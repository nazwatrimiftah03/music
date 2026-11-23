
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
import '../library/song_list_screen.dart';
import '../search/search.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SongService _svc = SongService();
  final RecommendationService _recSvc = RecommendationService();

  static const _genres = [
    ('Pop', 'pop', Icons.music_note_rounded),
    ('Rock', 'rock', Icons.album_rounded),
    ('Elektronik', 'electronic', Icons.graphic_eq_rounded),
    ('Hip Hop', 'hiphop', Icons.mic_rounded),
    ('Jazz', 'jazz', Icons.piano_rounded),
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
    final hour = DateTime.now().hour;

    if (hour < 11) return 'Selamat pagi';
    if (hour < 15) return 'Selamat siang';
    if (hour < 19) return 'Selamat sore';

    return 'Selamat malam';
  }

  void _load() {
    _forYou = null;
    _forYouUsesHistory = false;

    _trending = _svc.getAll();
    _indonesia = _svc.indonesiaHits();

    _genreFutures = [
      for (final genre in _genres)
        _svc.byGenre(genre.$2),
    ];
  }

  Future<void> _reload() async {
    setState(_load);

    await Future.wait([
      _trending,
      _indonesia,
      ..._genreFutures,
    ].map((future) => future.catchError((_) => <Song>[])));
  }

  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SearchScreen(),
      ),
    );
  }

  void _openGenre(int index) {
    final genre = _genres[index];

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SongListScreen(
          title: genre.$1,
          icon: genre.$3,
          allowSaveAsPlaylist: true,
          loader: () => _svc.byGenre(genre.$2),
          emptyText: 'Belum ada lagu untuk kategori ini.',
        ),
      ),
    );
  }

  void _openDailyMix() {
    final recent = context.read<HistoryProvider>().songs;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SongListScreen(
          title: 'Mix harian',
          icon: Icons.auto_awesome_rounded,
          allowSaveAsPlaylist: true,
          loader: () => _recSvc.dailyMix(history: recent),
          emptyText: 'Belum ada lagu untuk mix hari ini.\n'
              'Sukai beberapa lagu dulu ya 💗',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final user = AuthService().user;
    final name = user?.userMetadata?['username'] ??
        user?.email?.split('@').first ??
        'Musik Lover';

    final history = context.watch<HistoryProvider>().songs;

    if (_forYou == null ||
        (!_forYouUsesHistory && history.isNotEmpty)) {
      _forYou = _recSvc.forYou(history: history);
      _forYouUsesHistory = history.isNotEmpty;
    }

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _greeting(),
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        name.toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Muat ulang',
                  onPressed: _reload,
                  icon: Icon(
                    Icons.refresh_rounded,
                    color: cs.primary,
                    size: 25,
                  ),
                ),
              ],
            ),
          ),

          // KONTEN BERANDA
          Expanded(
            child: RefreshIndicator(
              color: cs.primary,
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  // SEARCH BAR
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                    ),
                    child: Material(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _openSearch,
                        child: Container(
                          height: 52,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: cs.outline),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.search_rounded,
                                color: cs.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Cari lagu, artis, atau album...',
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // MIX HARIAN
                  _DailyMixCard(onTap: _openDailyMix),

                  // KATEGORI
                  const _RowTitle('Jelajahi musik'),

                  SizedBox(
                    height: 48,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                      ),
                      scrollDirection: Axis.horizontal,
                      itemCount: _genres.length,
                      separatorBuilder: (_, _) =>
                      const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final genre = _genres[index];

                        return Material(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(30),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(30),
                            onTap: () => _openGenre(index),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: cs.outline),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    genre.$3,
                                    size: 17,
                                    color: cs.primary,
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    genre.$1,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // RIWAYAT
                  if (history.isNotEmpty) ...[
                    const _RowTitle('Terakhir diputar'),
                    SizedBox(
                      height: _SongCards.height,
                      child: _SongCards(songs: history),
                    ),
                  ],

                  // REKOMENDASI
                  _SongRow(
                    title: 'Rekomendasi untuk kamu',
                    subtitle: 'Pilihan lagu berdasarkan seleramu',
                    future: _forYou!,
                  ),

                  // HITS INDONESIA
                  _SongRow(
                    title: 'Hits Indonesia',
                    subtitle: 'Musik pilihan dari Indonesia',
                    future: _indonesia,
                  ),

                  // POPULER
                  _SongRow(
                    title: 'Populer minggu ini',
                    subtitle: 'Temukan lagu yang sedang populer',
                    future: _trending,
                  ),

                  // GENRE LAINNYA
                  for (var i = 0; i < _genres.length; i++)
                    _SongRow(
                      title: 'Musik ${_genres[i].$1}',
                      future: _genreFutures[i],
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

// JUDUL BAGIAN
class _RowTitle extends StatelessWidget {
  final String text;
  final String? subtitle;

  const _RowTitle(
      this.text, {
        this.subtitle,
      });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// BARIS LAGU DARI API
class _SongRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Future<List<Song>> future;

  const _SongRow({
    required this.title,
    required this.future,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RowTitle(title, subtitle: subtitle),
        SizedBox(
          height: _SongCards.height,
          child: FutureBuilder<List<Song>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: cs.primary,
                    ),
                  ),
                );
              }

              final songs = snapshot.data ?? [];

              if (snapshot.hasError || songs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                  ),
                  child: Text(
                    snapshot.hasError
                        ? 'Gagal memuat. Tarik ke bawah untuk mencoba lagi.'
                        : 'Belum ada lagu.',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                    ),
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

// KARTU-KARTU LAGU
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
      separatorBuilder: (_, _) => const SizedBox(width: 14),
      itemBuilder: (context, index) {
        final song = songs[index];

        return GestureDetector(
          onTap: () {
            context.read<PlayerProvider>().playQueue(
              songs,
              index,
            );
          },
          onLongPress: () => showSongMenu(context, song),
          child: SizedBox(
            width: cardWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CoverImage(
                  url: song.coverUrl,
                  size: cardWidth,
                  radius: 17,
                ),
                const SizedBox(height: 9),
                Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  song.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// BANNER MIX HARIAN
class _DailyMixCard extends StatelessWidget {
  final VoidCallback onTap;

  const _DailyMixCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.all(19),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
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
                  color: cs.primary.withValues(alpha: 0.23),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 15),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mix harian',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Temukan musik yang cocok dengan harimu.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
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
