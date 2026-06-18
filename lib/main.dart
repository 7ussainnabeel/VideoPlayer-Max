import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'constants/styles.dart';
import 'providers/media_library_manager.dart';
import 'providers/playback_manager.dart';
import 'screens/main_shell.dart';

import 'screens/pin_lock_screen.dart';

import 'package:audio_service/audio_service.dart';
import 'providers/audio_handler.dart';
import 'providers/carplay_manager.dart';

late AudioHandler audioHandler;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize CarPlay MethodChannel
  CarPlayManager.init();
  
  // Initialize AudioService for lock screen and background controls
  audioHandler = await AudioService.init(
    builder: () => VideoPlayerMaxAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.multimedia.player.channel.audio',
      androidNotificationChannelName: 'VideoPlayer Max Playback',
      androidNotificationOngoing: true,
      androidShowNotificationBadge: true,
    ),
  );
  
  // Lock orientation to portrait (standard for this layout)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MediaLibraryManager()),
        ChangeNotifierProvider(create: (_) => PlaybackManager()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Backgrounded - trigger security lock
      Provider.of<MediaLibraryManager>(context, listen: false).lockApp();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MediaLibraryManager>(
      builder: (context, libraryManager, child) {
        return MaterialApp(
          title: 'VideoPlayer Max',
          debugShowCheckedModeBanner: false,
          themeMode: libraryManager.themeMode,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            primaryColor: AppStyles.primaryRed,
            scaffoldBackgroundColor: const Color(0xFFF1F5F9),
            appBarTheme: const AppBarTheme(
              backgroundColor: AppStyles.primaryRed,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            sliderTheme: SliderThemeData(
              activeTrackColor: AppStyles.primaryRed,
              thumbColor: AppStyles.primaryRed,
              overlayColor: AppStyles.primaryRed.withValues(alpha: 0.12),
              trackHeight: 3.0,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            primaryColor: AppStyles.primaryRed,
            scaffoldBackgroundColor: AppStyles.scaffoldBackground,
            appBarTheme: const AppBarTheme(
              backgroundColor: AppStyles.primaryRed,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            sliderTheme: SliderThemeData(
              activeTrackColor: AppStyles.primaryRed,
              thumbColor: AppStyles.primaryRed,
              overlayColor: AppStyles.primaryRed.withValues(alpha: 0.12),
              trackHeight: 3.0,
            ),
          ),
          home: libraryManager.isAppLocked
              ? const PinLockScreen()
              : const MainShell(),
        );
      },
    );
  }
}
