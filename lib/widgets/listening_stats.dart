import 'package:flutter/material.dart';

import '../models/song.dart';
import '../screens/artist/artist_screen.dart';

/// Ringkasan kebiasaan mendengarkan musik.
class ListeningStats extends StatelessWidget {
  final List<Song> songs;

  const ListeningStats({
    super.key,
    required this.songs,
  });

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

  static String _genreLabel(String genre) {
    if (genre.isEmpty) return 'Lainnya';

    return _genreNames[genre] ??
        '${genre[0].toUpperCase()}${genre.substring(1)}';
  }

  static List<MapEntry<String, int>> _top(
    Iterable<String> items,
    int limit,
  ) {
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

    return entries.take(limit).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final artists = _top(
      songs
          .map((song) => song.artist.trim())
          .where((artist) =>
              artist.isNotEmpty && hasArtistPage(artist)),
      3,
    );

    final genres = _top(
      songs
          .map((song) => (song.genre ?? '').trim().toLowerCase())
          .where((genre) => genre.isNotEmpty),
      4,
    );

    final notEnough = songs.length < 3 || artists.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.equalizer_rounded,
              color: cs.primary,
              size: 22,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Sering kamu dengar',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 5),

        Text(
          'Berdasarkan ${songs.length} lagu terakhir yang kamu putar',
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurfaceVariant,
          ),
        ),

        const SizedBox(height: 14),

        if (notEnough)
          _EmptyStats(
            color: cs.primary,
            background: cs.primaryContainer,
            textColor: cs.onPrimaryContainer,
          )
        else ...[
          Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: cs.outline.withValues(alpha: 0.25),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < artists.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        indent: 65,
                        endIndent: 14,
                        color: cs.outline.withValues(alpha: 0.3),
                      ),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 3,
                      ),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            color: cs.primary,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      title: Text(
                        artists[i].key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        '${artists[i].value} kali diputar',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: cs.onSurfaceVariant,
                      ),
                      onTap: () {
                        openArtist(context, artists[i].key);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),

          if (genres.isNotEmpty) ...[
            const SizedBox(height: 16),

            Text(
              'Genre favoritmu',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),

            const SizedBox(height: 10),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final genre in genres)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.music_note_rounded,
                          size: 15,
                          color: cs.primary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _genreLabel(genre.key),
                          style: TextStyle(
                            color: cs.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Â· ${genre.value}',
                          style: TextStyle(
                            color: cs.onPrimaryContainer,
                            fontSize: 11,
                          ),
                        ),
                      ],
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

class _EmptyStats extends StatelessWidget {
  final Color color;
  final Color background;
  final Color textColor;

  const _EmptyStats({
    required this.color,
    required this.background,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: background.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(
            Icons.headphones_rounded,
            size: 38,
            color: color,
          ),
          const SizedBox(height: 10),
          Text(
            'Mulai jelajahi musik!',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Putar beberapa lagu dulu. Nanti artis dan genre '
            'favoritmu akan muncul di sini.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
