import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'services/app_state.dart';

import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'br.com.walkman.playback',
    androidNotificationChannelName: 'Reprodução Walkmen',
    androidNotificationOngoing: true,
    androidNotificationIcon: 'drawable/ic_stat_walkmen',
  );
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const WalkmanApp());
}

class WalkmanApp extends StatelessWidget {
  const WalkmanApp({super.key, this.state});
  final AppState? state;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFFF8A32),
      brightness: Brightness.dark,
      primary: const Color(0xFFFF8A32),
      surface: const Color(0xFF202123),
    );
    return MaterialApp(
      title: 'Walkmen',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFF141516),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: false),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
        ),
      ),
      home: HomeScreen(state: state),
    );
  }
}
