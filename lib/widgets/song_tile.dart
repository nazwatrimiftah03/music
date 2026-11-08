import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../services/itunes_service.dart';
import 'cover_image.dart';
import 'song_menu.dart';

class SongTile extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;
  final String? playlistId;
  final VoidCallback? onChanged;

  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.playlistId,
    this.onChanged,
  });

  /// Lagu dari iTunes hanya berupa cuplikan 30 detik.
  bool get _isPreview => song.id.startsWith(ItunesService.idPrefix);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCurrent =
    context.select<PlayerProvider, bool>((p) => p.current?.id == song.id);
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.only(left: 20, right: 8, top: 2, bottom: 2),
      leading: CoverImage(url: song.coverUrl, size: 52),
      title: Text(song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isCurrent ? cs.primary : cs.onSurface)),
      subtitle: Row(
        children: [
          if (_isPreview) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '30 dtk',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(song.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: cs.onSurfaceVariant)),
          ),
        ],
      ),
      trailing: IconButton(
        icon: Icon(Icons.more_horiz_rounded, color: cs.onSurfaceVariant),
        onPressed: () => showSongMenu(context, song,
            playlistId: playlistId, onChanged: onChanged),
      ),
    );
  }
}