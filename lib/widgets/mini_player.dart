
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/player_provider.dart';
import '../screens/player/now_playing_screen.dart';
import 'cover_image.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final song = player.current;
    final cs = Theme.of(context).colorScheme;

    if (song == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 5),
      child: Material(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NowPlayingScreen(),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: cs.outline.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 9, 5, 8),
                  child: Row(
                    children: [
                      // COVER LAGU
                      ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: CoverImage(
                          url: song.coverUrl,
                          size: 46,
                          radius: 11,
                        ),
                      ),

                      const SizedBox(width: 11),

                      // INFORMASI LAGU
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: cs.onSurface,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 5),

                      // INDIKATOR MUSIK
                      Icon(
                        Icons.graphic_eq_rounded,
                        color: player.isPlaying
                            ? cs.primary
                            : cs.onSurfaceVariant,
                        size: 21,
                      ),

                      const SizedBox(width: 5),

                      // PLAY / PAUSE
                      Material(
                        color: cs.primaryContainer,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: player.togglePlay,
                          child: SizedBox(
                            width: 38,
                            height: 38,
                            child: Icon(
                              player.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: cs.primary,
                              size: 24,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 3),

                      // NEXT SONG
                      IconButton(
                        tooltip: 'Lagu berikutnya',
                        visualDensity: VisualDensity.compact,
                        onPressed: player.next,
                        icon: Icon(
                          Icons.skip_next_rounded,
                          color: cs.onSurface,
                          size: 25,
                        ),
                      ),
                    ],
                  ),
                ),

                // PROGRESS BAR
                StreamBuilder<Duration>(
                  stream: player.player.positionStream,
                  builder: (context, snapshot) {
                    final position = snapshot.data ?? Duration.zero;
                    final duration =
                        player.player.duration ?? Duration.zero;

                    final progress = duration.inMilliseconds > 0
                        ? (position.inMilliseconds /
                        duration.inMilliseconds)
                        .clamp(0.0, 1.0)
                        : 0.0;

                    return ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(18),
                        bottomRight: Radius.circular(18),
                      ),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                        backgroundColor:
                        cs.onSurface.withValues(alpha: 0.06),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          cs.primary,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
