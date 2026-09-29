import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'data/speech_lines.dart';
import 'providers/pet_controller.dart';
import 'screens/home_screen.dart';
import 'services/sound_service.dart';
import 'services/talk_controller.dart';
import 'theme/app_theme.dart';

/// App entry point.
///
/// Responsibilities kept tiny on purpose (fast cold start):
///  1. Lock to portrait.
///  2. Create the three singletons (SoundService, PetController, TalkController).
///  3. Load speech lines + persisted settings BEFORE showing the UI (~50 ms).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait only, per the design brief.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const MikoApp());
}

class MikoApp extends StatelessWidget {
  const MikoApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Services are created once for the app's lifetime.
    final sound = SoundService();

    return MultiProvider(
      providers: [
        Provider<SoundService>.value(value: sound),
        ChangeNotifierProvider<PetController>(
          create: (_) => PetController(sound: sound, lines: SpeechLines.empty())
            ..init(), // loads counter/settings from SharedPreferences
        ),
        ChangeNotifierProvider<TalkController>(
          create: (_) => TalkController(onPlayPitched: sound.playPitchedFile),
        ),
      ],
      child: const MikoMaterialApp(),
    );
  }
}

class MikoMaterialApp extends StatefulWidget {
  const MikoMaterialApp({super.key});

  @override
  State<MikoMaterialApp> createState() => _MikoMaterialAppState();
}

class _MikoMaterialAppState extends State<MikoMaterialApp> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    // Kick off speech-line loading immediately; swap in when parsed.
    SpeechLines.load().then((lines) {
      if (!mounted) return;
      context.read<PetController>().setLines(lines);
      setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Miko Monkey',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system, // follows the OS (light cream / dark plum)
      // A blank cream frame shows instantly (native splash covers it), then
      // HomeScreen appears as soon as lines are parsed - usually <100ms.
      home: _ready
          ? const HomeScreen()
          : const ColoredBox(color: AppTheme.cream, child: SizedBox.expand()),
    );
  }
}
