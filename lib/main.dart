import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'services/haptic_service.dart';
import 'services/notification_service.dart';
import 'services/book_guide_service.dart';
import 'services/discovery_service.dart';
import 'services/tts_service.dart';
import 'services/home_screen_widget_service.dart';
import 'screens/word_detail_screen.dart';
import 'services/phrase_service.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() {
  // Catch everything else (async errors outside the widget tree).
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      // Lock native mobile/tablet to portrait — rotation is disabled so
      // WindowClass width breakpoints stay the only responsive variable
      // (no-op on web/desktop, where there's no device orientation). A
      // platform-channel call, not network I/O, so it stays safe to await
      // synchronously here without reintroducing the blocking-startup issue
      // fixed by moving Firebase.initializeApp() into _initBackgroundServices.
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      // Catch framework-level errors (widget build/layout/paint)
      FlutterError.onError = (FlutterErrorDetails details) {
        AppLogger.error(
          'Uncaught Flutter error',
          error: details.exception,
          stackTrace: details.stack,
          tag: 'FlutterError',
        );
        FlutterError.presentError(details);
      };

      // Launch UI immediately so the user never sees a black screen
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
            ChangeNotifierProvider(create: (_) => HapticService()),
            ChangeNotifierProvider(create: (_) => NotificationService()),
            ChangeNotifierProvider(create: (_) => BookGuideService()),
            ChangeNotifierProvider(create: (_) => DiscoveryService()),
            ChangeNotifierProvider(create: (_) => TtsService()),
            ChangeNotifierProvider(create: (_) => PhraseService()),
          ],
          child: const MyApp(),
        ),
      );

      // Async background service initialization (non-blocking)
      _initBackgroundServices();
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

void _initBackgroundServices() async {
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

  void handleWidgetClick(Uri uri) {
    final rawTerm = uri.queryParameters['term'];
    if (rawTerm != null && rawTerm.isNotEmpty) {
      final term = Uri.decodeComponent(rawTerm).trim();
      void navigate() {
        appNavigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => WordDetailScreen(word: term)),
        );
      }

      if (appNavigatorKey.currentState != null) {
        navigate();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 300), navigate);
        });
      }
    }
  }

  // Initialize Home Screen Widget Service & deep links
  try {
    final widgetService = HomeScreenWidgetService();
    widgetService.onWidgetClicked.listen(handleWidgetClick);
    await widgetService.init().timeout(const Duration(seconds: 5));
    if (widgetService.initialUri != null) {
      handleWidgetClick(widgetService.initialUri!);
    }
  } catch (e) {
    AppLogger.error('Widget service init failed', error: e, tag: 'HomeWidget');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      navigatorKey: appNavigatorKey,
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
