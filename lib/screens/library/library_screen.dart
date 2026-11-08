import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/playlist.dart';
import '../../providers/likes_provider.dart';
import '../../services/library_service.dart';
import '../../widgets/song_menu.dart';
import 'song_list_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _svc = LibraryService();
  late Future<List<Playlist>> _future;

  @override
  void initState() {
    super.initState();
    _future = _svc.playlists();
  }

  void _reload() {
    setState(() {
      _future = _svc.playlists();
    });
  }

  Future<void> _create() async {
    final name = await promptPlaylistName(context);
    if (name == null) return;
    try {
      await _svc.createPlaylist(name);
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final likes = context.watch<LikesProvider>();

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text('Koleksi',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  icon: Icon(Icons.add_rounded, color: cs.primary, size: 30),
                  onPressed: _create,
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: cs.primary,
              onRefresh: () async => _reload(),
              child: ListView(
                children: [
                  ListTile(
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    leading: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                            colors: [cs.primary, cs.secondary]),
                      ),
                      child: const Icon(Icons.favorite_rounded,
                          color: Colors.white),
                    ),
                    title: const Text('Lagu yang Disukai',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${likes.count} lagu'),
                    onTap: () => _open(SongListScreen(
                      title: 'Lagu yang Disukai',
                      icon: Icons.favorite_rounded,
                      loader: _svc.likedSongs,
                    )),
                  ),
                  FutureBuilder<List<Playlist>>(
                    future: _future,
                    builder: (context, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                              child: CircularProgressIndicator(
                                  color: cs.primary)),
                        );
                      }
                      if (snap.hasError) {
                        return Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('Gagal memuat playlist\n${snap.error}',
                              textAlign: TextAlign.center),
                        );
                      }
                      final lists = snap.data!;
                      if (lists.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(40),
                          child: Center(
                            child: Text(
                                'Belum ada playlist.\nTekan + untuk membuat 💗',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: cs.onSurfaceVariant)),
                          ),
                        );
                      }
                      return Column(
                        children: [
                          for (final pl in lists)
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 4),
                              leading: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: cs.primaryContainer,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(Icons.queue_music_rounded,
                                    color: cs.primary),
                              ),
                              title: Text(pl.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              subtitle: const Text('Playlist'),
                              onTap: () => _open(SongListScreen(
                                title: pl.name,
                                icon: Icons.queue_music_rounded,
                                playlist: pl,
                                loader: () => _svc.playlistSongs(pl.id),
                              )),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}