import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import 'cover_image.dart';

/// Panel antrean: lihat semua lagu, ketuk untuk loncat, hapus yang tidak perlu,
/// dan geser ikon ☰ di kanan untuk mengubah urutan.
void showQueueSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
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
    final cs = Theme.of(context).colorScheme;
    final p = context.watch<PlayerProvider>();
    final queue = p.queue;
    final now = p.currentIndex;

    if (queue.isEmpty) {
      return Center(
        child: Text('Antrean masih kosong',
            style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }

    final upcoming = queue.length - now - 1;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Row(
            children: [
              Expanded(
                child: Text('Antrean',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ),
              Text(
                upcoming > 0 ? '$upcoming lagu berikutnya' : 'Lagu terakhir',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            scrollController: controller,
            buildDefaultDragHandles: false,
            itemCount: queue.length,
            // onReorderItem sudah menghitung posisi akhir lagunya.
            onReorderItem: (oldIndex, newIndex) =>
                p.moveInQueue(oldIndex, newIndex),
            itemBuilder: (context, i) {
              final song = queue[i];
              final isNow = i == now;
              final played = i < now;

              return Opacity(
                // Lagu yang sama boleh muncul dua kali, jadi kuncinya
                // digabung dengan posisi.
                key: ValueKey('${i}_${song.id}'),
                opacity: played ? 0.5 : 1,
                child: ListTile(
                  onTap: () => p.jumpTo(i),
                  contentPadding: const EdgeInsets.only(left: 24, right: 8),
                  leading: Stack(
                    alignment: Alignment.center,
                    children: [
                      CoverImage(url: song.coverUrl, size: 48),
                      if (isNow)
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            p.isPlaying
                                ? Icons.equalizer_rounded
                                : Icons.pause_rounded,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                  title: Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isNow ? cs.primary : cs.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    isNow ? 'Sedang diputar • ${song.artist}' : song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isNow)
                        IconButton(
                          tooltip: 'Hapus dari antrean',
                          icon: Icon(Icons.close_rounded,
                              color: cs.onSurfaceVariant),
                          onPressed: () => p.removeFromQueue(i),
                        ),
                      ReorderableDragStartListener(
                        index: i,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Icon(Icons.drag_handle_rounded,
                              color: cs.onSurfaceVariant),
                        ),
                      ),
                    ],
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