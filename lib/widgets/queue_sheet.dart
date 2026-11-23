
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/player_provider.dart';
import 'cover_image.dart';

void showQueueSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => _QueueList(controller: scroll),
    ),
  );
}

class _QueueList extends StatelessWidget {
  final ScrollController controller;

  const _QueueList({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final p = context.watch<PlayerProvider>();
    final queue = p.queue;
    final now = p.currentIndex;

    if (queue.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.queue_music_rounded,
              size: 64,
              color: cs.primary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 14),
            Text(
              'Antrean masih kosong',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tambahkan lagu untuk mulai mendengarkan',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    final upcoming = (queue.length - now - 1).clamp(0, queue.length);

    return Column(
      children: [
        // HEADER
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cs.primary, cs.secondary],
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.queue_music_rounded,
                  color: Colors.white,
                  size: 27,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Antrean Lagu',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${queue.length} lagu dalam antrean',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  upcoming > 0 ? '$upcoming berikutnya' : 'Selesai',
                  style: TextStyle(
                    color: cs.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),

        // LABEL DAFTAR
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Row(
            children: [
              Text(
                'DAFTAR PUTAR',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.swap_vert_rounded,
                size: 16,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                'Geser untuk mengatur',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // DAFTAR LAGU
        Expanded(
          child: ReorderableListView.builder(
            scrollController: controller,
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
            itemCount: queue.length,
            onReorderItem: (oldIndex, newIndex) {
              p.moveInQueue(oldIndex, newIndex);
            },
            itemBuilder: (context, i) {
              final song = queue[i];
              final isNow = i == now;
              final played = i < now;

              return Container(
                key: ValueKey('${i}_${song.id}'),
                margin: const EdgeInsets.only(bottom: 9),
                decoration: BoxDecoration(
                  color: isNow
                      ? cs.primary.withValues(alpha: 0.09)
                      : cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: isNow
                        ? cs.primary.withValues(alpha: 0.4)
                        : cs.outlineVariant.withValues(alpha: 0.35),
                  ),
                ),
                child: Opacity(
                  opacity: played ? 0.55 : 1,
                  child: ListTile(
                    onTap: () => p.jumpTo(i),
                    contentPadding: const EdgeInsets.only(
                      left: 12,
                      right: 5,
                    ),
                    leading: Stack(
                      alignment: Alignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: CoverImage(
                            url: song.coverUrl,
                            size: 49,
                          ),
                        ),
                        if (isNow)
                          Container(
                            width: 49,
                            height: 49,
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(
                              p.isPlaying
                                  ? Icons.equalizer_rounded
                                  : Icons.pause_rounded,
                              color: Colors.white,
                              size: 25,
                            ),
                          ),
                      ],
                    ),
                    title: Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: isNow ? cs.primary : cs.onSurface,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          if (isNow) ...[
                            Icon(
                              Icons.equalizer_rounded,
                              size: 13,
                              color: cs.primary,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'SEDANG DIPUTAR • ${song.artist}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: cs.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ] else
                            Expanded(
                              child: Text(
                                played
                                    ? 'Sudah diputar • ${song.artist}'
                                    : song.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isNow)
                          IconButton(
                            tooltip: 'Hapus dari antrean',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => p.removeFromQueue(i),
                            icon: Icon(
                              Icons.close_rounded,
                              color: cs.onSurfaceVariant,
                              size: 20,
                            ),
                          ),
                        ReorderableDragStartListener(
                          index: i,
                          child: Padding(
                            padding: const EdgeInsets.all(9),
                            child: Icon(
                              Icons.drag_handle_rounded,
                              color: cs.onSurfaceVariant,
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
