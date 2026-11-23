
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/player_provider.dart';

String _formatDuration(Duration duration) {
  final remaining = duration.isNegative ? Duration.zero : duration;

  final hours = remaining.inHours;
  final minutes = remaining.inMinutes.remainder(60);
  final seconds = remaining.inSeconds.remainder(60);

  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

class SleepTimerButton extends StatelessWidget {
  const SleepTimerButton({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final player = context.watch<PlayerProvider>();
    final active = player.sleepActive;

    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: active ? cs.primary : cs.onSurfaceVariant,
      ),
      onPressed: () => showSleepTimerSheet(context),
      icon: Icon(
        active ? Icons.timer_rounded : Icons.bedtime_rounded,
        size: 20,
      ),
      label: active
          ? StreamBuilder<int>(
        stream: Stream.periodic(
          const Duration(seconds: 1),
              (index) => index,
        ),
        builder: (context, snapshot) {
          final remaining = player.sleepRemaining;

          return Text(
            remaining == null
                ? 'Timer tidur'
                : _formatDuration(remaining),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
            ),
          );
        },
      )
          : const Text('Timer tidur'),
    );
  }
}

void showSleepTimerSheet(BuildContext context) {
  final player = context.read<PlayerProvider>();
  final messenger = ScaffoldMessenger.of(context);

  const minutes = [5, 10, 15, 30, 45, 60];

  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final cs = theme.colorScheme;

      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ICON
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        cs.primary,
                        cs.secondary,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(21),
                  ),
                  child: const Icon(
                    Icons.bedtime_rounded,
                    color: Colors.white,
                    size: 33,
                  ),
                ),

                const SizedBox(height: 14),

                // JUDUL
                Text(
                  'Sleep Timer',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 7),

                Text(
                  'Atur waktu untuk menghentikan musik secara otomatis.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 24),

                // DURASI
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'PILIH DURASI',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.3,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: minutes.length,
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.35,
                  ),
                  itemBuilder: (context, index) {
                    final minute = minutes[index];

                    return Material(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(17),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(17),
                        onTap: () {
                          player.startSleepTimer(
                            Duration(minutes: minute),
                          );

                          Navigator.pop(ctx);

                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Musik akan berhenti dalam $minute menit',
                              ),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(17),
                            border: Border.all(
                              color: cs.outlineVariant.withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                color: cs.primary,
                                size: 22,
                              ),
                              const SizedBox(height: 7),
                              Text(
                                '$minute menit',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: cs.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // STATUS TIMER AKTIF
                if (player.sleepActive) ...[
                  const SizedBox(height: 22),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(
                        color: cs.primary.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 43,
                          height: 43,
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                            Icons.timer_rounded,
                            color: cs.primary,
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Timer sedang aktif',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 5),
                              StreamBuilder<int>(
                                stream: Stream.periodic(
                                  const Duration(seconds: 1),
                                      (index) => index,
                                ),
                                builder: (context, snapshot) {
                                  final remaining = player.sleepRemaining;

                                  return Text(
                                    remaining == null
                                        ? 'Pilih durasi baru untuk mengganti timer.'
                                        : 'Sisa waktu: ${_formatDuration(remaining)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: cs.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 13),

                  // MATIKAN TIMER
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        player.cancelSleepTimer();
                        Navigator.pop(ctx);

                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Timer tidur dimatikan'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.timer_off_rounded),
                      label: const Text('Matikan Timer'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.error,
                        side: BorderSide(
                          color: cs.error.withValues(alpha: 0.4),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}
