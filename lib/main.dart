import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/app_entry_point.dart';
import 'theme/theme_provider.dart';
import 'services/app_logger.dart';
import 'services/media_library_service.dart';
import 'services/vocabulary_service.dart';
import 'services/auth_service.dart';
import 'services/sync_service.dart';
import 'services/profile_service.dart';
import 'services/gamification_service.dart';
import 'services/curriculum_service.dart';
import 'services/sound_service.dart';
import 'services/notification_service.dart';
import 'services/book_guide_service.dart';
import 'services/discovery_service.dart';

void main() {
  // Catch everything else (async errors outside the widget tree).
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (e, st) {
        AppLogger.error(
          'Firebase initialization failed',
          error: e,
          stackTrace: st,
          tag: 'Firebase',
        );
      }

      // Catch framework-level errors (widget build/layout/paint) that would
      // otherwise only show as a red error screen in debug and vanish silently
      // in release, with nothing anywhere recording that they happened.
      FlutterError.onError = (FlutterErrorDetails details) {
        AppLogger.error(
          'Uncaught Flutter error',
          error: details.exception,
          stackTrace: details.stack,
          tag: 'FlutterError',
        );
        FlutterError.presentError(details);
      };

      runApp(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => MediaLibraryService()),
            ChangeNotifierProvider(create: (_) => VocabularyService()),
            ChangeNotifierProvider(create: (_) => AuthService()),
            ChangeNotifierProvider(create: (_) => SyncService()),
            ChangeNotifierProvider(create: (_) => ProfileService()),
            ChangeNotifierProvider(create: (_) => GamificationService()),
            ChangeNotifierProvider(create: (_) => CurriculumService()),
            ChangeNotifierProvider(create: (_) => SoundService()),
            ChangeNotifierProvider(create: (_) => NotificationService()),
            ChangeNotifierProvider(create: (_) => BookGuideService()),
            ChangeNotifierProvider(create: (_) => DiscoveryService()),
          ],
          child: const MyApp(),
        ),
      );
    },
    (error, stackTrace) {
      AppLogger.error(
        'Uncaught async error',
        error: error,
        stackTrace: stackTrace,
        tag: 'Zone',
      );
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'DeutschApp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(
        themeProvider.fontFamily,
        themeProvider.colorTheme,
      ),
      darkTheme: AppTheme.darkTheme(
        themeProvider.fontFamily,
        themeProvider.colorTheme,
      ),
      themeMode: themeProvider.themeMode,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AppEntryPoint(),
    );
  }
}
