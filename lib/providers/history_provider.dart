import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/song.dart';
import '../services/library_service.dart';

/// Riwayat putar disimpan di Supabase (tabel play_history), jadi ikut
/// pindah ke perangkat lain saat login dengan akun yang sama.
class HistoryProvider extends ChangeNotifier {
  static const int _max = 20;

  final SupabaseClient _db = Supabase.instance.client;
  final LibraryService _library = LibraryService();

  List<Song> _songs = [];
  List<Song> get songs => List.unmodifiable(_songs);

  String? get _uid => _db.auth.currentUser?.id;

  Future<void> load() async {
    final uid = _uid;
    if (uid == null) {
      _songs = [];
      notifyListeners();
      return;
    }

    try {
      final data = await _db
          .from('play_history')
          .select('played_at, songs(*)')
          .eq('user_id', uid)
          .order('played_at', ascending: false)
          .limit(_max);

      _songs = (data as List)
          .where((e) => e['songs'] != null)
          .map((e) => Song.fromMap(Map<String, dynamic>.from(e['songs'] as Map)))
          .toList();
    } catch (e) {
      // Gagal memuat (offline dll): pertahankan daftar yang sudah ada.
      debugPrint('Gagal load riwayat: $e');
    }

    notifyListeners();
  }

  Future<void> add(Song song) async {
    // Tampilan diperbarui dulu supaya terasa instan.
    _songs.removeWhere((s) => s.id == song.id);
    _songs.insert(0, song);
    if (_songs.length > _max) {
      _songs = _songs.sublist(0, _max);
    }
    notifyListeners();

    final uid = _uid;
    if (uid == null) return;

    try {
      await _library.ensureSong(song);
      await _db.from('play_history').upsert(
        {
          'user_id': uid,
          'song_id': song.id,
          'played_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id,song_id',
      );
    } catch (e) {
      debugPrint('Gagal simpan riwayat: $e');
    }
  }
}