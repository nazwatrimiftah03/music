import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../providers/player_provider.dart';
import '../services/lyrics_service.dart';

/// Tampilkan lirik lagu yang sedang diputar. Kalau lagunya berganti saat
/// sheet terbuka, liriknya ikut berganti.
void showLyricsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const FractionallySizedBox(
      heightFactor: 0.9,
      child: _LyricsSheet(),
    ),
  );
}

class _LyricsSheet extends StatelessWidget {
  const _LyricsSheet();

  @override
  Widget build(BuildContext context) {
    final song = context.select<PlayerProvider, Song?>((p) => p.current);
    final cs = Theme.of(context).colorScheme;

    if (song == null) {
      return const Center(child: Text('Belum ada lagu'));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: Column(
            children: [
              Text(song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              Text(song.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
        Expanded(child: _LyricsBody(key: ValueKey(song.id), song: song)),
      ],
    );
  }
}

class _LyricsBody extends StatefulWidget {
  final Song song;
  const _LyricsBody({super.key, required this.song});

  @override
  State<_LyricsBody> createState() => _LyricsBodyState();
}

class _LyricsBodyState extends State<_LyricsBody> {
  late Future<Lyrics?> _future;
  List<GlobalKey> _keys = [];
  int _active = -1;

  @override
  void initState() {
    super.initState();
    _future = LyricsService().fetch(widget.song);
  }

  void _retry() {
    setState(() => _future = LyricsService().fetch(widget.song));
  }

  /// Indeks baris terakhir yang waktunya sudah lewat (-1 kalau belum mulai).
  int _indexAt(List<LyricLine> lines, Duration pos) {
    var idx = -1;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].time! <= pos) {
        idx = i;
      } else {
        break;
      }
    }
    return idx;
  }

  void _scrollTo(int i) {
    if (i < 0 || i >= _keys.length) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[i].currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.4,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget message(String text, {bool retry = false}) => Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant)),
            if (retry) ...[
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba lagi'),
              ),
            ],
          ],
        ),
      ),
    );

    return FutureBuilder<Lyrics?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Center(child: CircularProgressIndicator(color: cs.primary));
        }
        if (snap.hasError) {
          return message('Gagal memuat lirik.\nPeriksa koneksi internetmu.',
              retry: true);
        }
        final lyrics = snap.data;
        if (lyrics == null || lyrics.lines.isEmpty) {
          return message('Lirik untuk lagu ini belum tersedia.');
        }

        if (_keys.length != lyrics.lines.length) {
          _keys = List.generate(lyrics.lines.length, (_) => GlobalKey());
        }

        // Lirik tanpa waktu: tampilkan sebagai teks biasa.
        if (!lyrics.synced) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            children: [
              for (final l in lyrics.lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(l.text,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 17, height: 1.4)),
                ),
            ],
          );
        }

        final player = context.read<PlayerProvider>().player;
        return StreamBuilder<Duration>(
          stream: player.positionStream,
          builder: (context, pos) {
            final idx = _indexAt(lyrics.lines, pos.data ?? Duration.zero);
            if (idx != _active) {
              _active = idx;
              _scrollTo(idx);
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
              child: Column(
                children: [
                  for (var i = 0; i < lyrics.lines.length; i++)
                    Container(
                      key: _keys[i],
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: i == idx ? 22 : 18,
                          fontWeight:
                          i == idx ? FontWeight.w800 : FontWeight.w600,
                          height: 1.35,
                          color: i == idx
                              ? cs.primary
                              : cs.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                        child: Text(
                          lyrics.lines[i].text.isEmpty
                              ? '♪'
                              : lyrics.lines[i].text,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}