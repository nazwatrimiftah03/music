import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/song.dart';
import '../../providers/history_provider.dart';
import '../../providers/player_provider.dart';
import '../../services/auth_service.dart';
import '../../services/recommendation_service.dart';
import '../../services/song_service.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/song_menu.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SongService _svc = SongService();
  final RecommendationService _recSvc = RecommendationService();

  // (label tampilan, tag di Jamendo)
  static const _genres = [
    ('Pop', 'pop'),
    ('Rock', 'rock'),
    ('Elektronik', 'electronic'),
    ('Hip Hop', 'hiphop'),
    ('Jazz', 'jazz'),
  ];

  late Future<List<Song>> _trending;
  late Future<List<Song>> _indonesia;
  Future<List<Song>>? _forYou;
  bool _forYouUsesHistory = false;
  late List<Future<List<Song>>> _genreFutures;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 11) return 'Selamat pagi';
    if (h < 15) return 'Selamat siang';
    if (h < 19) return 'Selamat sore';
    return 'Selamat malam';
  }

  void _load() {
    _forYou = null;
    _forYouUsesHistory = false;
    _trending = _svc.getAll();
    _indonesia = _svc.indonesiaHits();
    _genreFutures = [for (final g in _genres) _svc.byGenre(g.$2)];
  }

  Future<void> _reload() async {
    setState(_load);
    // tunggu semua selesai (error diabaikan, ditangani tiap baris)
    await Future.wait(
      [_trending, _indonesia, ..._genreFutures].map((f) => f.catchError((_) => <Song>[])),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = AuthService().user;
    final name = user?.userMetadata?['username'] ?? user?.email ?? '';
    final history = context.watch<HistoryProvider>().songs;

    // Rekomendasi diambil sekali, lalu diperbarui sekali lagi saat
    // riwayat pertama kali terisi (supaya tidak refetch tiap lagu ganti).
    if (_forYou == null || (!_forYouUsesHistory && history.isNotEmpty)) {
      _forYou = _recSvc.forYou(history: history);
      _forYouUsesHistory = history.isNotEmpty;
    }

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_greeting()}, $name',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.refresh_rounded, color: cs.primary),
                  onPressed: _reload,
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: cs.primary,
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  if (history.isNotEmpty) ...[
                    const _RowTitle('Terakhir diputar'),
                    SizedBox(
                      height: _SongCards.height,
                      child: _SongCards(songs: history),
                    ),
                  ],
                  _SongRow(title: 'Rekomendasi untuk kamu', future: _forYou!),
                  _SongRow(title: 'Hits Indonesia', future: _indonesia),
                  _SongRow(title: 'Populer minggu ini', future: _trending),
                  for (var i = 0; i < _genres.length; i++)
                    _SongRow(title: _genres[i].$1, future: _genreFutures[i]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RowTitle extends StatelessWidget {
  final String text;
  const _RowTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleLarge
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// Satu baris horizontal yang datanya dimuat dari API.
class _SongRow extends StatelessWidget {
  final String title;
  final Future<List<Song>> future;

  const _SongRow({required this.title, required this.future});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RowTitle(title),
        SizedBox(
          height: _SongCards.height,
          child: FutureBuilder<List<Song>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: cs.primary),
                  ),
                );
              }

              final songs = snapshot.data ?? [];
              if (snapshot.hasError || songs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    snapshot.hasError
                        ? 'Gagal memuat. Tarik ke bawah untuk coba lagi.'
                        : 'Belum ada lagu.',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                );
              }

              return _SongCards(songs: songs);
            },
          ),
        ),
      ],
    );
  }
}

/// Daftar kartu lagu yang bisa digeser ke samping.
class _SongCards extends StatelessWidget {
  final List<Song> songs;

  const _SongCards({required this.songs});

  static const double cardWidth = 140;
  static const double height = 205;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: songs.length,
      separatorBuilder: (_, __) => const SizedBox(width: 14),
      itemBuilder: (context, i) {
        final song = songs[i];
        return GestureDetector(
          onTap: () => context.read<PlayerProvider>().playQueue(songs, i),
          onLongPress: () => showSongMenu(context, song),
          child: SizedBox(
            width: cardWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CoverImage(url: song.coverUrl, size: cardWidth, radius: 16),
                const SizedBox(height: 8),
                Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  song.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}