
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/playlist.dart';
import '../../models/song.dart';
import '../../providers/player_provider.dart';
import '../../services/library_service.dart';
import '../../widgets/mini_player.dart';
import '../../widgets/song_menu.dart';
import '../../widgets/song_tile.dart';

class SongListScreen extends StatefulWidget {
  final String title;
  final IconData icon;
  final Future<List<Song>> Function() loader;
  final Playlist? playlist;
  final String? emptyText;
  final bool allowSaveAsPlaylist;

  const SongListScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.loader,
    this.playlist,
    this.emptyText,
    this.allowSaveAsPlaylist = false,
  });

  @override
  State<SongListScreen> createState() => _SongListScreenState();
}

class _SongListScreenState extends State<SongListScreen> {
  late Future<List<Song>> _future;

  bool _saving = false;
  bool _saved = false;
  bool _deleting = false;
  bool _renaming = false;

  late String _title;

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr',
    'Mei', 'Jun', 'Jul', 'Agu',
    'Sep', 'Okt', 'Nov', 'Des',
  ];

  @override
  void initState() {
    super.initState();
    _title = widget.title;
    _future = widget.loader();
  }

  Future<void> _reload() async {
    if (!mounted) return;

    final future = widget.loader();

    setState(() {
      _future = future;
    });

    try {
      await future;
    } catch (_) {
      // Kesalahan ditampilkan melalui FutureBuilder.
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _saveAsPlaylist() async {
    if (_saving || _saved) return;

    List<Song> songs;

    try {
      songs = await _future;
    } catch (_) {
      _showMessage('Gagal memuat lagu. Coba lagi.');
      return;
    }

    if (!mounted) return;

    if (songs.isEmpty) {
      _showMessage('Belum ada lagu untuk disimpan.');
      return;
    }

    setState(() {
      _saving = true;
    });

    final now = DateTime.now();
    final name = '${widget.title} ${now.day} ${_months[now.month - 1]}';

    try {
      final service = LibraryService();
      final created = await service.createPlaylist(name);

      for (final song in songs) {
        await service.addToPlaylist(created.id, song);
      }

      if (!mounted) return;

      setState(() {
        _saved = true;
      });

      _showMessage('Berhasil disimpan sebagai "$name".');
    } catch (e) {
      _showMessage('Gagal menyimpan playlist: $e');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _renamePlaylist() async {
    if (_renaming || widget.playlist == null) return;

    final name = await promptPlaylistName(
      context,
      initial: _title,
    );

    if (!mounted || name == null) return;

    final cleanedName = name.trim();

    if (cleanedName.isEmpty || cleanedName == _title) return;

    setState(() {
      _renaming = true;
    });

    try {
      await LibraryService().renamePlaylist(
        widget.playlist!.id,
        cleanedName,
      );

      if (!mounted) return;

      setState(() {
        _title = cleanedName;
      });

      _showMessage('Nama playlist berhasil diubah.');
    } catch (e) {
      _showMessage('Gagal mengubah nama playlist: $e');
    } finally {
      if (mounted) {
        setState(() {
          _renaming = false;
        });
      }
    }
  }

  Future<void> _deletePlaylist() async {
    if (_deleting || widget.playlist == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;

        return AlertDialog(
          icon: Icon(
            Icons.delete_outline_rounded,
            size: 36,
            color: cs.error,
          ),
          title: const Text('Hapus Playlist?'),
          content: Text(
            'Playlist "$_title" akan dihapus. '
                'Tindakan ini tidak dapat dibatalkan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: cs.error,
                foregroundColor: cs.onError,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) return;

    setState(() {
      _deleting = true;
    });

    try {
      await LibraryService().deletePlaylist(widget.playlist!.id);

      if (!mounted) return;

      Navigator.pop(context);
    } catch (e) {
      _showMessage('Gagal menghapus playlist: $e');
    } finally {
      if (mounted) {
        setState(() {
          _deleting = false;
        });
      }
    }
  }

  void _playAll(List<Song> songs) {
    if (songs.isEmpty) return;

    context.read<PlayerProvider>().playQueue(songs, 0);
  }

  void _shuffleAll(List<Song> songs) {
    if (songs.isEmpty) return;

    final shuffled = List<Song>.of(songs)..shuffle();

    context.read<PlayerProvider>().playQueue(shuffled, 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          if (widget.allowSaveAsPlaylist)
            _buildSaveButton(cs),

          if (widget.playlist != null) ...[
            IconButton(
              tooltip: 'Ganti nama',
              onPressed: _renaming ? null : _renamePlaylist,
              icon: _renaming
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
                  : const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Hapus playlist',
              onPressed: _deleting ? null : _deletePlaylist,
              icon: _deleting
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
                  : const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ],
      ),
      bottomNavigationBar: const SafeArea(
        child: MiniPlayer(),
      ),
      body: FutureBuilder<List<Song>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(
              child: CircularProgressIndicator(
                color: cs.primary,
              ),
            );
          }

          if (snapshot.hasError) {
            return _buildError(cs);
          }

          final songs = snapshot.data ?? <Song>[];

          return RefreshIndicator(
            color: cs.primary,
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 30),
              children: [
                _buildHeader(
                  context,
                  songs,
                  cs,
                  theme,
                ),

                const SizedBox(height: 22),

                if (songs.isNotEmpty)
                  _buildSongHeading(
                    songs.length,
                    cs,
                    theme,
                  ),

                if (songs.isNotEmpty)
                  ...List.generate(
                    songs.length,
                        (index) {
                      return SongTile(
                        song: songs[index],
                        playlistId: widget.playlist?.id,
                        onChanged: _reload,
                        onTap: () {
                          context.read<PlayerProvider>().playQueue(
                            songs,
                            index,
                          );
                        },
                      );
                    },
                  ),

                if (songs.isEmpty)
                  _buildEmpty(cs, theme),

                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSaveButton(ColorScheme cs) {
    if (_saving) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    return IconButton(
      tooltip: _saved
          ? 'Sudah disimpan'
          : 'Simpan jadi playlist',
      onPressed: _saved ? null : _saveAsPlaylist,
      icon: Icon(
        _saved
            ? Icons.check_circle_rounded
            : Icons.playlist_add_rounded,
        color: _saved ? cs.primary : null,
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context,
      List<Song> songs,
      ColorScheme cs,
      ThemeData theme,
      ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 25),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withValues(alpha: 0.22),
            cs.secondary.withValues(alpha: 0.12),
            cs.surface,
          ],
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 174,
            height: 174,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cs.primary,
                  cs.secondary,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.30),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Icon(
              widget.icon,
              size: 76,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 22),

          Text(
            _title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            '${songs.length} lagu',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),

          if (songs.isNotEmpty) ...[
            const SizedBox(height: 22),

            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Putar Semua'),
                    onPressed: () => _playAll(songs),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.shuffle_rounded),
                    label: const Text('Acak'),
                    onPressed: () => _shuffleAll(songs),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      foregroundColor: cs.primary,
                      side: BorderSide(color: cs.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSongHeading(
      int total,
      ColorScheme cs,
      ThemeData theme,
      ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Daftar Lagu',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            '$total lagu',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(
      ColorScheme cs,
      ThemeData theme,
      ) {
    final message = widget.emptyText ??
        (widget.playlist != null
            ? 'Playlist masih kosong.\n'
            'Tambahkan lagu melalui menu pada lagu.'
            : 'Belum ada lagu yang disukai.');

    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 55, 30, 55),
      child: Column(
        children: [
          Container(
            width: 105,
            height: 105,
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.65),
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.icon,
              size: 48,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Belum Ada Lagu',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 58,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Gagal Memuat Lagu',
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Periksa koneksi internet dan coba kembali.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
