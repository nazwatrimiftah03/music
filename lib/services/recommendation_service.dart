
import 'dart:math';

import '../models/song.dart';
import 'itunes_service.dart';
import 'jamendo_service.dart';
import 'library_service.dart';

/// Layanan rekomendasi lagu PinkBeat.
class RecommendationService {
  final JamendoService _jamendo = JamendoService();
  final ItunesService _itunes = ItunesService();
  final LibraryService _library = LibraryService();

  bool _isItunes(Song song) =>
      song.id.startsWith(ItunesService.idPrefix);

  List<String> _top(Map<String, int> scores, int count) {
    final entries = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return entries.take(count).map((e) => e.key).toList();
  }

  /// Menghapus lagu duplikat dan lagu tanpa audio.
  List<Song> _uniqueSongs(
      Iterable<Song> songs, {
        required int limit,
      }) {
    final seen = <String>{};
    final result = <Song>[];

    for (final song in songs) {
      if (song.id.isEmpty || song.audioUrl.isEmpty) continue;

      if (seen.add(song.id)) {
        result.add(song);
      }

      if (result.length >= limit) break;
    }

    return result;
  }

  /// Mengambil lagu cadangan dari Jamendo dan iTunes.
  Future<List<Song>> _fallback({
    required Set<String> heard,
    required int limit,
  }) async {
    final lists = <List<Song>>[];

    // Sumber pertama: Jamendo.
    try {
      final songs = await _jamendo.fetchTrendingSongs(
        limit: limit + heard.length,
      );

      if (songs.isNotEmpty) {
        lists.add(songs);
      }
    } catch (_) {
      // Lanjut ke iTunes jika Jamendo gagal.
    }

    // Sumber kedua: iTunes.
    // Digunakan jika Jamendo tidak menghasilkan lagu yang cukup.
    if (lists.isEmpty ||
        _uniqueSongs(
          lists.expand((songs) => songs).where(
                (song) => !heard.contains(song.id),
          ),
          limit: limit,
        ).length < limit) {
      try {
        final hits = await _itunes.indonesiaHits(perArtist: 5);
        lists.add(hits);
      } catch (_) {
        // Tetap gunakan hasil Jamendo jika iTunes juga gagal.
      }
    }

    final combined = interleaveSongs(
      lists,
      limit: limit + heard.length,
    );

    return _uniqueSongs(
      combined.where((song) => !heard.contains(song.id)),
      limit: limit,
    );
  }

  Future<List<Song>> forYou({
    required List<Song> history,
    int limit = 20,
    int topGenres = 3,
    int topArtists = 2,
  }) async {
    if (limit <= 0) return [];

    List<Song> liked = [];

    try {
      liked = await _library.likedSongs();
    } catch (_) {
      // Tetap gunakan riwayat jika data like gagal dimuat.
    }

    final heard = <String>{
      ...history.map((song) => song.id),
      ...liked.map((song) => song.id),
    };

    final genreScore = <String, int>{};
    final artistScore = <String, int>{};

    void count(Iterable<Song> songs, int weight) {
      for (final song in songs) {
        if (_isItunes(song)) {
          final artist = song.artist.trim();

          if (artist.isNotEmpty) {
            artistScore[artist] =
                (artistScore[artist] ?? 0) + weight;
          }
        } else {
          final genre = song.genre?.trim();

          if (genre != null && genre.isNotEmpty) {
            genreScore[genre] =
                (genreScore[genre] ?? 0) + weight;
          }
        }
      }
    }

    count(liked, 2);
    count(history, 1);

    // Belum ada data minat: gunakan fallback.
    if (genreScore.isEmpty && artistScore.isEmpty) {
      return _fallback(heard: heard, limit: limit);
    }

    final lists = <List<Song>>[];

    // Cari lagu lain dari artis favorit melalui iTunes.
    for (final artist in _top(artistScore, topArtists)) {
      try {
        final songs = await _itunes.search(
          artist,
          limit: 12,
        );

        lists.add(songs);
      } catch (_) {
        // Lanjut ke sumber berikutnya.
      }
    }

    // Cari lagu dari genre favorit melalui Jamendo.
    for (final genre in _top(genreScore, topGenres)) {
      try {
        final songs = await _jamendo.songsByGenre(
          genre,
          limit: limit + heard.length,
        );

        lists.add(songs);
      } catch (_) {
        // Lanjut ke sumber berikutnya.
      }
    }

    final filtered = [
      for (final list in lists)
        list.where((song) {
          return song.id.isNotEmpty &&
              song.audioUrl.isNotEmpty &&
              !heard.contains(song.id);
        }).toList(),
    ];

    final combined = interleaveSongs(
      filtered,
      limit: limit + heard.length,
    );

    final result = _uniqueSongs(
      combined.where((song) => !heard.contains(song.id)),
      limit: limit,
    );

    // Jika hasil rekomendasi kosong, gunakan fallback.
    if (result.isEmpty) {
      return _fallback(heard: heard, limit: limit);
    }

    return result;
  }

  /// Mix harian: selang-seling lagu favorit dan rekomendasi baru.
  Future<List<Song>> dailyMix({
    required List<Song> history,
    int limit = 25,
  }) async {
    if (limit <= 0) return [];

    List<Song> liked = [];

    try {
      liked = await _library.likedSongs();
    } catch (_) {
      // Mix tetap bisa dibuat dari rekomendasi.
    }

    List<Song> fresh = [];

    try {
      fresh = await forYou(
        history: history,
        limit: limit,
      );
    } catch (_) {
      // Jika rekomendasi gagal, gunakan lagu favorit.
    }

    final now = DateTime.now();

    final rng = Random(
      now.year * 10000 + now.month * 100 + now.day,
    );

    final favorites = [...liked]..shuffle(rng);
    final discoveries = [...fresh]..shuffle(rng);

    final seen = <String>{};
    final mix = <Song>[];

    var a = 0;
    var b = 0;

    while (mix.length < limit &&
        (a < favorites.length || b < discoveries.length)) {
      if (a < favorites.length) {
        final song = favorites[a++];

        if (song.id.isNotEmpty && seen.add(song.id)) {
          mix.add(song);
        }
      }

      if (mix.length >= limit) break;

      if (b < discoveries.length) {
        final song = discoveries[b++];

        if (song.id.isNotEmpty && seen.add(song.id)) {
          mix.add(song);
        }
      }
    }

    return mix;
  }
}
