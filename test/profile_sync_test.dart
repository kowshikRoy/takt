import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:takt/models/saved_word.dart';
import 'package:takt/services/profile_service.dart';
import 'package:takt/services/vocabulary_service.dart';
import 'package:takt/services/discovery_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

  @override
  Stream<UserPlatform?> idTokenChanges() {
    return const Stream.empty();
  }

  @override
  Stream<UserPlatform?> userChanges() {
    return const Stream.empty();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    FirebasePlatform.instance = MockFirebasePlatform();
    FirebaseAuthPlatform.instance = MockFirebaseAuthPlatform();
    await Firebase.initializeApp();
  });

  group('ProfileService Sync & Stats Merging', () {
    test(
      'mergeRemoteStats merges dates additively and updates best streak',
      () async {
        SharedPreferences.setMockInitialValues({
          'profile_activity_dates_v1': ['2026-08-01', '2026-08-02'],
          'profile_best_streak_v1': 2,
        });

        final service = ProfileService();
        await service.testReset();

        expect(service.activityDates.contains('2026-08-01'), isTrue);
        expect(service.activityDates.contains('2026-08-02'), isTrue);
        expect(service.bestStreak, 2);

        // Perform merge
        await service.mergeRemoteStats([
          '2026-08-02',
          '2026-08-03',
          '2026-08-04',
        ], 5);

        // Check merged activity dates (union of local and remote)
        expect(service.activityDates.contains('2026-08-01'), isTrue);
        expect(service.activityDates.contains('2026-08-02'), isTrue);
        expect(service.activityDates.contains('2026-08-03'), isTrue);
        expect(service.activityDates.contains('2026-08-04'), isTrue);

        // Check merged best streak (takes the max)
        expect(service.bestStreak, 5);
      },
    );

    test(
      'mergeRemoteStats handles nulls and lower values without regression',
      () async {
        SharedPreferences.setMockInitialValues({
          'profile_activity_dates_v1': ['2026-08-01'],
          'profile_best_streak_v1': 10,
        });

        final service = ProfileService();
        await service.testReset();

        // Merge with lower best streak and null dates list
        await service.mergeRemoteStats(null, 3);

        expect(service.activityDates.contains('2026-08-01'), isTrue);
        expect(service.bestStreak, 10); // Remains 10, not clobbered by 3
      },
    );

    test('VocabularyService recordReview updates and preserves SRS fields locally', () async {
      SharedPreferences.setMockInitialValues({});
      final vocab = VocabularyService();
      await vocab.removeWord('test_haus_srs');

      final initialWord = SavedWord(
        id: 'test_haus_srs',
        word: 'Haus_SRS',
        primaryDefinition: 'house',
        interval: 0,
        repetitions: 0,
        dueDate: DateTime.now().subtract(const Duration(hours: 1)),
      );

      await vocab.upsertWord(initialWord);
      final savedBefore = await vocab.getSavedWord('test_haus_srs');
      expect(savedBefore, isNotNull);
      expect(savedBefore!.repetitions, 0);

      // Perform a review rating (good)
      await vocab.recordReview('test_haus_srs', ReviewRating.good);

      final reviewedWord = await vocab.getSavedWord('test_haus_srs');
      expect(reviewedWord, isNotNull);
      expect(reviewedWord!.repetitions, 1);
      expect(reviewedWord.interval, 1);
      expect(reviewedWord.lastReviewed, isNotNull);
      expect(reviewedWord.dueDate.isAfter(DateTime.now()), isTrue);

      // Re-saving with a new example context sentence does NOT wipe out review progress
      final updatedWithContext = SavedWord(
        id: 'test_haus_srs',
        word: 'Haus_SRS',
        primaryDefinition: 'house',
        contextSentence: 'Das ist ein schönes Haus.',
      );
      await vocab.upsertWord(updatedWithContext);

      final recheckedWord = await vocab.getSavedWord('test_haus_srs');
      expect(recheckedWord, isNotNull);
      expect(recheckedWord!.repetitions, 1);
      expect(recheckedWord.interval, 1);
      expect(recheckedWord.lastReviewed, isNotNull);

      // Cleanup
      await vocab.removeWord('test_haus_srs');
    });

    test('DiscoveryService persists savedTodayCount locally and reloads it', () async {
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      SharedPreferences.setMockInitialValues({
        'daily_discovery_pool_date_v2': todayStr,
        'daily_discovery_saved_today_v2': 3,
        'daily_discovery_pool_v2': '[]',
      });

      final discovery = DiscoveryService();
      await discovery.loadPool(forceRefresh: false);

      expect(discovery.savedTodayCount, 3);
    });

    test('ProfileService records today reviews and today words saved', () async {
      SharedPreferences.setMockInitialValues({});
      final profile = ProfileService();
      await profile.testReset();

      expect(profile.todayReviewsCount, 0);
      expect(profile.todayWordsSaved, 0);

      await profile.recordActivityToday(review: true, wordSaved: true);

      expect(profile.todayReviewsCount, 1);
      expect(profile.todayWordsSaved, 1);
    });
  });
}
