
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/playlist.dart';
import '../../providers/history_provider.dart';
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
  final LibraryService _svc = LibraryService();

  late Future<List<Playlist>> _future;

  @override
  void initState() {
    super.initState();
    _future = _svc.playlists();
  }

  Future<void> _reload() async {
    final future = _svc.playlists();

    setState(() {
      _future = future;
    });

    await Future.wait([
      future,
      context.read<HistoryProvider>().load(),
    ]);
  }

  Future<void> _create() async {
    final name = await promptPlaylistName(context);

    if (name == null || name.trim().isEmpty) return;

    try {
      await _svc.createPlaylist(name.trim());

      if (!mounted) return;

      await _reload();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Playlist berhasil dibuat!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuat playlist: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );

    if (!mounted) return;

    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final likes = context.watch<LikesProvider>();
    final history = context.watch<HistoryProvider>();

    return SafeArea(
      child: Column(
        children: [
          // HEADER
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Koleksi Saya',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.7,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Semua musik favoritmu ada di sini.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _create,
                    child: Padding(
                      padding: const EdgeInsets.all(13),
                      child: Icon(
                        Icons.add_rounded,
                        color: cs.primary,
                        size: 27,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // CONTENT
          Expanded(
            child: RefreshIndicator(
              color: cs.primary,
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
                children: [
                  // FAVORITE CARD
                  _FavoriteCard(
                    count: likes.count,
                    onTap: () {
                      _open(
                        SongListScreen(
                          title: 'Lagu yang Disukai',
                          icon: Icons.favorite_rounded,
                          loader: _svc.likedSongs,
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 14),

                  // HISTORY CARD
                  _HistoryCard(
                    count: history.songs.length,
                    onTap: () {
                      _open(
                        SongListScreen(
                          title: 'Riwayat Pemutaran',
                          icon: Icons.history_rounded,
                          loader: () async {
                            return context.read<HistoryProvider>().songs;
                          },
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 28),

                  // PLAYLIST HEADER
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Playlist Saya',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _create,
                        icon: const Icon(Icons.add_rounded, size: 19),
                        label: const Text('Buat baru'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // PLAYLIST DATA
                  FutureBuilder<List<Playlist>>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState !=
                          ConnectionState.done) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 36),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: cs.primary,
                            ),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return _MessageCard(
                          icon: Icons.cloud_off_rounded,
                          title: 'Playlist gagal dimuat',
                          message:
                          'Periksa koneksi internet lalu coba lagi.',
                          action: TextButton(
                            onPressed: _reload,
                            child: const Text('Coba lagi'),
                          ),
                        );
                      }

                      final playlists = snapshot.data ?? [];

                      if (playlists.isEmpty) {
                        return _MessageCard(
                          icon: Icons.queue_music_rounded,
                          title: 'Belum ada playlist',
                          message:
                          'Buat playlist pertamamu dan kumpulkan lagu-lagu favorit dalam satu tempat.',
                          action: FilledButton.icon(
                            onPressed: _create,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Buat playlist'),
                          ),
                        );
                      }

                      return Column(
                        children: [
                          for (int i = 0; i < playlists.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _PlaylistCard(
                                playlist: playlists[i],
                                number: i + 1,
                                onTap: () {
                                  final playlist = playlists[i];

                                  _open(
                                    SongListScreen(
                                      title: playlist.name,
                                      icon: Icons.queue_music_rounded,
                                      playlist: playlist,
                                      loader: () =>
                                          _svc.playlistSongs(playlist.id),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  Center(
                    child: Text(
                      'Dengarkan musik, temukan suasana baru.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// FAVORITE CARD
class _FavoriteCard extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _FavoriteCard({
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              colors: [
                cs.primary,
                cs.secondary,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: cs.primary.withValues(alpha: 0.20),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lagu yang Disukai',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '$count lagu tersimpan',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// HISTORY CARD
class _HistoryCard extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _HistoryCard({
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(
                  Icons.history_rounded,
                  color: cs.primary,
                  size: 31,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Riwayat Pemutaran',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$count pemutaran terakhir',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: cs.onSurfaceVariant,
                size: 17,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// PLAYLIST CARD
class _PlaylistCard extends StatelessWidget {
  final Playlist playlist;
  final int number;
  final VoidCallback onTap;

  const _PlaylistCard({
    required this.playlist,
    required this.number,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: LinearGradient(
                    colors: [
                      cs.primaryContainer,
                      cs.secondaryContainer,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(
                  Icons.queue_music_rounded,
                  color: cs.primary,
                  size: 29,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Playlist pribadi',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: cs.onSurfaceVariant,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// EMPTY / ERROR CARD
class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 22,
        vertical: 30,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 42,
            color: cs.primary,
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              height: 1.5,
              fontSize: 13,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );
  }
}
