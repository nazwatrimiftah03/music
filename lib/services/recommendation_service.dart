import 'dart:math';

import '../models/song.dart';
import 'itunes_service.dart';
import 'jamendo_service.dart';
import 'library_service.dart';

/// Rekomendasi "Untuk kamu":
/// - Lagu Jamendo  -> genre favorit (dari like bobot 2 + riwayat bobot 1),
///   lalu lagu populer genre itu diambil dari Jamendo.
/// - Lagu iTunes   -> artis favorit, lalu lagu lain dari artis itu.
/// Lagu yang sudah pernah didengar/di-like tidak ditampilkan lagi.
class RecommendationService {
  final JamendoService _jamendo = JamendoService();
  final ItunesService _itunes = ItunesService();
  final LibraryService _library = LibraryService();

  bool _isItunes(Song song) => song.id.startsWith(ItunesService.idPrefix);

  List<String> _top(Map<String, int> scores, int count) {
    final entries = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(count).map((e) => e.key).toList();
  }

  Future<List<Song>> forYou({
    required List<Song> history,
    int limit = 20,
    int topGenres = 3,
    int topArtists = 2,
  }) async {
    List<Song> liked = [];
    try {
      liked = await _library.likedSongs();
    } catch (_) {
      // Tanpa data like, rekomendasi tetap jalan dari riwayat.
    }

    // 1. Hitung skor genre (Jamendo) dan artis (iTunes).
    final genreScore = <String, int>{};
    final artistScore = <String, int>{};

    void count(Iterable<Song> songs, int weight) {
      for (final s in songs) {
        if (_isItunes(s)) {
          artistScore[s.artist] = (artistScore[s.artist] ?? 0) + weight;
        } else {
          final g = s.genre;
          if (g == null || g.isEmpty) continue;
          genreScore[g] = (genreScore[g] ?? 0) + weight;
        }
      }
    }

    count(liked, 2);
    count(history, 1);

    // 2. Belum ada data -> tampilkan lagu populer.
    if (genreScore.isEmpty && artistScore.isEmpty) {
      return _jamendo.fetchTrendingSongs(limit: limit);
    }

    // 3. Ambil kandidat.
    final lists = <List<Song>>[];

    for (final artist in _top(artistScore, topArtists)) {
      try {
        lists.add(await _itunes.search(artist, limit: 12));
      } catch (_) {}
    }

    for (final genre in _top(genreScore, topGenres)) {
      try {
        lists.add(await _jamendo.songsByGenre(genre, limit: limit));
      } catch (_) {
        // Satu sumber gagal tidak boleh menggagalkan semuanya.
      }
    }

    // 4. Gabung bergantian, buang duplikat & lagu yang sudah pernah didengar.
    final heard = <String>{
      ...history.map((s) => s.id),
      ...liked.map((s) => s.id),
    };

    final filtered = [
      for (final list in lists)
        list.where((song) => !heard.contains(song.id)).toList(),
    ];

    final result = interleaveSongs(filtered, limit: limit);

    // Semua gagal / sudah pernah didengar -> tetap tampilkan sesuatu.
    if (result.isEmpty) {
      return _jamendo.fetchTrendingSongs(limit: limit);
    }

    return result;
  }

  /// "Mix harian": selang-seling lagu yang kamu sukai dan lagu baru hasil
  /// rekomendasi. Urutannya diacak dengan benih tanggal hari ini, jadi mix
  /// tetap sama sepanjang hari dan berganti besok.
  Future<List<Song>> dailyMix({
    required List<Song> history,
    int limit = 25,
  }) async {
    List<Song> liked = [];
    try {
      liked = await _library.likedSongs();
    } catch (_) {
      // Tanpa data like, mix tetap dibuat dari rekomendasi.
    }

    List<Song> fresh = [];
    try {
      fresh = await forYou(history: history, limit: limit);
    } catch (_) {
      // Rekomendasi gagal: pakai lagu yang disukai saja.
    }

    final now = DateTime.now();
    final rng = Random(now.year * 10000 + now.month * 100 + now.day);
    final favorites = [...liked]..shuffle(rng);
    final discoveries = [...fresh]..shuffle(rng);

    final seen = <String>{};
    final mix = <Song>[];
    var a = 0;
    var b = 0;

    // Pola: 1 lagu favorit, lalu 1 lagu baru, dan seterusnya.
    while (mix.length < limit &&
        (a < favorites.length || b < discoveries.length)) {
      if (a < favorites.length) {
        final s = favorites[a++];
        if (seen.add(s.id)) mix.add(s);
      }
      if (mix.length >= limit) break;
      if (b < discoveries.length) {
        final s = discoveries[b++];
        if (seen.add(s.id)) mix.add(s);
      }
    }

    return mix;
  }
}