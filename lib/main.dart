import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'core/services/app_service.dart';
import 'core/services/model_service.dart';
import 'core/services/speech_service.dart';
import 'core/services/tts_service.dart';
import 'theme/providers/theme_provider.dart';
import 'features/splash/pages/splash_page.dart';
import 'utils/app_scroll_behavior.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  // Initialize core services
  await AppService.initialize();
  await SpeechService.instance.initialize();

  // Initialize theme provider before running the app
  final themeProvider = ThemeProvider();
  await themeProvider.initialize();
  
  runApp(AhamAIApp(themeProvider: themeProvider));
}

class AhamAIApp extends StatelessWidget {
  final ThemeProvider themeProvider;

  const AhamAIApp({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: ModelService.instance),
        ChangeNotifierProvider.value(value: SpeechService.instance),
        ChangeNotifierProvider.value(value: TtsService.instance),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'AhamAI',
            debugShowCheckedModeBanner: false,
            
            // Theme configuration
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            themeMode: themeProvider.themeMode,
            
            // Ultra-smooth scroll behavior
            scrollBehavior: AppScrollBehavior(),
            
            // Smooth theme transitions
            builder: (context, child) {
              return AnimatedTheme(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOutCubic,
                data: Theme.of(context),
                child: child ?? const SizedBox.shrink(),
              );
            },
            
            home: const SplashPage(),
          );
        },
      ),
    );
  }
}