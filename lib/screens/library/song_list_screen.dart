import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/playlist.dart';
import '../../models/song.dart';
import '../../providers/player_provider.dart';
import '../../services/library_service.dart';
import '../../widgets/mini_player.dart';
import '../../widgets/song_tile.dart';

class SongListScreen extends StatefulWidget {
  final String title;
  final IconData icon;
  final Future<List<Song>> Function() loader;
  final Playlist? playlist; // diisi kalau ini halaman playlist

  const SongListScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.loader,
    this.playlist,
  });

  @override
  State<SongListScreen> createState() => _SongListScreenState();
}

class _SongListScreenState extends State<SongListScreen> {
  late Future<List<Song>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.loader();
  }

  void _reload() {
    setState(() {
      _future = widget.loader();
    });
  }

  Future<void> _deletePlaylist() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus playlist?'),
        content: Text('"${widget.playlist!.name}" akan dihapus permanen.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true) return;
    await LibraryService().deletePlaylist(widget.playlist!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final player = context.read<PlayerProvider>();

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (widget.playlist != null)
            IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: _deletePlaylist),
        ],
      ),
      bottomNavigationBar: const SafeArea(child: MiniPlayer()),
      body: FutureBuilder<List<Song>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Center(child: CircularProgressIndicator(color: cs.primary));
          }
          if (snap.hasError) {
            return Center(child: Text('Gagal memuat\n${snap.error}',
                textAlign: TextAlign.center));
          }
          final songs = snap.data!;
          return ListView(
            children: [
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [cs.primary, cs.secondary],
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: cs.primary.withValues(alpha: 0.35),
                          blurRadius: 28,
                          offset: const Offset(0, 12)),
                    ],
                  ),
                  child: Icon(widget.icon, size: 64, color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(widget.title,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Text('${songs.length} lagu',
                    style: TextStyle(color: cs.onSurfaceVariant)),
              ),
              if (songs.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Putar'),
                          onPressed: () => player.playQueue(songs, 0),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            shape: const StadiumBorder(),
                            foregroundColor: cs.primary,
                            side: BorderSide(color: cs.primary),
                          ),
                          icon: const Icon(Icons.shuffle_rounded),
                          label: const Text('Acak'),
                          onPressed: () {
                            final shuffled = [...songs]..shuffle();
                            player.playQueue(shuffled, 0);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              if (songs.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Text(
                        widget.playlist != null
                            ? 'Playlist masih kosong.\nTambah lagu lewat menu ⋯ di lagu mana saja 💗'
                            : 'Belum ada lagu yang disukai.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.onSurfaceVariant)),
                  ),
                ),
              for (var i = 0; i < songs.length; i++)
                SongTile(
                  song: songs[i],
                  playlistId: widget.playlist?.id,
                  onChanged: _reload,
                  onTap: () => player.playQueue(songs, i),
                ),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }
}