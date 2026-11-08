import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../../providers/likes_provider.dart';
import '../../providers/player_provider.dart';
import '../../widgets/cover_image.dart';
import '../artist/artist_screen.dart';
import '../../widgets/queue_sheet.dart';
import '../../widgets/sleep_timer_sheet.dart';
import '../../widgets/song_menu.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  double? _drag;

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlayerProvider>();
    final likes = context.watch<LikesProvider>();
    final song = p.current;
    final cs = Theme.of(context).colorScheme;
    final width = MediaQuery.of(context).size.width;

    if (song == null) {
      return const Scaffold(body: Center(child: Text('Belum ada lagu')));
    }

    final liked = likes.isLiked(song.id);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              cs.primaryContainer,
              Theme.of(context).scaffoldBackgroundColor
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          size: 34),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text('Sedang diputar',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: cs.onSurfaceVariant)),
                    IconButton(
                      icon: const Icon(Icons.more_horiz_rounded),
                      onPressed: () => showSongMenu(context, song),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                          color: cs.primary.withValues(alpha: 0.3),
                          blurRadius: 40,
                          offset: const Offset(0, 16)),
                    ],
                  ),
                  child: CoverImage(
                      url: song.coverUrl, size: width - 56, radius: 28),
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: hasArtistPage(song.artist)
                                ? () => openArtist(context, song.artist)
                                : null,
                            child: Text(song.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 16, color: cs.onSurfaceVariant)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        liked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: cs.primary,
                        size: 28,
                      ),
                      onPressed: () => likes.toggle(song),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                StreamBuilder<Duration>(
                  stream: p.player.positionStream,
                  builder: (_, snap) {
                    final pos = snap.data ?? Duration.zero;
                    final dur = p.player.duration ?? Duration.zero;
                    final max = dur.inMilliseconds.toDouble();
                    final value = _drag ??
                        pos.inMilliseconds
                            .toDouble()
                            .clamp(0, max == 0 ? 1 : max);
                    return Column(
                      children: [
                        Slider(
                          value: value.toDouble(),
                          max: max == 0 ? 1 : max,
                          onChanged: (v) => setState(() => _drag = v),
                          onChangeEnd: (v) {
                            p.seek(Duration(milliseconds: v.toInt()));
                            setState(() => _drag = null);
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_fmt(pos),
                                  style:
                                  TextStyle(color: cs.onSurfaceVariant)),
                              Text(_fmt(dur),
                                  style:
                                  TextStyle(color: cs.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.shuffle_rounded,
                          color: p.shuffle ? cs.primary : cs.onSurfaceVariant),
                      onPressed: p.toggleShuffle,
                    ),
                    IconButton(
                      iconSize: 40,
                      icon: const Icon(Icons.skip_previous_rounded),
                      onPressed: p.previous,
                    ),
                    Container(
                      decoration: BoxDecoration(
                          color: cs.primary, shape: BoxShape.circle),
                      child: IconButton(
                        iconSize: 44,
                        padding: const EdgeInsets.all(14),
                        color: cs.onPrimary,
                        icon: Icon(p.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded),
                        onPressed: p.togglePlay,
                      ),
                    ),
                    IconButton(
                      iconSize: 40,
                      icon: const Icon(Icons.skip_next_rounded),
                      onPressed: p.next,
                    ),
                    IconButton(
                      icon: Icon(
                        p.loop == LoopMode.one
                            ? Icons.repeat_one_rounded
                            : Icons.repeat_rounded,
                        color: p.loop == LoopMode.off
                            ? cs.onSurfaceVariant
                            : cs.primary,
                      ),
                      onPressed: p.cycleLoop,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SleepTimerButton(),
                    IconButton(
                      tooltip: 'Antrean',
                      icon: Icon(Icons.queue_music_rounded,
                          color: cs.onSurfaceVariant),
                      onPressed: () => showQueueSheet(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}