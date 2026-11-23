
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/playlist.dart';
import '../models/song.dart';
import '../providers/likes_provider.dart';
import '../providers/player_provider.dart';
import '../screens/artist/artist_screen.dart';
import '../services/library_service.dart';
import 'cover_image.dart';

/// Dialog input nama playlist.
Future<String?> promptPlaylistName(
    BuildContext context, {
      String? initial,
    }) {
  final ctrl = TextEditingController(text: initial);

  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        initial == null ? 'Playlist baru' : 'Ganti nama playlist',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        maxLength: 40,
        decoration: InputDecoration(
          hintText: 'Nama playlist',
          prefixIcon: const Icon(Icons.queue_music_rounded),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            final name = ctrl.text.trim();
            Navigator.pop(ctx, name.isEmpty ? null : name);
          },
          child: Text(initial == null ? 'Buat' : 'Simpan'),
        ),
      ],
    ),
  ).whenComplete(ctrl.dispose);
}

/// Menampilkan pilihan playlist.
Future<void> showAddToPlaylist(
    BuildContext context,
    Song song,
    ) async {
  final svc = LibraryService();
  final messenger = ScaffoldMessenger.of(context);

  List<Playlist> lists = [];
  String? loadError;

  try {
    lists = await svc.playlists();
  } catch (e) {
    loadError = e.toString();
  }

  if (!context.mounted) return;

  void toast(String message) {
    messenger.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;

      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.65,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(
                  'Tambah ke playlist',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              // MEMBUAT PLAYLIST
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    color: cs.primary,
                  ),
                ),
                title: const Text(
                  'Playlist baru',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('Buat koleksi lagu baru'),
                onTap: () async {
                  Navigator.pop(ctx);

                  if (!context.mounted) return;

                  final name = await promptPlaylistName(context);

                  if (name == null || !context.mounted) return;

                  try {
                    final playlist = await svc.createPlaylist(name);
                    await svc.addToPlaylist(playlist.id, song);

                    if (context.mounted) {
                      toast('Ditambahkan ke "$name"');
                    }
                  } catch (e) {
                    if (context.mounted) {
                      toast('Gagal menambahkan lagu: $e');
                    }
                  }
                },
              ),

              const Divider(height: 12),

              if (loadError != null)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Gagal memuat playlist: $loadError',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.error),
                  ),
                )
              else if (lists.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.library_music_outlined,
                        size: 38,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Belum ada playlist',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 4),
                      Text('Buat playlist baru untuk menyimpan lagu.'),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: lists.length,
                    itemBuilder: (context, index) {
                      final playlist = lists[index];

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                        ),
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: cs.secondaryContainer,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.queue_music_rounded,
                            color: cs.onSecondaryContainer,
                          ),
                        ),
                        title: Text(
                          playlist.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.add_circle_outline_rounded,
                        ),
                        onTap: () async {
                          Navigator.pop(ctx);

                          try {
                            await svc.addToPlaylist(playlist.id, song);

                            if (context.mounted) {
                              toast('Ditambahkan ke "${playlist.name}"');
                            }
                          } catch (e) {
                            if (context.mounted) {
                              toast('Gagal menambahkan lagu: $e');
                            }
                          }
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// Menampilkan menu tindakan lagu.
void showSongMenu(
    BuildContext context,
    Song song, {
      String? playlistId,
      VoidCallback? onChanged,
    }) {
  final likes = context.read<LikesProvider>();
  final player = context.read<PlayerProvider>();
  final liked = likes.isLiked(song.id);
  final messenger = ScaffoldMessenger.of(context);
  final cs = Theme.of(context).colorScheme;

  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // INFORMASI LAGU
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CoverImage(
                    url: song.coverUrl,
                    size: 54,
                    radius: 12,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // DISUKAI
          _SongMenuItem(
            icon: liked
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            color: liked ? cs.primary : null,
            title: liked ? 'Hapus dari Disukai' : 'Tambah ke Disukai',
            onTap: () async {
              Navigator.pop(ctx);
              await likes.toggle(song);
              onChanged?.call();
            },
          ),

          // PUTAR BERIKUTNYA
          _SongMenuItem(
            icon: Icons.playlist_play_rounded,
            title: 'Putar berikutnya',
            onTap: () async {
              Navigator.pop(ctx);

              final queued = await player.playNext(song);

              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    queued
                        ? 'Akan diputar setelah lagu ini'
                        : 'Memutar "${song.title}"',
                  ),
                ),
              );
            },
          ),

          // TAMBAH ANTREAN
          _SongMenuItem(
            icon: Icons.queue_music_rounded,
            title: 'Tambah ke antrean',
            onTap: () async {
              Navigator.pop(ctx);

              final queued = await player.addToQueue(song);

              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    queued
                        ? 'Ditambahkan ke antrean'
                        : 'Memutar "${song.title}"',
                  ),
                ),
              );
            },
          ),

          // TAMBAH PLAYLIST
          _SongMenuItem(
            icon: Icons.playlist_add_rounded,
            title: 'Tambah ke playlist',
            onTap: () {
              Navigator.pop(ctx);
              showAddToPlaylist(context, song);
            },
          ),

          // HALAMAN ARTIS
          if (hasArtistPage(song.artist))
            _SongMenuItem(
              icon: Icons.person_outline_rounded,
              title: 'Lihat artis: ${song.artist}',
              onTap: () {
                Navigator.pop(ctx);
                openArtist(context, song.artist);
              },
            ),

          // HAPUS DARI PLAYLIST
          if (playlistId != null)
            _SongMenuItem(
              icon: Icons.remove_circle_outline_rounded,
              color: cs.error,
              title: 'Hapus dari playlist ini',
              onTap: () async {
                Navigator.pop(ctx);

                try {
                  await LibraryService().removeFromPlaylist(
                    playlistId,
                    song.id,
                  );

                  onChanged?.call();
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Gagal: $e')),
                  );
                }
              },
            ),

          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}

/// Komponen pilihan pada menu lagu.
class _SongMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;

  const _SongMenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 22),
      leading: Icon(
        icon,
        color: color ?? cs.onSurfaceVariant,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: color ?? cs.onSurface,
        ),
      ),
      onTap: onTap,
    );
  }
}
