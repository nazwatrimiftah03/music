
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/song.dart';
import 'itunes_service.dart';
import 'jamendo_service.dart';

/// Pembungkus supaya Home & Search tidak perlu tahu sumber datanya.
/// Lagu sendiri : file MP3 milikmu di Supabase Storage, diputar penuh.
/// Jamendo      : lagu independen, diputar penuh.
/// iTunes       : lagu populer/Indonesia, cuplikan 30 detik.
class SongService {
  final JamendoService _jamendo = JamendoService();
  final ItunesService _itunes = ItunesService();

  static const String indonesiaTag = 'indonesia';
  static const String ownPrefix = 'own_';

  static const int _minFullSongs = 10;

  /// Lagu populer dari Jamendo.
  /// Jika Jamendo gagal, gunakan iTunes sebagai cadangan.
  Future<List<Song>> getAll() async {
    final jamendo = await _safe(
      _jamendo.fetchTrendingSongs(),
    );

    if (jamendo != null && jamendo.isNotEmpty) {
      return jamendo;
    }

    // Cadangan pertama: pencarian lagu populer iTunes.
    final itunes = await _safe(
      _itunes.search('top hits', limit: 30),
    );

    if (itunes != null && itunes.isNotEmpty) {
      return itunes;
    }

    // Cadangan kedua: Hits Indonesia.
    final indonesia = await _safe(
      _itunes.indonesiaHits(),
    );

    if (indonesia != null && indonesia.isNotEmpty) {
      return indonesia;
    }

    throw Exception('Tidak bisa memuat lagu populer');
  }

  /// Lagu yang diunggah sendiri ke Supabase.
  Future<List<Song>> ownSongs() async {
    final data = await Supabase.instance.client
        .from('songs')
        .select()
        .like('id', '$ownPrefix%')
        .order('id');

    return (data as List)
        .map((e) => Song.fromMap(Map<String, dynamic>.from(e as Map)))
        .where((s) => s.audioUrl.isNotEmpty)
        .toList();
  }

  /// Urutan: lagu sendiri -> Jamendo -> iTunes.
  Future<List<Song>> indonesiaHits() async {
    final own = await _safe(ownSongs()) ?? <Song>[];
    final jamendo = await _safe(
      _jamendo.indonesianSongs(),
    ) ??
        <Song>[];

    final seen = <String>{};

    final full = <Song>[
      ...own.where((s) => seen.add(s.id)),
      ...jamendo.where((s) => seen.add(s.id)),
    ];

    if (full.length >= _minFullSongs) return full;

    final previews = await _safe(
      _itunes.indonesiaHits(),
    ) ??
        <Song>[];

    final result = <Song>[
      ...full,
      ...previews.where((s) => seen.add(s.id)),
    ];

    if (result.isEmpty) {
      throw Exception('Tidak bisa memuat lagu Indonesia');
    }

    return result;
  }

  Future<List<Song>> search(String query) async {
    final q = query.trim();

    if (q.isEmpty) return getAll();

    final results = await Future.wait([
      _safe(_itunes.search(q)),
      _safe(_jamendo.searchSongs(q)),
    ]);

    final available = results.whereType<List<Song>>().toList();

    if (available.isEmpty) {
      throw Exception('Pencarian gagal');
    }

    return interleaveSongs(available);
  }

  /// Lagu dari artis tertentu.
  Future<List<Song>> byArtist(String artist) async {
    final key = artist.trim().toLowerCase();

    if (key.isEmpty) return <Song>[];

    bool match(Song s) => s.artist.toLowerCase().contains(key);

    final own = await _safe(ownSongs()) ?? <Song>[];
    final found = await _safe(search(artist)) ?? <Song>[];

    final seen = <String>{};

    return [
      ...own.where(match),
      ...found.where(match),
    ].where((s) => seen.add(s.id)).toList();
  }

  /// Lagu populer berdasarkan data pemutaran PinkBeat.
  Future<List<Song>> popular({
    String? artist,
    int limit = 20,
  }) async {
    try {
      final data = await Supabase.instance.client.rpc(
        'popular_songs',
        params: {
          'p_artist': artist,
          'p_limit': limit,
        },
      );

      return (data as List)
          .map((e) => Song.fromMap(Map<String, dynamic>.from(e as Map)))
          .where((s) => s.audioUrl.isNotEmpty)
          .toList();
    } catch (_) {
      return <Song>[];
    }
  }

  Future<List<Song>> byGenre(String genre) {
    if (genre == indonesiaTag) return indonesiaHits();

    return _jamendo.songsByGenre(genre);
  }

  Future<List<Song>?> _safe(
      Future<List<Song>> future,
      ) async {
    try {
      return await future;
    } catch (_) {
      return null;
    }
  }
}
