
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/song.dart';
import '../../providers/player_provider.dart';
import '../../services/song_service.dart';
import '../../widgets/song_tile.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final SongService _svc = SongService();
  final TextEditingController _ctrl = TextEditingController();

  Timer? _debounce;

  List<Song> _results = [];

  bool _loading = false;
  bool _error = false;

  String? _genreLabel;
  int _requestId = 0;

  static const List<(String, String)> _genres = [
    ('Indonesia', 'indonesia'),
    ('Pop', 'pop'),
    ('Rock', 'rock'),
    ('Elektronik', 'electronic'),
    ('Hip Hop', 'hiphop'),
    ('Jazz', 'jazz'),
    ('Klasik', 'classical'),
    ('Indie', 'indie'),
    ('Ambient', 'ambient'),
    ('Folk', 'folk'),
    ('Reggae', 'reggae'),
  ];

  static const List<Color> _genreColors = [
    Color(0xFFE8115B),
    Color(0xFF8D67AB),
    Color(0xFF1E3264),
    Color(0xFFE13300),
    Color(0xFF148A08),
    Color(0xFFBA5D07),
    Color(0xFF477D95),
    Color(0xFF7358FF),
  ];

  static const List<IconData> _genreIcons = [
    Icons.flag_rounded,
    Icons.music_note_rounded,
    Icons.album_rounded,
    Icons.graphic_eq_rounded,
    Icons.mic_rounded,
    Icons.piano_rounded,
    Icons.library_music_rounded,
    Icons.headphones_rounded,
    Icons.spa_rounded,
    Icons.queue_music_rounded,
    Icons.waves_rounded,
  ];

  bool get _showingResults =>
      _genreLabel != null || _ctrl.text.trim().isNotEmpty;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();

    final query = value.trim();
    final request = ++_requestId;

    setState(() {
      _genreLabel = null;
      _error = false;
    });

    if (query.isEmpty) {
      setState(() {
        _results = [];
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _results = [];
    });

    _debounce = Timer(
      const Duration(milliseconds: 450),
          () => _search(query, request),
    );
  }

  Future<void> _search(String query, int request) async {
    try {
      final songs = await _svc.search(query);

      if (!mounted || request != _requestId) return;

      setState(() {
        _results = songs;
        _loading = false;
        _error = false;
      });
    } catch (_) {
      if (!mounted || request != _requestId) return;

      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  Future<void> _pickGenre(String label, String tag) async {
    _debounce?.cancel();

    final request = ++_requestId;

    _ctrl.clear();

    setState(() {
      _genreLabel = label;
      _loading = true;
      _error = false;
      _results = [];
    });

    try {
      final songs = await _svc.byGenre(tag);

      if (!mounted || request != _requestId) return;

      setState(() {
        _results = songs;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || request != _requestId) return;

      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  void _clear() {
    _debounce?.cancel();
    _requestId++;

    _ctrl.clear();

    setState(() {
      _genreLabel = null;
      _results = [];
      _loading = false;
      _error = false;
    });
  }

  Future<void> _retry() async {
    if (_genreLabel != null) {
      final genre = _genres.firstWhere(
            (item) => item.$1 == _genreLabel,
        orElse: () => _genres[0],
      );

      await _pickGenre(genre.$1, genre.$2);
    } else {
      final query = _ctrl.text.trim();

      if (query.isNotEmpty) {
        final request = ++_requestId;

        setState(() {
          _loading = true;
          _error = false;
        });

        await _search(query, request);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final player = context.read<PlayerProvider>();

    return Material(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Temukan Musik',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.8,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.headphones_rounded,
                          color: cs.primary,
                          size: 23,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Cari lagu favorit dan temukan musik baru.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Search bar
                  Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    child: TextField(
                      controller: _ctrl,
                      onChanged: _onChanged,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Cari lagu atau nama artis...',
                        hintStyle: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: cs.primary,
                        ),
                        suffixIcon: _showingResults
                            ? IconButton(
                          onPressed: _clear,
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Hapus pencarian',
                        )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 17,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_genreLabel != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.filter_list_rounded,
                      color: cs.primary,
                      size: 19,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Genre:',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Chip(
                      label: Text(_genreLabel!),
                      backgroundColor: cs.primaryContainer,
                      labelStyle: TextStyle(
                        color: cs.primary,
                        fontWeight: FontWeight.w700,
                      ),
                      side: BorderSide.none,
                      deleteIcon: Icon(
                        Icons.close_rounded,
                        size: 17,
                        color: cs.primary,
                      ),
                      onDeleted: _clear,
                    ),
                  ],
                ),
              ),

            Expanded(
              child: !_showingResults
                  ? _buildGenres()
                  : _loading
                  ? _buildLoading()
                  : _error
                  ? _buildError()
                  : _results.isEmpty
                  ? _buildEmpty()
                  : _buildResults(player, cs),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenres() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        Row(
          children: [
            Text(
              'Jelajahi Genre',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            Text(
              '${_genres.length} genre',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Pilih genre sesuai suasana hatimu.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 18),

        GridView.builder(
          itemCount: _genres.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.75,
          ),
          itemBuilder: (context, index) {
            final genre = _genres[index];

            return _GenreCard(
              label: genre.$1,
              icon: _genreIcons[index],
              color: _genreColors[index % _genreColors.length],
              onTap: () => _pickGenre(genre.$1, genre.$2),
            );
          },
        ),

        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cs.primaryContainer.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(
                Icons.favorite_rounded,
                color: cs.primary,
                size: 30,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Musik untuk setiap suasana',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Temukan lagu yang cocok untuk menemani harimu.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResults(PlayerProvider player, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _genreLabel != null
                      ? 'Lagu $_genreLabel'
                      : 'Hasil Pencarian',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${_results.length} lagu',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: _results.length,
            itemBuilder: (context, index) {
              return SongTile(
                song: _results[index],
                onTap: () => player.playQueue(_results, index),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: cs.primary),
          const SizedBox(height: 16),
          Text(
            'Sedang mencari musik...',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.music_off_rounded,
              size: 65,
              color: cs.onSurfaceVariant.withValues(alpha: 0.55),
            ),
            const SizedBox(height: 16),
            Text(
              'Lagu tidak ditemukan',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Coba kata kunci atau genre yang berbeda.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _clear,
              icon: const Icon(Icons.search_rounded),
              label: const Text('Cari lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 60,
              color: cs.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Gagal memuat musik',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Periksa koneksi internet, lalu coba lagi.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenreCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _GenreCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Positioned(
              right: -13,
              top: -17,
              child: Icon(
                icon,
                size: 90,
                color: Colors.white.withValues(alpha: 0.13),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(
                    icon,
                    size: 25,
                    color: Colors.white,
                  ),
                  const Spacer(),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: Icon(
                Icons.arrow_forward_rounded,
                size: 17,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
