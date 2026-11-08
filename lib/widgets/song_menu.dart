import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../providers/likes_provider.dart';
import '../services/library_service.dart';
import 'cover_image.dart';

/// Dialog input nama playlist. Return null kalau dibatalkan.
Future<String?> promptPlaylistName(BuildContext context) {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Playlist baru'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Nama playlist'),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
        TextButton(
          onPressed: () {
            final t = ctrl.text.trim();
            Navigator.pop(ctx, t.isEmpty ? null : t);
          },
          child: const Text('Buat'),
        ),
      ],
    ),
  );
}

Future<void> showAddToPlaylist(BuildContext context, Song song) async {
  final svc = LibraryService();
  final messenger = ScaffoldMessenger.of(context);
  List<Playlist> lists = [];
  try {
    lists = await svc.playlists();
  } catch (_) {}
  if (!context.mounted) return;

  void toast(String msg) =>
      messenger.showSnackBar(SnackBar(content: Text(msg)));

  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      return SafeArea(
        child: ConstrainedBox(
          constraints:
          BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Tambah ke playlist',
                    style:
                    TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              ),
              ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.add_rounded, color: cs.primary),
                ),
                title: const Text('Playlist baru',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (!context.mounted) return;
                  final name = await promptPlaylistName(context);
                  if (name == null) return;
                  try {
                    final pl = await svc.createPlaylist(name);
                    await svc.addToPlaylist(pl.id, song);
                    toast('Ditambahkan ke "$name"');
                  } catch (e) {
                    toast('Gagal: $e');
                  }
                },
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final pl in lists)
                      ListTile(
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.queue_music_rounded,
                              color: cs.primary),
                        ),
                        title: Text(pl.name,
                            style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                        onTap: () async {
                          Navigator.pop(ctx);
                          try {
                            await svc.addToPlaylist(pl.id, song);
                            toast('Ditambahkan ke "${pl.name}"');
                          } catch (e) {
                            toast('Gagal: $e');
                          }
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

void showSongMenu(
    BuildContext context,
    Song song, {
      String? playlistId,
      VoidCallback? onChanged,
    }) {
  final likes = context.read<LikesProvider>();
  final liked = likes.isLiked(song.id);
  final messenger = ScaffoldMessenger.of(context);

  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: CoverImage(url: song.coverUrl, size: 48),
            title: Text(song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(song.artist),
          ),
          const Divider(),
          ListTile(
            leading: Icon(
                liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: Theme.of(ctx).colorScheme.primary),
            title: Text(liked ? 'Hapus dari Disukai' : 'Tambah ke Disukai'),
            onTap: () async {
              Navigator.pop(ctx);
              await likes.toggle(song);
              onChanged?.call();
            },
          ),
          ListTile(
            leading: const Icon(Icons.playlist_add_rounded),
            title: const Text('Tambah ke playlist'),
            onTap: () {
              Navigator.pop(ctx);
              showAddToPlaylist(context, song);
            },
          ),
          if (playlistId != null)
            ListTile(
              leading: const Icon(Icons.remove_circle_outline_rounded),
              title: const Text('Hapus dari playlist ini'),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  await LibraryService().removeFromPlaylist(playlistId, song.id);
                  onChanged?.call();
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text('Gagal: $e')));
                }
              },
            ),
        ],
      ),
    ),
  );
}