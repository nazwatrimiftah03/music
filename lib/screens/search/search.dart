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
  final _svc = SongService();
  final _ctrl = TextEditingController();
  Timer? _debounce;

  List<Song> _results = [];
  bool _loading = false;
  bool _error = false;
  String? _genreLabel;

  // (label tampilan, tag di Jamendo)
  static const _genres = [
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

  static const _genreColors = [
    Color(0xFFE8115B),
    Color(0xFF8D67AB),
    Color(0xFF1E3264),
    Color(0xFFE13300),
    Color(0xFF148A08),
    Color(0xFFBA5D07),
    Color(0xFF477D95),
    Color(0xFF7358FF),
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  bool get _showingResults =>
      _genreLabel != null || _ctrl.text.trim().isNotEmpty;

  void _onChanged(String q) {
    _debounce?.cancel();
    final query = q.trim();
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

    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final r = await _svc.search(query);
        if (mounted && _ctrl.text.trim() == query) {
          setState(() {
            _results = r;
            _loading = false;
          });
        }
      } catch (_) {
        if (mounted && _ctrl.text.trim() == query) {
          setState(() {
            _error = true;
            _loading = false;
          });
        }
      }
    });
  }

  Future<void> _pickGenre(String label, String tag) async {
    _debounce?.cancel();
    _ctrl.clear();
    setState(() {
      _genreLabel = label;
      _loading = true;
      _error = false;
      _results = [];
    });
    try {
      final r = await _svc.byGenre(tag);
      if (mounted && _genreLabel == label) {
        setState(() {
          _results = r;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted && _genreLabel == label) {
        setState(() {
          _error = true;
          _loading = false;
        });
      }
    }
  }

  void _clear() {
    _debounce?.cancel();
    _ctrl.clear();
    setState(() {
      _genreLabel = null;
      _results = [];
      _loading = false;
      _error = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final player = context.read<PlayerProvider>();

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text('Cari',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _ctrl,
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: 'Lagu atau artis',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _showingResults
                    ? IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: _clear,
                )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_genreLabel != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: Chip(
                label: Text('Genre: $_genreLabel'),
                backgroundColor: cs.primaryContainer,
                side: BorderSide.none,
              ),
            ),
          Expanded(
            child: !_showingResults
                ? _buildGenres()
                : _loading
                ? Center(
                child: CircularProgressIndicator(color: cs.primary))
                : _error
                ? Center(
                child: Text('Gagal memuat. Cek koneksi kamu 🥲',
                    style: TextStyle(color: cs.onSurfaceVariant)))
                : _results.isEmpty
                ? Center(
                child: Text('Tidak ada hasil 🥲',
                    style:
                    TextStyle(color: cs.onSurfaceVariant)))
                : ListView.builder(
              itemCount: _results.length,
              itemBuilder: (_, i) => SongTile(
                song: _results[i],
                onTap: () => player.playQueue(_results, i),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenres() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Jelajahi genre',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.0,
          children: [
            for (var i = 0; i < _genres.length; i++)
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _pickGenre(_genres[i].$1, _genres[i].$2),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  alignment: Alignment.bottomLeft,
                  decoration: BoxDecoration(
                    color: _genreColors[i % _genreColors.length],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(_genres[i].$1,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16)),
                ),
              ),
          ],
        ),
      ],
    );
  }
}