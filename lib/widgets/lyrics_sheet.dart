
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../providers/player_provider.dart';
import '../services/lyrics_service.dart';

void showLyricsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
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
    final song = context.select<PlayerProvider, Song?>(
          (p) => p.current,
    );

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (song == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.music_off_rounded,
              size: 52,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Belum ada lagu yang diputar',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 18),
          child: Column(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.lyrics_rounded,
                  color: cs.primary,
                  size: 27,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Lirik Lagu',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                song.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          color: cs.outlineVariant.withValues(alpha: 0.4),
        ),
        Expanded(
          child: _LyricsBody(
            key: ValueKey(song.id),
            song: song,
          ),
        ),
      ],
    );
  }
}

class _LyricsBody extends StatefulWidget {
  final Song song;

  const _LyricsBody({
    super.key,
    required this.song,
  });

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
    setState(() {
      _active = -1;
      _keys = [];
      _future = LyricsService().fetch(widget.song);
    });
  }

  int _indexAt(List<LyricLine> lines, Duration position) {
    var index = -1;

    for (var i = 0; i < lines.length; i++) {
      final time = lines[i].time;

      if (time == null) continue;

      if (time <= position) {
        index = i;
      } else {
        break;
      }
    }

    return index;
  }

  void _scrollTo(int index) {
    if (index < 0 || index >= _keys.length) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final targetContext = _keys[index].currentContext;
      if (targetContext == null) return;

      Scrollable.ensureVisible(
        targetContext,
        alignment: 0.4,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  Widget _message(
      BuildContext context,
      String message, {
        bool retry = false,
      }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              retry
                  ? Icons.cloud_off_rounded
                  : Icons.music_note_rounded,
              size: 52,
              color: cs.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 15),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            if (retry) ...[
              const SizedBox(height: 18),
              FilledButton.tonalIcon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba Lagi'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return FutureBuilder<Lyrics?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: cs.primary),
                const SizedBox(height: 16),
                Text(
                  'Sedang memuat lirik...',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return _message(
            context,
            'Gagal memuat lirik.\nPeriksa koneksi internetmu.',
            retry: true,
          );
        }

        final lyrics = snapshot.data;

        if (lyrics == null || lyrics.lines.isEmpty) {
          return _message(
            context,
            'Lirik untuk lagu ini belum tersedia.',
          );
        }

        if (_keys.length != lyrics.lines.length) {
          _keys = List.generate(
            lyrics.lines.length,
                (_) => GlobalKey(),
          );
        }

        // Lirik tanpa sinkronisasi waktu.
        if (!lyrics.synced) {
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(26, 20, 26, 40),
            itemCount: lyrics.lines.length,
            itemBuilder: (context, index) {
              final line = lyrics.lines[index];

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  line.text.isEmpty ? '♪' : line.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    height: 1.6,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              );
            },
          );
        }

        final player = context.read<PlayerProvider>().player;

        return StreamBuilder<Duration>(
          stream: player.positionStream,
          initialData: player.position,
          builder: (context, positionSnapshot) {
            final index = _indexAt(
              lyrics.lines,
              positionSnapshot.data ?? Duration.zero,
            );

            if (index != _active) {
              _active = index;
              _scrollTo(index);
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 100),
              child: Column(
                children: [
                  for (var i = 0; i < lyrics.lines.length; i++)
                    Container(
                      key: _keys[i],
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: i == index ? 23 : 17,
                          fontWeight: i == index
                              ? FontWeight.w900
                              : FontWeight.w600,
                          height: 1.45,
                          color: i == index
                              ? cs.primary
                              : cs.onSurfaceVariant.withValues(
                            alpha: 0.55,
                          ),
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
