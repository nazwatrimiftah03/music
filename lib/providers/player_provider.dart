import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../models/song.dart';

class PlayerProvider extends ChangeNotifier {
  final AudioPlayer player = AudioPlayer();

  /// Dipanggil setiap ada lagu yang mulai diputar (untuk riwayat).
  final void Function(Song song)? onSongStarted;

  /// True kalau pemutar sudah memuat daftar lagu. Isinya selalu
  /// berurutan sama dengan [_queue].
  bool _hasPlaylist = false;

  List<Song> _queue = [];
  int _index = -1;
  String? error;

  Timer? _sleepTimer;
  Timer? _fadeTimer;
  DateTime? _sleepEndsAt;

  /// Lama suara mengecil sebelum musik dijeda oleh timer tidur.
  static const Duration _fadeDuration = Duration(seconds: 10);

  Song? get current =>
      (_index >= 0 && _index < _queue.length) ? _queue[_index] : null;
  bool get isPlaying => player.playing;
  bool get shuffle => player.shuffleModeEnabled;
  LoopMode get loop => player.loopMode;

  /// Seluruh antrean (hanya untuk dibaca).
  List<Song> get queue => List.unmodifiable(_queue);

  /// Posisi lagu yang sedang diputar di dalam [queue].
  int get currentIndex => _index;

  /// True kalau timer tidur sedang berjalan.
  bool get sleepActive => _sleepEndsAt != null;

  /// Sisa waktu timer tidur (null kalau timer tidak aktif).
  Duration? get sleepRemaining {
    final end = _sleepEndsAt;
    if (end == null) return null;
    final left = end.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

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
    // Disalin supaya perubahan antrean tidak ikut mengubah daftar asalnya.
    _queue = List<Song>.of(songs);
    _index = start;
    error = null;
    notifyListeners();
    try {
      _hasPlaylist = true;
      await player.setAudioSources(
        _queue.map(_toSource).toList(),
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

  // ===================== Antrean =====================

  /// Taruh lagu tepat setelah lagu yang sedang diputar.
  /// Return true kalau masuk antrean, false kalau belum ada yang diputar
  /// sehingga lagunya langsung diputar.
  Future<bool> playNext(Song song) => _insert(song, _index + 1);

  /// Taruh lagu di urutan paling akhir antrean.
  Future<bool> addToQueue(Song song) => _insert(song, _queue.length);

  Future<bool> _insert(Song song, int at) async {
    if (!_hasPlaylist || _queue.isEmpty) {
      await playQueue([song], 0);
      return false;
    }

    final pos = at.clamp(0, _queue.length);
    try {
      await player.insertAudioSource(pos, _toSource(song));
      _queue = [..._queue]..insert(pos, song);
      notifyListeners();
    } catch (_) {
      error = 'Gagal menambah ke antrean';
      notifyListeners();
    }
    return true;
  }

  /// Hapus satu lagu dari antrean. Lagu yang sedang diputar tidak bisa dihapus.
  Future<void> removeFromQueue(int i) async {
    if (!_hasPlaylist || i < 0 || i >= _queue.length || i == _index) return;

    final oldQueue = _queue;
    final oldIndex = _index;

    // Perbarui dulu supaya pemutar tidak dianggap pindah lagu
    // (kalau tidak, riwayat bisa tercatat dobel).
    if (i < _index) _index -= 1;
    _queue = [..._queue]..removeAt(i);
    notifyListeners();

    try {
      await player.removeAudioSourceAt(i);
    } catch (_) {
      _queue = oldQueue;
      _index = oldIndex;
      error = 'Gagal menghapus dari antrean';
      notifyListeners();
    }
  }

  /// Pindahkan lagu dari posisi [from] ke posisi [to] di antrean.
  /// [to] adalah posisi akhir lagu tersebut (sudah dihitung setelah dicabut).
  Future<void> moveInQueue(int from, int to) async {
    if (!_hasPlaylist) return;
    if (from < 0 || from >= _queue.length) return;
    if (to < 0 || to >= _queue.length || from == to) return;

    final oldQueue = _queue;
    final oldIndex = _index;

    // Lagu yang sedang diputar harus tetap "ikut" posisinya.
    if (from == _index) {
      _index = to;
    } else if (from < _index && to >= _index) {
      _index -= 1;
    } else if (from > _index && to <= _index) {
      _index += 1;
    }

    final list = [..._queue];
    list.insert(to, list.removeAt(from));
    _queue = list;
    notifyListeners();

    try {
      await player.moveAudioSource(from, to);
    } catch (_) {
      _queue = oldQueue;
      _index = oldIndex;
      error = 'Gagal mengubah urutan antrean';
      notifyListeners();
    }
  }

  /// Loncat ke lagu tertentu di antrean lalu putar.
  Future<void> jumpTo(int i) async {
    if (i < 0 || i >= _queue.length) return;
    await player.seek(Duration.zero, index: i);
    player.play();
  }

  // ===================== Timer tidur =====================

  /// Jeda musik otomatis setelah [duration]. Suara mengecil perlahan
  /// selama 10 detik terakhir. Timer lama diganti kalau ada.
  void startSleepTimer(Duration duration) {
    _stopSleepTimers();
    _sleepEndsAt = DateTime.now().add(duration);

    final wait =
    duration > _fadeDuration ? duration - _fadeDuration : Duration.zero;
    _sleepTimer = Timer(wait, _startFadeOut);
    notifyListeners();
  }

  void _startFadeOut() {
    _sleepTimer = null;
    const steps = 20;
    final tick = Duration(
        milliseconds: _fadeDuration.inMilliseconds ~/ steps);
    var step = 0;

    _fadeTimer = Timer.periodic(tick, (t) async {
      step++;
      if (step < steps) {
        player.setVolume(1.0 - step / steps);
        return;
      }

      // Selesai: jeda musik, kembalikan volume, lalu bersihkan timer.
      t.cancel();
      _fadeTimer = null;
      _sleepEndsAt = null;
      await player.pause();
      await player.setVolume(1.0);
      notifyListeners();
    });
  }

  void cancelSleepTimer() {
    _stopSleepTimers();
    notifyListeners();
  }

  /// Hentikan semua timer tidur dan pastikan volume kembali normal.
  void _stopSleepTimers() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _fadeTimer?.cancel();
    _fadeTimer = null;
    _sleepEndsAt = null;
    player.setVolume(1.0);
  }

  // ===================== Kontrol dasar =====================

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
    _sleepTimer?.cancel();
    _fadeTimer?.cancel();
    player.dispose();
    super.dispose();
  }
}