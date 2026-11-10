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
    androidNotificationOngoing: false,
    androidStopForegroundOnPause: false,
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
        appBarTheme: const AppBarTheme(
            centerTitle: false,
            backgroundColor: Color(0xFF111418),
            surfaceTintColor: Colors.transparent,
            titleTextStyle: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFFF4EBDD))),
        iconTheme: const IconThemeData(size: 25, color: Color(0xFFE5D6C0)),
        filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
                textStyle:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                shape: const StadiumBorder())),
        outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(shape: const StadiumBorder())),
        sliderTheme: const SliderThemeData(
            trackHeight: 3,
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6)),
        navigationBarTheme: const NavigationBarThemeData(
            backgroundColor: Color(0xFF191D21),
            indicatorColor: Color(0xFF543923),
            height: 76),
        listTileTheme: ListTileThemeData(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14))),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
        ),
      ),
      home: HomeScreen(state: state),
    );
  }
}
