import 'package:flutter/material.dart';

import '../models/song.dart';
import '../services/history_service.dart';

class HistoryProvider extends ChangeNotifier {
  static const int _max = 20;

  final HistoryService _service;

  List<Song> _songs = [];

  HistoryProvider({HistoryService? service})
      : _service = service ?? SupabaseHistoryService();

  List<Song> get songs => List.unmodifiable(_songs);

  Future<void> load() async {
    try {
      _songs = await _service.load();
    } catch (e) {
      debugPrint('Gagal load riwayat: $e');
    }

    notifyListeners();
  }

  Future<void> add(Song song) async {
    _songs.insert(0, song);

    if (_songs.length > _max) {
      _songs = _songs.sublist(0, _max);
    }

    notifyListeners();

    try {
      await _service.save(song);
    } catch (e) {
      debugPrint('Gagal simpan riwayat: $e');
    }
  }

  void clear() {
    _songs = [];
    notifyListeners();
  }
}
