import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:takt/l10n/app_localizations.dart';
import 'package:takt/screens/settings_screen.dart';
import 'package:takt/services/auth_service.dart';
import 'package:takt/services/book_guide_service.dart';
import 'package:takt/services/curriculum_service.dart';
import 'package:takt/services/discovery_service.dart';
import 'package:takt/services/gamification_service.dart';
import 'package:takt/services/media_library_service.dart';
import 'package:takt/services/notification_service.dart';
import 'package:takt/services/profile_service.dart';
import 'package:takt/services/sound_service.dart';
import 'package:takt/services/sync_service.dart';
import 'package:takt/services/tts_service.dart';
import 'package:takt/services/vocabulary_service.dart';
import 'package:takt/theme/theme_provider.dart';

class MockFirebasePlatform extends FirebasePlatform {
  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) {
    return MockFirebaseApp();
  }

  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async {
    return MockFirebaseApp();
  }
}

class MockFirebaseApp extends FirebaseAppPlatform {
  MockFirebaseApp()
    : super(
        '[DEFAULT]',
        const FirebaseOptions(
          apiKey: 'mock-api-key',
          appId: 'mock-app-id',
          messagingSenderId: 'mock-sender-id',
          projectId: 'mock-project-id',
        ),
      );
}

class MockFirebaseAuthPlatform extends FirebaseAuthPlatform {
  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) {
    return this;
  }

  @override
  FirebaseAuthPlatform setInitialValues({
    dynamic currentUser,
    dynamic languageCode,
  }) {
    return this;
  }

  @override
  UserPlatform? get currentUser => null;

  @override
  Stream<UserPlatform?> authStateChanges() {
    return const Stream.empty();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FirebasePlatform.instance = MockFirebasePlatform();
    FirebaseAuthPlatform.instance = MockFirebaseAuthPlatform();
    await Firebase.initializeApp();
  });

  group('TtsVoice Model Tests', () {
    test('formats Android voice names into human-readable labels', () {
      const v1 = TtsVoice(name: 'de-de-x-deg-local', locale: 'de-DE');
      expect(v1.label, 'German Voice DEG (Offline)');
      expect(v1.regionLabel, 'Germany (de-DE)');

      const v2 = TtsVoice(name: 'de-de-x-deb-network', locale: 'de-DE');
      expect(v2.label, 'German Voice DEB (HQ)');
      expect(v2.regionLabel, 'Germany (de-DE)');
    });

    test('formats standard names and web voice names', () {
      const v1 = TtsVoice(name: 'Anna', locale: 'de-DE', gender: 'female', quality: 'Enhanced');
      expect(v1.label, 'Anna');
      expect(v1.regionLabel, 'Germany (de-DE)');
      expect(v1.details, 'Germany (de-DE) • Female • Enhanced');

      const v2 = TtsVoice(name: 'Microsoft Stefan Online (Natural) - German (Germany)', locale: 'de-DE');
      expect(v2.label, 'Stefan (Natural)');
    });

    test('formats Austrian and Swiss German regions correctly', () {
      const vAt = TtsVoice(name: 'de-at-x-at-local', locale: 'de-AT');
      expect(vAt.regionLabel, 'Austria (de-AT)');

      const vCh = TtsVoice(name: 'de-ch-x-ch-local', locale: 'de-CH');
      expect(vCh.regionLabel, 'Switzerland (de-CH)');
    });

    test('equality and hashCode match identical voices', () {
      const v1 = TtsVoice(name: 'Anna', locale: 'de-DE');
      const v2 = TtsVoice(name: 'Anna', locale: 'de-DE');
      const v3 = TtsVoice(name: 'Markus', locale: 'de-DE');

      expect(v1, equals(v2));
      expect(v1.hashCode, equals(v2.hashCode));
      expect(v1, isNot(equals(v3)));
    });
  });

  group('TtsService Voice Selection & Persistence Tests', () {
    test('setting voice updates selectedVoice and persists to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final service = TtsService();

      const customVoice = TtsVoice(name: 'Anna', locale: 'de-DE');
      await service.setVoice(customVoice);

      expect(service.selectedVoice, equals(customVoice));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('tts_voice_name_v1'), 'Anna');
      expect(prefs.getString('tts_voice_locale_v1'), 'de-DE');

      // Reset to system default (null)
      await service.setVoice(null);
      expect(service.selectedVoice, isNull);
      expect(prefs.getString('tts_voice_name_v1'), isNull);
    });

    test('speech rate setting updates and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final service = TtsService();

      await service.setSpeechRate(0.8);
      expect(service.speechRate, 0.8);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('tts_speech_rate_v1'), 0.8);
    });
  });

  group('SettingsScreen German Voice UI Tests', () {
    testWidgets('SettingsScreen displays German Voice tile and opens selection dialog', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
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
            ChangeNotifierProvider(create: (_) => TtsService()),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify the German Voice tile is present
      final voiceTileFinder = find.text('German Voice (TTS)');
      expect(voiceTileFinder, findsOneWidget);
      expect(find.textContaining('System Default'), findsWidgets);

      // Ensure visible and tap on German Voice tile to open dialog
      await tester.ensureVisible(voiceTileFinder);
      await tester.tap(voiceTileFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify dialog is shown with title and options
      expect(find.text('Select German Voice'), findsOneWidget);
      expect(find.text('System Default'), findsWidgets);
      expect(find.text('Speech Speed'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Close'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Dialog should be dismissed
      expect(find.text('Select German Voice'), findsNothing);
    });
  });
}
