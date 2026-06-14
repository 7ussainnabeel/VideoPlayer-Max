import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'constants/styles.dart';
import 'providers/media_library_manager.dart';
import 'providers/playback_manager.dart';
import 'screens/main_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VideoPlayer Max',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
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
      home: const MainShell(),
    );
  }
}
