import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';

/// Tombol kecil di layar "Sedang diputar".
/// Kalau timer aktif, tombolnya menampilkan hitung mundur.
class SleepTimerButton extends StatelessWidget {
  const SleepTimerButton({super.key});

  String _fmt(Duration d) {
    final m = d.inMinutes.toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = context.watch<PlayerProvider>();
    final active = p.sleepActive;
    final color = active ? cs.primary : cs.onSurfaceVariant;

    return TextButton.icon(
      style: TextButton.styleFrom(foregroundColor: color),
      onPressed: () => showSleepTimerSheet(context),
      icon: const Icon(Icons.bedtime_rounded, size: 20),
      label: active
          ? StreamBuilder<int>(
        // Diperbarui tiap detik supaya hitung mundurnya bergerak.
        stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
        builder: (_, _) {
          final left = p.sleepRemaining;
          return Text(left == null ? 'Timer tidur' : _fmt(left));
        },
      )
          : const Text('Timer tidur'),
    );
  }
}

/// Pilihan durasi timer tidur.
void showSleepTimerSheet(BuildContext context) {
  final player = context.read<PlayerProvider>();
  final messenger = ScaffoldMessenger.of(context);
  const minutes = [5, 10, 15, 30, 45, 60];

  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints:
        BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text('Timer tidur',
                    style:
                    TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Suara mengecil perlahan, lalu musik dijeda otomatis',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              for (final m in minutes)
                ListTile(
                  leading: const Icon(Icons.schedule_rounded),
                  title: Text('$m menit'),
                  onTap: () {
                    player.startSleepTimer(Duration(minutes: m));
                    Navigator.pop(ctx);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Musik berhenti dalam $m menit'),
                      ),
                    );
                  },
                ),
              if (player.sleepActive)
                ListTile(
                  leading: Icon(Icons.timer_off_rounded,
                      color: Theme.of(ctx).colorScheme.error),
                  title: Text(
                    'Matikan timer',
                    style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                  ),
                  onTap: () {
                    player.cancelSleepTimer();
                    Navigator.pop(ctx);
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Timer tidur dimatikan')),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    ),
  );
}