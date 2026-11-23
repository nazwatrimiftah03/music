
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/song.dart';
import '../../providers/player_provider.dart';
import '../../services/song_service.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/mini_player.dart';
import '../../widgets/song_tile.dart';

void openArtist(BuildContext context, String artist) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ArtistScreen(artist: artist),
    ),
  );
}

bool hasArtistPage(String artist) {
  final a = artist.trim().toLowerCase();
  return a.isNotEmpty && a != 'unknown artist';
}

class ArtistScreen extends StatefulWidget {
  final String artist;

  const ArtistScreen({
    super.key,
    required this.artist,
  });

  @override
  State<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends State<ArtistScreen> {
  static const int _topCount = 5;

  late Future<List<Song>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Song>> _load() async {
    final svc = SongService();

    final all = await svc.byArtist(widget.artist);
    final popular = await svc.popular(
      artist: widget.artist,
      limit: 20,
    );

    if (popular.isEmpty) return all;

    final rank = <String, int>{
      for (var i = 0; i < popular.length; i++)
        popular[i].id: i,
    };

    final ranked = all
        .where((song) => rank.containsKey(song.id))
        .toList()
      ..sort(
            (a, b) => rank[a.id]!.compareTo(rank[b.id]!),
      );

    final others = all.where(
          (song) => !rank.containsKey(song.id),
    );

    return [...ranked, ...others];
  }

  Future<void> _reload() async {
    final future = _load();

    setState(() {
      _future = future;
    });

    await future;
  }

  String? _coverOf(List<Song> songs) {
    for (final song in songs) {
      if (song.coverUrl.isNotEmpty) {
        return song.coverUrl;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
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

          return _buildContent(
            context,
            snapshot.data ?? const <Song>[],
          );
        },
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
              'Gagal memuat halaman artis',
              style: TextStyle(
                color: cs.onSurface,
                fontWeight: FontWeight.w800,
                fontSize: 17,
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
              onPressed: () {
                setState(() {
                  _future = _load();
                });
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context,
      List<Song> songs,
      ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final player = context.read<PlayerProvider>();

    final top = songs.take(_topCount).toList();

    final rest = songs.length > _topCount
        ? songs.sublist(_topCount)
        : <Song>[];

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildHeader(
            context,
            songs,
            cs,
            theme,
            player,
          ),

          if (songs.isEmpty)
            _buildEmpty(cs),

          if (top.isNotEmpty)
            _sectionTitle(
              rest.isEmpty ? 'Semua Lagu' : 'Lagu Teratas',
              cs,
              theme,
            ),

          if (top.isNotEmpty)
            ...List.generate(
              top.length,
                  (index) => _buildTopSong(
                songs,
                top[index],
                index,
                player,
                cs,
              ),
            ),

          if (rest.isNotEmpty)
            _sectionTitle(
              'Lagu Lainnya',
              cs,
              theme,
            ),

          ...List.generate(
            rest.length,
                (index) => SongTile(
              song: rest[index],
              onTap: () => player.playQueue(
                songs,
                _topCount + index,
              ),
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context,
      List<Song> songs,
      ColorScheme cs,
      ThemeData theme,
      PlayerProvider player,
      ) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        topPadding + kToolbarHeight + 12,
        20,
        28,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            cs.primary.withValues(alpha: 0.30),
            cs.primaryContainer.withValues(alpha: 0.30),
            cs.surface,
          ],
        ),
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.25),
                  blurRadius: 30,
                  spreadRadius: 2,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: CoverImage(
              url: _coverOf(songs),
              size: 174,
              radius: 100,
            ),
          ),

          const SizedBox(height: 22),

          Text(
            'PROFIL ARTIS',
            style: theme.textTheme.labelMedium?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            widget.artist,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.7,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            songs.isEmpty
                ? 'Artis di PinkBeat'
                : '${songs.length} lagu tersedia',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 22),

          if (songs.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      player.playQueue(songs, 0);
                    },
                    icon: const Icon(
                      Icons.play_arrow_rounded,
                      size: 23,
                    ),
                    label: const Text('Putar Semua'),
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
                    onPressed: () {
                      final shuffled = [...songs]..shuffle();
                      player.playQueue(shuffled, 0);
                    },
                    icon: const Icon(
                      Icons.shuffle_rounded,
                      size: 20,
                    ),
                    label: const Text('Acak'),
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

            const SizedBox(height: 22),

            Container(
              padding: const EdgeInsets.symmetric(
                vertical: 15,
                horizontal: 12,
              ),
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _ArtistStat(
                      icon: Icons.music_note_rounded,
                      value: '${songs.length}',
                      label: 'Total Lagu',
                      color: cs.primary,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 38,
                    color: cs.outlineVariant,
                  ),
                  Expanded(
                    child: _ArtistStat(
                      icon: Icons.star_rounded,
                      value: '${topCount(songs.length)}',
                      label: 'Lagu Teratas',
                      color: cs.secondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  int topCount(int total) {
    return total < _topCount ? total : _topCount;
  }

  Widget _sectionTitle(
      String title,
      ColorScheme cs,
      ThemeData theme,
      ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 23,
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSong(
      List<Song> songs,
      Song song,
      int index,
      PlayerProvider player,
      ColorScheme cs,
      ) {
    return Row(
      children: [
        SizedBox(
          width: 38,
          child: Center(
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: index == 0
                    ? cs.primary
                    : cs.onSurfaceVariant,
                fontWeight: FontWeight.w900,
                fontSize: index == 0 ? 17 : 14,
              ),
            ),
          ),
        ),
        Expanded(
          child: SongTile(
            song: song,
            onTap: () => player.playQueue(songs, index),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 55, 30, 55),
      child: Column(
        children: [
          Icon(
            Icons.library_music_rounded,
            size: 65,
            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Belum Ada Lagu',
            style: TextStyle(
              color: cs.onSurface,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Belum ada lagu dari "${widget.artist}" di PinkBeat.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtistStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _ArtistStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: 22,
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
