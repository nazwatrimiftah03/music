
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../../providers/likes_provider.dart';
import '../../providers/player_provider.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/lyrics_sheet.dart';
import '../../widgets/queue_sheet.dart';
import '../../widgets/sleep_timer_sheet.dart';
import '../../widgets/song_menu.dart';
import '../artist/artist_screen.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  double? _drag;
  String? _dragSongId;

  String _fmt(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }

    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final likes = context.watch<LikesProvider>();
    final song = player.current;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (song == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.music_off_rounded,
                  size: 60,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                const Text('Belum ada lagu yang diputar'),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Kembali'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Reset posisi slider ketika lagu berganti.
    if (_dragSongId != song.id) {
      _dragSongId = song.id;
      _drag = null;
    }

    final liked = likes.isLiked(song.id);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              cs.primaryContainer,
              cs.surface,
              theme.scaffoldBackgroundColor,
            ],
            stops: const [0, 0.48, 1],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = MediaQuery.of(context).size.width;
              final availableHeight = constraints.maxHeight;

              final coverSize = math.min(
                screenWidth - 48,
                math.max(150.0, availableHeight * 0.36),
              );

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: availableHeight,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        // HEADER
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              tooltip: 'Kembali',
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 32,
                              ),
                            ),
                            Column(
                              children: [
                                Text(
                                  'SEDANG DIPUTAR',
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 10,
                                    letterSpacing: 1.8,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'PinkBeat Player',
                                  style: TextStyle(
                                    color: cs.onSurface,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              tooltip: 'Menu lagu',
                              onPressed: () => showSongMenu(context, song),
                              icon: const Icon(
                                Icons.more_horiz_rounded,
                                size: 27,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 22),

                        // COVER ALBUM
                        Center(
                          child: Container(
                            width: coverSize,
                            height: coverSize,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(
                                  color: cs.primary.withValues(alpha: 0.24),
                                  blurRadius: 32,
                                  offset: const Offset(0, 15),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(25),
                              child: CoverImage(
                                url: song.coverUrl,
                                size: coverSize,
                                radius: 25,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // JUDUL DAN FAVORIT
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    song.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: hasArtistPage(song.artist)
                                        ? () => openArtist(
                                      context,
                                      song.artist,
                                    )
                                        : null,
                                    child: Text(
                                      song.artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            IconButton(
                              tooltip: liked
                                  ? 'Hapus dari favorit'
                                  : 'Tambahkan ke favorit',
                              onPressed: () => likes.toggle(song),
                              icon: Icon(
                                liked
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: liked
                                    ? cs.primary
                                    : cs.onSurfaceVariant,
                                size: 29,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // PROGRESS LAGU
                        StreamBuilder<Duration?>(
                          stream: player.player.durationStream,
                          initialData: player.player.duration,
                          builder: (context, durationSnapshot) {
                            final duration =
                                durationSnapshot.data ?? Duration.zero;

                            return StreamBuilder<Duration>(
                              stream: player.player.positionStream,
                              initialData: player.player.position,
                              builder: (context, positionSnapshot) {
                                final position =
                                    positionSnapshot.data ?? Duration.zero;

                                final maxValue = math.max(
                                  1.0,
                                  duration.inMilliseconds.toDouble(),
                                );

                                final currentValue = (_drag ??
                                    position.inMilliseconds.toDouble())
                                    .clamp(0.0, maxValue);

                                final displayPosition = _drag != null
                                    ? Duration(
                                  milliseconds: _drag!.toInt(),
                                )
                                    : position;

                                return Column(
                                  children: [
                                    SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        trackHeight: 4,
                                        thumbShape:
                                        const RoundSliderThumbShape(
                                          enabledThumbRadius: 6,
                                        ),
                                        overlayShape:
                                        const RoundSliderOverlayShape(
                                          overlayRadius: 15,
                                        ),
                                        activeTrackColor: cs.primary,
                                        inactiveTrackColor:
                                        cs.onSurface.withValues(
                                          alpha: 0.12,
                                        ),
                                        thumbColor: cs.primary,
                                      ),
                                      child: Slider(
                                        value: currentValue,
                                        max: maxValue,
                                        onChanged: duration == Duration.zero
                                            ? null
                                            : (value) {
                                          setState(() {
                                            _drag = value;
                                          });
                                        },
                                        onChangeEnd: duration == Duration.zero
                                            ? null
                                            : (value) {
                                          player.seek(
                                            Duration(
                                              milliseconds:
                                              value.toInt(),
                                            ),
                                          );

                                          setState(() {
                                            _drag = null;
                                          });
                                        },
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _fmt(displayPosition),
                                            style: TextStyle(
                                              color: cs.onSurfaceVariant,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            _fmt(duration),
                                            style: TextStyle(
                                              color: cs.onSurfaceVariant,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),

                        const SizedBox(height: 17),

                        // KONTROL PEMUTARAN
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              tooltip: 'Acak lagu',
                              onPressed: player.toggleShuffle,
                              icon: Icon(
                                Icons.shuffle_rounded,
                                color: player.shuffle
                                    ? cs.primary
                                    : cs.onSurfaceVariant,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Lagu sebelumnya',
                              iconSize: 35,
                              onPressed: player.previous,
                              icon: const Icon(
                                Icons.skip_previous_rounded,
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: cs.primary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: cs.primary.withValues(alpha: 0.3),
                                    blurRadius: 18,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                tooltip: player.isPlaying ? 'Jeda' : 'Putar',
                                iconSize: 39,
                                padding: const EdgeInsets.all(14),
                                color: cs.onPrimary,
                                onPressed: player.togglePlay,
                                icon: Icon(
                                  player.isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Lagu berikutnya',
                              iconSize: 35,
                              onPressed: player.next,
                              icon: const Icon(
                                Icons.skip_next_rounded,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Mode pengulangan',
                              onPressed: player.cycleLoop,
                              icon: Icon(
                                player.loop == LoopMode.one
                                    ? Icons.repeat_one_rounded
                                    : Icons.repeat_rounded,
                                color: player.loop == LoopMode.off
                                    ? cs.onSurfaceVariant
                                    : cs.primary,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 15),

                        // FITUR TAMBAHAN
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: cs.surface.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: cs.outline.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              const SleepTimerButton(),
                              _ExtraButton(
                                icon: Icons.lyrics_outlined,
                                label: 'Lirik',
                                onTap: () => showLyricsSheet(context),
                              ),
                              _ExtraButton(
                                icon: Icons.queue_music_rounded,
                                label: 'Antrean',
                                onTap: () => showQueueSheet(context),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 22),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ExtraButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ExtraButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: cs.onSurfaceVariant,
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 9,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }
}
