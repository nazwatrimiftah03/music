import 'package:flutter/material.dart';
import '../models/song.dart';
import '../screens/artist/artist_screen.dart';

/// Ringkasan kebiasaan mendengarkan, dihitung dari riwayat putar:
/// 3 artis teratas dan genre yang paling sering muncul.
class ListeningStats extends StatelessWidget {
  final List<Song> songs;
  const ListeningStats({super.key, required this.songs});

  static const _genreNames = {
    'pop': 'Pop',
    'rock': 'Rock',
    'electronic': 'Elektronik',
    'hiphop': 'Hip Hop',
    'jazz': 'Jazz',
    'classical': 'Klasik',
    'indie': 'Indie',
    'ambient': 'Ambient',
    'folk': 'Folk',
    'reggae': 'Reggae',
  };

  static String _genreLabel(String g) =>
      _genreNames[g] ?? '${g[0].toUpperCase()}${g.substring(1)}';

  /// Hitung kemunculan, urutkan dari terbanyak. Kalau sama banyak,
  /// yang lebih dulu muncul di riwayat (lebih baru diputar) di atas.
  static List<MapEntry<String, int>> _top(Iterable<String> items, int n) {
    final counts = <String, int>{};
    final order = <String, int>{};
    for (final item in items) {
      counts[item] = (counts[item] ?? 0) + 1;
      order.putIfAbsent(item, () => order.length);
    }
    final entries = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0
            ? byCount
            : order[a.key]!.compareTo(order[b.key]!);
      });
    return entries.take(n).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final artists = _top(
      songs.map((s) => s.artist.trim()).where(hasArtistPage),
      3,
    );
    final genres = _top(
      songs.map((s) => (s.genre ?? '').trim().toLowerCase()).where(
            (g) => g.isNotEmpty,
      ),
      4,
    );

    final notEnough = songs.length < 3 || artists.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sering kamu dengar',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Dari ${songs.length} lagu terakhir yang kamu putar',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        if (notEnough)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Putar beberapa lagu dulu, nanti artis dan genre '
                    'favoritmu muncul di sini.',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
          )
        else ...[
          Card(
            child: Column(
              children: [
                for (var i = 0; i < artists.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: cs.outline),
                  ListTile(
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: cs.primaryContainer,
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: cs.primary,
                        ),
                      ),
                    ),
                    title: Text(
                      artists[i].key,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('${artists[i].value} lagu'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => openArtist(context, artists[i].key),
                  ),
                ],
              ],
            ),
          ),
          if (genres.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final g in genres)
                  Chip(
                    label: Text('${_genreLabel(g.key)} • ${g.value}'),
                    backgroundColor: cs.primaryContainer,
                    side: BorderSide.none,
                    labelStyle: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}