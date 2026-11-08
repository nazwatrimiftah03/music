import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/supabase_config.dart';
import 'providers/history_provider.dart';
import 'providers/likes_provider.dart';
import 'providers/player_provider.dart';
import 'screens/auth/auth_gate.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';

/// Ubah ke false untuk mematikan background audio (mis. saat mencari penyebab
/// layar hitam). Kalau true, MainActivity.kt harus memakai AudioServiceActivity.
const bool kBackgroundAudio = true;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pemutar tetap jalan di latar belakang + kontrol di notifikasi/layar kunci.
  // Dibungkus try/catch supaya kegagalan di sini tidak membuat layar hitam.
  if (kBackgroundAudio) {
    try {
      await JustAudioBackground.init(
        androidNotificationChannelId: 'com.example.music.channel.audio',
        androidNotificationChannelName: 'Pemutar musik',
        androidNotificationOngoing: true,
      );
    } catch (e) {
      debugPrint('Background audio tidak aktif: $e');
    }
  }

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(const PinkBeatApp());
}

class PinkBeatApp extends StatelessWidget {
  const PinkBeatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
        ChangeNotifierProvider(create: (_) => LikesProvider()),
        // Setiap lagu mulai diputar -> otomatis masuk riwayat.
        ChangeNotifierProvider(
          create: (ctx) => PlayerProvider(
            onSongStarted: ctx.read<HistoryProvider>().add,
          ),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) {
          return MaterialApp(
            title: 'PinkBeat',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: theme.mode,
            home: const AuthGate(),
          );
        },
      ),
    );
  }
}