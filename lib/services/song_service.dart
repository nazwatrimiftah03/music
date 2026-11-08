import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/song.dart';
import 'itunes_service.dart';
import 'jamendo_service.dart';

/// Pembungkus supaya Home & Search tidak perlu tahu sumber datanya.
/// Lagu sendiri : file MP3 milikmu di Supabase Storage, diputar penuh.
/// Jamendo      : lagu independen (termasuk Indonesia), diputar penuh.
/// iTunes       : lagu populer/Indonesia, cuplikan 30 detik.
class SongService {
  final JamendoService _jamendo = JamendoService();
  final ItunesService _itunes = ItunesService();

  /// Tag khusus di layar Cari / Beranda untuk lagu Indonesia.
  static const String indonesiaTag = 'indonesia';

  /// Awalan id untuk lagu yang kamu unggah sendiri (contoh: own_1, own_2).
  static const String ownPrefix = 'own_';

  /// Kalau lagu penuh (lagu sendiri + Jamendo) kurang dari ini,
  /// daftar dilengkapi dengan cuplikan 30 detik dari iTunes.
  static const int _minFullSongs = 10;

  Future<List<Song>> getAll() => _jamendo.fetchTrendingSongs();

  /// Lagu yang kamu unggah sendiri ke Supabase (id berawalan "own_").
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

  /// Urutan: lagu sendiri -> lagu penuh Jamendo -> cuplikan iTunes
  /// (iTunes hanya muncul kalau lagu penuhnya masih sedikit).
  Future<List<Song>> indonesiaHits() async {
    final own = await _safe(ownSongs()) ?? <Song>[];
    final jamendo = await _safe(_jamendo.indonesianSongs()) ?? <Song>[];

    final seen = <String>{};
    final full = <Song>[
      ...own.where((s) => seen.add(s.id)),
      ...jamendo.where((s) => seen.add(s.id)),
    ];

    if (full.length >= _minFullSongs) return full;

    final previews = await _safe(_itunes.indonesiaHits()) ?? <Song>[];
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

    // Dua-duanya gagal -> biarkan layar menampilkan pesan error.
    if (available.isEmpty) {
      throw Exception('Pencarian gagal');
    }

    return interleaveSongs(available);
  }

  Future<List<Song>> byGenre(String genre) {
    if (genre == indonesiaTag) return indonesiaHits();
    return _jamendo.songsByGenre(genre);
  }

  Future<List<Song>?> _safe(Future<List<Song>> future) async {
    try {
      return await future;
    } catch (_) {
      return null;
    }
  }
}