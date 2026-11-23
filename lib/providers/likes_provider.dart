import 'package:flutter/material.dart';

import '../models/song.dart';
import '../services/likes_service.dart';
import '../services/library_service.dart';

class LikesProvider extends ChangeNotifier {
  final LikesService _svc;

  Set<String> _ids = {};

  LikesProvider({LikesService? service})
      : _svc = service ?? LibraryService();

  bool isLiked(String songId) => _ids.contains(songId);

  int get count => _ids.length;

  Future<void> load() async {
    try {
      _ids = await _svc.likedIds();
      notifyListeners();
    } catch (e) {
      debugPrint('Gagal load likes: $e');
    }
  }

  Future<void> toggle(Song song) async {
    final wasLiked = _ids.contains(song.id);

    if (wasLiked) {
      _ids.remove(song.id);
    } else {
      _ids.add(song.id);
    }

    notifyListeners();

    try {
      if (wasLiked) {
        await _svc.unlike(song.id);
      } else {
        await _svc.like(song);
      }
    } catch (e) {
      debugPrint('Gagal toggle like: $e');

      if (wasLiked) {
        _ids.add(song.id);
      } else {
        _ids.remove(song.id);
      }

      notifyListeners();
    }
  }
}