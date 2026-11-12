import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/song.dart';
import '../../providers/player_provider.dart';
import '../../services/song_service.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/mini_player.dart';
import '../../widgets/song_tile.dart';

/// Buka halaman profil satu artis (header, lagu teratas, semua lagu).
void openArtist(BuildContext context, String artist) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => ArtistScreen(artist: artist)),
  );
}

/// Nama artis yang bisa dipakai untuk membuka halaman artis.
/// False untuk nama kosong atau placeholder "Unknown Artist".
bool hasArtistPage(String artist) {
  final a = artist.trim().toLowerCase();
  return a.isNotEmpty && a != 'unknown artist';
}

class ArtistScreen extends StatefulWidget {
  final String artist;
  const ArtistScreen({super.key, required this.artist});

  @override
  State<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends State<ArtistScreen> {
  /// Jumlah lagu yang ditampilkan di bagian "Lagu teratas".
  static const int _topCount = 5;

  late Future<List<Song>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  /// Semua lagu artis, dengan yang paling banyak didengar di PinkBeat
  /// ditaruh paling atas. Sisanya tetap berurutan seperti hasil pencarian.
  Future<List<Song>> _load() async {
    final svc = SongService();
    final all = await svc.byArtist(widget.artist);
    final popular = await svc.popular(artist: widget.artist, limit: 20);
    if (popular.isEmpty) return all;

    final rank = <String, int>{
      for (var i = 0; i < popular.length; i++) popular[i].id: i,
    };
    final ranked = all.where((s) => rank.containsKey(s.id)).toList()
      ..sort((a, b) => rank[a.id]!.compareTo(rank[b.id]!));
    final others = all.where((s) => !rank.containsKey(s.id));
    return [...ranked, ...others];
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  /// Cover artis diambil dari lagu pertama yang punya gambar.
  String? _coverOf(List<Song> songs) {
    for (final s in songs) {
      if (s.coverUrl.isNotEmpty) return s.coverUrl;
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
      bottomNavigationBar: const SafeArea(child: MiniPlayer()),
      body: FutureBuilder<List<Song>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Center(child: CircularProgressIndicator(color: cs.primary));
          }
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Gagal memuat halaman artis',
                      style: TextStyle(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Coba lagi'),
                  ),
                ],
              ),
            );
          }
          return _buildContent(context, snap.data ?? const <Song>[]);
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<Song> songs) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final player = context.read<PlayerProvider>();

    final top = songs.take(_topCount).toList();
    final rest = songs.length > _topCount ? songs.sublist(_topCount) : <Song>[];

    Widget sectionTitle(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Text(text,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800)),
    );

    return RefreshIndicator(
      onRefresh: () async {
        _reload();
        await _future;
      },
      child: ListView(
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // ===== Header =====
          Container(
            padding: EdgeInsets.fromLTRB(
                20, MediaQuery.of(context).padding.top + kToolbarHeight, 20, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  cs.primary.withValues(alpha: 0.45),
                  cs.surface.withValues(alpha: 0),
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
                        color: cs.primary.withValues(alpha: 0.35),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: CoverImage(
                    url: _coverOf(songs),
                    size: 160,
                    radius: 80,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.artist,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  songs.isEmpty ? 'Artis' : 'Artis • ${songs.length} lagu',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                if (songs.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
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
                ],
              ],
            ),
          ),

          // ===== Kosong =====
          if (songs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Text(
                  'Belum ada lagu dari "${widget.artist}" di aplikasi ini.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            ),

          // ===== Lagu teratas =====
          if (top.isNotEmpty) sectionTitle(rest.isEmpty ? 'Lagu' : 'Lagu teratas'),
          for (var i = 0; i < top.length; i++)
            Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text('${i + 1}',
                        style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
                Expanded(
                  child: SongTile(
                    song: top[i],
                    onTap: () => player.playQueue(songs, i),
                  ),
                ),
              ],
            ),

          // ===== Lagu lainnya =====
          if (rest.isNotEmpty) sectionTitle('Lagu lainnya'),
          for (var i = 0; i < rest.length; i++)
            SongTile(
              song: rest[i],
              onTap: () => player.playQueue(songs, _topCount + i),
            ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}