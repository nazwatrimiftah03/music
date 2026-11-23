
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../models/song.dart';

class PlayerProvider extends ChangeNotifier {
  final AudioPlayer player = AudioPlayer();

  /// Dipanggil setiap lagu baru mulai diputar untuk menyimpan riwayat.
  final void Function(Song song)? onSongStarted;

  bool _hasPlaylist = false;
  List<Song> _queue = [];
  int _index = -1;

  bool _shuffleOn = false;
  String? error;

  Timer? _sleepTimer;
  Timer? _fadeTimer;
  DateTime? _sleepEndsAt;

  static const Duration _fadeDuration = Duration(seconds: 10);

  /// Mencegah lagu yang sama tercatat dua kali akibat event stream
  /// dan pemanggilan manual saat playQueue().
  String? _lastReportedSongId;

  late final StreamSubscription<PlayerState> _playerStateSubscription;
  late final StreamSubscription<int?> _currentIndexSubscription;

  Song? get current =>
      (_index >= 0 && _index < _queue.length) ? _queue[_index] : null;

  bool get isPlaying => player.playing;
  bool get shuffle => _shuffleOn;
  LoopMode get loop => player.loopMode;

  List<Song> get queue => List.unmodifiable(_queue);

  int get currentIndex => _index;

  bool get sleepActive => _sleepEndsAt != null;

  Duration? get sleepRemaining {
    final end = _sleepEndsAt;
    if (end == null) return null;

    final left = end.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  PlayerProvider({this.onSongStarted}) {
    _playerStateSubscription =
        player.playerStateStream.listen((_) {
          notifyListeners();
        });

    _currentIndexSubscription =
        player.currentIndexStream.listen((i) {
          if (i == null || i < 0 || i >= _queue.length) return;

          if (i != _index) {
            _index = i;
            notifyListeners();
          }

          _reportSongStarted(i);
        });
  }

  /// Mencatat lagu yang sedang mulai diputar.
  /// Lagu yang sama tidak dilaporkan dua kali pada event yang berdekatan.
  void _reportSongStarted(int index) {
    if (index < 0 || index >= _queue.length) return;

    final song = _queue[index];

    if (_lastReportedSongId == song.id) return;

    _lastReportedSongId = song.id;
    onSongStarted?.call(song);
  }

  Future<void> playQueue(List<Song> songs, int start) async {
    if (songs.isEmpty || start < 0 || start >= songs.length) {
      return;
    }

    _queue = List<Song>.of(songs);
    _index = start;
    _lastReportedSongId = null;

    if (_shuffleOn && start < _queue.length - 1) {
      final rest = _queue.sublist(start + 1)..shuffle();
      _queue.replaceRange(start + 1, _queue.length, rest);
    }

    error = null;
    notifyListeners();

    try {
      _hasPlaylist = true;

      await player.setAudioSources(
        _queue.map(_toSource).toList(),
        initialIndex: start,
      );

      // Memastikan lagu pertama tetap masuk riwayat.
      // Jika stream sudah melaporkannya, fungsi ini tidak akan
      // mencatat lagu yang sama untuk kedua kalinya.
      _reportSongStarted(start);

      unawaited(player.play());
    } catch (e) {
      _hasPlaylist = false;
      error = 'Gagal memutar lagu';
      notifyListeners();
    }
  }

  AudioSource _toSource(Song song) {
    return AudioSource.uri(
      Uri.parse(song.audioUrl),
      tag: MediaItem(
        id: song.id,
        title: song.title,
        artist: song.artist,
        artUri: Uri.tryParse(song.coverUrl),
      ),
    );
  }

  // ===================== ANTREAN =====================

  Future<bool> playNext(Song song) {
    return _insert(song, _index + 1);
  }

  Future<bool> addToQueue(Song song) {
    return _insert(song, _queue.length);
  }

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
    } catch (e) {
      error = 'Gagal menambah ke antrean';
      notifyListeners();
    }

    return true;
  }

  Future<void> removeFromQueue(int i) async {
    if (!_hasPlaylist ||
        i < 0 ||
        i >= _queue.length ||
        i == _index) {
      return;
    }

    final oldQueue = _queue;
    final oldIndex = _index;

    if (i < _index) {
      _index--;
    }

    _queue = [..._queue]..removeAt(i);
    notifyListeners();

    try {
      await player.removeAudioSourceAt(i);
    } catch (e) {
      _queue = oldQueue;
      _index = oldIndex;
      error = 'Gagal menghapus dari antrean';
      notifyListeners();
    }
  }

  Future<void> moveInQueue(int from, int to) async {
    if (!_hasPlaylist) return;

    if (from < 0 ||
        from >= _queue.length ||
        to < 0 ||
        to >= _queue.length ||
        from == to) {
      return;
    }

    final oldQueue = _queue;
    final oldIndex = _index;

    if (from == _index) {
      _index = to;
    } else if (from < _index && to >= _index) {
      _index--;
    } else if (from > _index && to <= _index) {
      _index++;
    }

    final list = [..._queue];
    list.insert(to, list.removeAt(from));

    _queue = list;
    notifyListeners();

    try {
      await player.moveAudioSource(from, to);
    } catch (e) {
      _queue = oldQueue;
      _index = oldIndex;
      error = 'Gagal mengubah urutan antrean';
      notifyListeners();
    }
  }

  Future<void> jumpTo(int i) async {
    if (i < 0 || i >= _queue.length) return;

    await player.seek(Duration.zero, index: i);
    unawaited(player.play());
  }

  // ===================== TIMER TIDUR =====================

  void startSleepTimer(Duration duration) {
    _stopSleepTimers();

    if (duration <= Duration.zero) {
      unawaited(player.pause());
      notifyListeners();
      return;
    }

    _sleepEndsAt = DateTime.now().add(duration);

    // Fade mengikuti durasi timer jika kurang dari 10 detik.
    final fadeDuration =
        duration < _fadeDuration ? duration : _fadeDuration;

    final wait = duration - fadeDuration;

    _sleepTimer = Timer(
      wait,
      () => _startFadeOut(fadeDuration),
    );

    notifyListeners();
  }

  void _startFadeOut(Duration fadeDuration) {
    _sleepTimer = null;

    final totalMilliseconds = fadeDuration.inMilliseconds;
    final steps = totalMilliseconds < 20 ? totalMilliseconds : 20;

    if (steps <= 0) {
      _sleepEndsAt = null;
      unawaited(player.pause());
      notifyListeners();
      return;
    }

    final tick = Duration(
      milliseconds: totalMilliseconds ~/ steps,
    );

    var step = 0;

    _fadeTimer = Timer.periodic(tick, (timer) async {
      step++;

      if (step < steps) {
        await player.setVolume(1.0 - step / steps);
        return;
      }

      timer.cancel();
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

  void _stopSleepTimers() {
    _sleepTimer?.cancel();
    _sleepTimer = null;

    _fadeTimer?.cancel();
    _fadeTimer = null;

    _sleepEndsAt = null;

    unawaited(player.setVolume(1.0));
  }

  // ===================== KONTROL PEMUTAR =====================

  void togglePlay() {
    if (player.playing) {
      unawaited(player.pause());
    } else {
      unawaited(player.play());
    }
  }

  Future<void> next() => player.seekToNext();

  Future<void> previous() async {
    if (player.position.inSeconds > 3) {
      await player.seek(Duration.zero);
    } else {
      await player.seekToPrevious();
    }
  }

  Future<void> seek(Duration duration) {
    return player.seek(duration);
  }

  // ===================== SHUFFLE =====================

  Future<void> toggleShuffle() async {
    _shuffleOn = !_shuffleOn;
    notifyListeners();

    if (_shuffleOn) {
      await _shuffleUpcoming();
    }
  }

  Future<void> _shuffleUpcoming() async {
    final start = _index + 1;

    if (!_hasPlaylist ||
        _index < 0 ||
        _queue.length - start < 2) {
      return;
    }

    final oldQueue = _queue;
    final rest = _queue.sublist(start)..shuffle();

    _queue = [
      ..._queue.sublist(0, start),
      ...rest,
    ];

    notifyListeners();

    try {
      await player.removeAudioSourceRange(
        start,
        oldQueue.length,
      );

      await player.insertAudioSources(
        start,
        rest.map(_toSource).toList(),
      );
    } catch (e) {
      _queue = oldQueue;
      error = 'Gagal mengacak antrean';

      try {
        await player.setAudioSources(
          _queue.map(_toSource).toList(),
          initialIndex: _index,
          initialPosition: player.position,
        );
      } catch (_) {}

      notifyListeners();
    }
  }

  // ===================== REPEAT =====================

  Future<void> cycleLoop() async {
    final nextMode = switch (player.loopMode) {
      LoopMode.off => LoopMode.all,
      LoopMode.all => LoopMode.one,
      LoopMode.one => LoopMode.off,
    };

    await player.setLoopMode(nextMode);
    notifyListeners();
  }

  // ===================== DISPOSE =====================

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _fadeTimer?.cancel();

    _playerStateSubscription.cancel();
    _currentIndexSubscription.cancel();

    player.dispose();

    super.dispose();
  }
}

