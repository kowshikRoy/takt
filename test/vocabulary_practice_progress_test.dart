import 'dart:io';
import 'package:path/path.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:takt/models/saved_word.dart';
import 'package:takt/screens/practice/vocabulary_practice_screen.dart';
import 'package:takt/services/profile_service.dart';
import 'package:takt/services/vocabulary_service.dart';
import 'package:takt/services/gamification_service.dart';
import 'package:takt/services/sound_service.dart';
import 'package:takt/theme/theme_provider.dart';
import 'package:google_fonts/google_fonts.dart';

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
    GoogleFonts.config.allowRuntimeFetching = false;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dbDir = await databaseFactory.getDatabasesPath();
    final dbPath = join(dbDir, 'german_dictionary.db');
    if (!await File(dbPath).exists()) {
      final db = await databaseFactory.openDatabase(dbPath);
      await db.execute(
        'CREATE TABLE words (id INTEGER PRIMARY KEY, word TEXT, pos TEXT, gender TEXT, ipa TEXT, base_form TEXT)',
      );
      await db.close();
    }
    FirebasePlatform.instance = MockFirebasePlatform();
    FirebaseAuthPlatform.instance = MockFirebaseAuthPlatform();
    await Firebase.initializeApp();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await VocabularyService.resetForTesting();
    await ProfileService().testReset();
  });

  Widget createTestApp(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider.value(value: VocabularyService()),
        ChangeNotifierProvider.value(value: ProfileService()),
        ChangeNotifierProvider.value(value: GamificationService()),
        ChangeNotifierProvider.value(value: SoundService()),
      ],
      child: MaterialApp(home: child),
    );
  }

  group('Vocabulary Practice & Progress Tracking Tests', () {
    test('Saving a new word records wordSaved activity in ProfileService', () async {
      final vocab = VocabularyService();
      final profile = ProfileService();

      expect(profile.todayWordsSaved, 0);

      final word = SavedWord(
        id: 'haus',
        word: 'Haus',
        gender: 'n',
        primaryDefinition: 'house',
        category: VocabCategory.learning,
      );

      await vocab.upsertWord(word);

      expect(profile.todayWordsSaved, 1);
      expect(profile.dailyTasksCompleted, greaterThanOrEqualTo(1));
    });

    test('recordReview updates word SRS scheduling and records review activity', () async {
      final vocab = VocabularyService();
      final profile = ProfileService();

      final word = SavedWord(
        id: 'wasser',
        word: 'Wasser',
        gender: 'n',
        primaryDefinition: 'water',
        category: VocabCategory.learning,
        interval: 0,
        repetitions: 0,
      );

      await vocab.upsertWord(word);
      expect(profile.todayReviewsCount, 0);

      // 1. Review with Good rating
      await vocab.recordReview('wasser', ReviewRating.good);

      final updated = await vocab.getSavedWord('wasser');
      expect(updated, isNotNull);
      expect(updated!.repetitions, 1);
      expect(updated.interval, 1);
      expect(updated.lastReviewed, isNotNull);
      expect(profile.todayReviewsCount, 1);

      // 2. Review again with Easy rating
      await vocab.recordReview('wasser', ReviewRating.easy);
      final updated2 = await vocab.getSavedWord('wasser');
      expect(updated2!.repetitions, 2);
      expect(updated2.interval, 10);
      expect(profile.todayReviewsCount, 2);
      expect(profile.dailyTasksCompleted, greaterThanOrEqualTo(2));
    });

    test('SM-2 Again rating resets repetitions to 0 and schedules next day', () async {
      final vocab = VocabularyService();

      final word = SavedWord(
        id: 'baum',
        word: 'Baum',
        gender: 'm',
        primaryDefinition: 'tree',
        category: VocabCategory.learning,
        interval: 10,
        repetitions: 3,
        easeFactor: 2.5,
      );

      await vocab.upsertWord(word);
      await vocab.recordReview('baum', ReviewRating.again);

      final updated = await vocab.getSavedWord('baum');
      expect(updated!.repetitions, 0);
      expect(updated.interval, 1);
      expect(updated.easeFactor, closeTo(2.3, 0.01));
    });

    testWidgets('VocabularyPracticeScreen rates card, advances SRS, and shows completion stats',
        (tester) async {
      final vocab = VocabularyService();
      final profile = ProfileService();

      final word = SavedWord(
        id: 'katze',
        word: 'Katze',
        gender: 'f',
        primaryDefinition: 'cat',
        contextSentence: 'Die Katze schlaeft auf dem Sofa.',
        category: VocabCategory.learning,
        dueDate: DateTime.now().subtract(const Duration(minutes: 5)),
      );

      await tester.runAsync(() async {
        await vocab.upsertWord(word);
      });

      await tester.pumpWidget(
        createTestApp(const VocabularyPracticeScreen()),
      );

      await tester.runAsync(() async {
        for (int i = 0; i < 50; i++) {
          await Future.delayed(const Duration(milliseconds: 50));
          await tester.pump();
          if (find.text('Katze').evaluate().isNotEmpty) break;
        }
      });

      // Card is displayed with word and flip hint
      expect(find.text('Katze'), findsOneWidget);
      expect(find.text('Tap card to flip answer'), findsOneWidget);

      // Flip card to reveal answer and rating buttons
      await tester.tap(find.byType(InkWell).first);

      await tester.runAsync(() async {
        for (int i = 0; i < 50; i++) {
          await Future.delayed(const Duration(milliseconds: 50));
          await tester.pump();
          if (find.text('Good').evaluate().isNotEmpty) break;
        }
      });

      expect(find.text('Good'), findsOneWidget);
      expect(find.text('Easy'), findsOneWidget);
      expect(find.text('Again'), findsOneWidget);

      // Rate card as Good
      await tester.tap(find.text('Good'));

      await tester.runAsync(() async {
        for (int i = 0; i < 50; i++) {
          await Future.delayed(const Duration(milliseconds: 50));
          await tester.pump();
          if (find.text('Review Session Complete! 🎉').evaluate().isNotEmpty) break;
        }
      });

      // Verify that review was recorded
      SavedWord? reviewedWord;
      await tester.runAsync(() async {
        final all = await vocab.getSavedWords();
        reviewedWord = all.isNotEmpty ? all.first : null;
      });
      expect(reviewedWord, isNotNull);
      expect(reviewedWord!.repetitions, 1);
      expect(reviewedWord!.lastReviewed, isNotNull);

      // Verify completion card is shown with rich stats
      expect(find.text('Review Session Complete! 🎉'), findsOneWidget);
      expect(find.text('REVIEWED'), findsOneWidget);
      expect(find.text('MASTERY PTS'), findsOneWidget);
      expect(find.text('LEVEL'), findsOneWidget);
      expect(find.text('STREAK'), findsOneWidget);

      await tester.pumpWidget(Container());
      await tester.pump(const Duration(seconds: 11));
    });
  });
}
