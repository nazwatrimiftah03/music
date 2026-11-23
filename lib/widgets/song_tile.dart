
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../providers/player_provider.dart';
import '../services/itunes_service.dart';
import 'cover_image.dart';
import 'song_menu.dart';

class SongTile extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;
  final String? playlistId;
  final VoidCallback? onChanged;

  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.playlistId,
    this.onChanged,
  });

  /// Lagu dari iTunes hanya berupa cuplikan 30 detik.
  bool get _isPreview => song.id.startsWith(ItunesService.idPrefix);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final player = context.watch<PlayerProvider>();
    final isCurrent = player.current?.id == song.id;
    final isPlaying = isCurrent && player.isPlaying;

    return Material(
      color: isCurrent
          ? cs.primary.withValues(alpha: 0.06)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          child: Row(
            children: [
              // COVER LAGU
              Stack(
                children: [
                  CoverImage(
                    url: song.coverUrl,
                    size: 52,
                    radius: 10,
                  ),
                  if (isPlaying)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.graphic_eq_rounded,
                          color: Colors.white,
                          size: 25,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(width: 12),

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
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isCurrent ? cs.primary : cs.onSurface,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Row(
                      children: [
                        if (_isPreview) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              '30 dtk',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],

                        Expanded(
                          child: Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 4),

              // MENU LAGU
              IconButton(
                tooltip: 'Menu lagu',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.more_horiz_rounded,
                  color: cs.onSurfaceVariant,
                  size: 24,
                ),
                onPressed: () {
                  showSongMenu(
                    context,
                    song,
                    playlistId: playlistId,
                    onChanged: onChanged,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
