import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../models/song.dart';

class PlayerProvider extends ChangeNotifier {
  final AudioPlayer player = AudioPlayer();

  /// Dipanggil setiap ada lagu yang mulai diputar (untuk riwayat).
  final void Function(Song song)? onSongStarted;

  List<Song> _queue = [];
  int _index = -1;
  String? error;

  Song? get current =>
      (_index >= 0 && _index < _queue.length) ? _queue[_index] : null;
  bool get isPlaying => player.playing;
  bool get shuffle => player.shuffleModeEnabled;
  LoopMode get loop => player.loopMode;

  PlayerProvider({this.onSongStarted}) {
    player.playerStateStream.listen((_) => notifyListeners());
    player.currentIndexStream.listen((i) {
      if (i != null && i != _index && i < _queue.length) {
        _index = i;
        notifyListeners();
        final s = current;
        if (s != null) onSongStarted?.call(s);
      }
    });
  }

  Future<void> playQueue(List<Song> songs, int start) async {
    _queue = songs;
    _index = start;
    error = null;
    notifyListeners();
    try {
      await player.setAudioSource(
        ConcatenatingAudioSource(
          children:
          songs.map(_toSource).toList(),
        ),
        initialIndex: start,
      );
      player.play(); // jangan di-await, future-nya selesai saat lagu habis
      final s = current;
      if (s != null) onSongStarted?.call(s);
    } catch (e) {
      error = 'Gagal memutar lagu';
      notifyListeners();
    }
  }

  /// Setiap lagu membawa MediaItem supaya notifikasi & layar kunci
  /// menampilkan judul, artis, dan cover.
  AudioSource _toSource(Song s) {
    return AudioSource.uri(
      Uri.parse(s.audioUrl),
      tag: MediaItem(
        id: s.id,
        title: s.title,
        artist: s.artist,
        artUri: Uri.tryParse(s.coverUrl),
      ),
    );
  }

  void togglePlay() => player.playing ? player.pause() : player.play();
  Future<void> next() => player.seekToNext();
  Future<void> previous() async {
    if (player.position.inSeconds > 3) {
      await player.seek(Duration.zero);
    } else {
      await player.seekToPrevious();
    }
  }

  Future<void> seek(Duration d) => player.seek(d);

  Future<void> toggleShuffle() async {
    await player.setShuffleModeEnabled(!player.shuffleModeEnabled);
    notifyListeners();
  }

  Future<void> cycleLoop() async {
    final next = switch (player.loopMode) {
      LoopMode.off => LoopMode.all,
      LoopMode.all => LoopMode.one,
      LoopMode.one => LoopMode.off,
    };
    await player.setLoopMode(next);
    notifyListeners();
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }
}