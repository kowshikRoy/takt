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
import 'package:takt/screens/practice/daily_challenge_screen.dart';
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
  FirebaseAuthPlatform setInitialValues({dynamic currentUser, dynamic languageCode}) {
    return this;
  }

  @override
  UserPlatform? get currentUser => null;

  @override
  Stream<UserPlatform?> authStateChanges() => const Stream.empty();

  @override
  Stream<UserPlatform?> idTokenChanges() => const Stream.empty();

  @override
  Stream<UserPlatform?> userChanges() => const Stream.empty();
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

  testWidgets('answering a vocab question and a gender question updates real SRS state and daily-goal counters',
      (tester) async {
    final vocab = VocabularyService();
    final profile = ProfileService();

    // "Katze" is the only due word with a gender set — the sole candidate for both
    // the vocab slice (due-words pool) and the gender slice (due-SRS-nouns pool),
    // so which specific words show up as those question types is deterministic.
    // Four extra non-due filler words satisfy the vocab-slice's minimum-saved-words
    // gate and supply distinct distractor definitions.
    await tester.runAsync(() async {
      await vocab.upsertWord(
        SavedWord(
          id: 'katze',
          word: 'Katze',
          gender: 'f',
          primaryDefinition: 'cat',
          category: VocabCategory.learning,
          dueDate: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await vocab.upsertWord(
          SavedWord(
            id: 'filler$i',
            word: 'Filler$i',
            primaryDefinition: 'filler meaning $i',
            category: VocabCategory.learning,
            dueDate: DateTime.now().add(const Duration(days: 30)),
          ),
        );
      }
    });

    expect(profile.todayReviewsCount, 0);

    await tester.pumpWidget(createTestApp(const DailyChallengeScreen()));

    await tester.runAsync(() async {
      for (int i = 0; i < 50; i++) {
        await Future.delayed(const Duration(milliseconds: 50));
        await tester.pump();
        if (find.text('Katze').evaluate().isNotEmpty) break;
      }
    });

    bool answeredVocab = false;
    bool answeredGender = false;

    // Option tiles and gender buttons carry ValueKeys ('option_<text>' /
    // 'gender_<code>') specifically so tests can target an actual answerable
    // widget reliably, instead of an ambiguous `find.byType(InkWell)` which can
    // also match incidental InkWells elsewhere in the tree (e.g. from IconButton).
    bool isOptionKey(Key? key) => key is ValueKey && key.value.toString().startsWith('option_');
    bool isGenderKey(Key? key) => key is ValueKey && key.value.toString().startsWith('gender_');

    // Walk the session, answering the two "Katze" questions (vocab + gender) when
    // encountered and just advancing through everything else, up to a safety cap.
    for (var step = 0; step < 20 && !(answeredVocab && answeredGender); step++) {
      final onKatzeGenderQuestion =
          find.byKey(const ValueKey('gender_f')).evaluate().isNotEmpty && find.text('Katze').evaluate().isNotEmpty;
      final onKatzeVocabQuestion =
          !onKatzeGenderQuestion && find.byKey(const ValueKey('option_cat')).evaluate().isNotEmpty;

      if (onKatzeGenderQuestion) {
        await tester.tap(find.byKey(const ValueKey('gender_f'))); // Katze is feminine
        answeredGender = true;
      } else if (onKatzeVocabQuestion) {
        await tester.tap(find.byKey(const ValueKey('option_cat')));
        answeredVocab = true;
      } else {
        final anyOption = find.byWidgetPredicate((w) => isOptionKey(w.key));
        final anyGender = find.byWidgetPredicate((w) => isGenderKey(w.key));
        if (anyOption.evaluate().isNotEmpty) {
          await tester.tap(anyOption.first);
        } else if (anyGender.evaluate().isNotEmpty) {
          await tester.tap(anyGender.first);
        }
      }

      await tester.runAsync(() async {
        for (int i = 0; i < 30; i++) {
          await Future.delayed(const Duration(milliseconds: 50));
          await tester.pump();
          if (find.text('Continue').evaluate().isNotEmpty || find.text('Finish').evaluate().isNotEmpty) break;
        }
      });

      final continueButton = find.text('Continue').evaluate().isNotEmpty
          ? find.text('Continue')
          : find.text('Finish');
      if (continueButton.evaluate().isNotEmpty) {
        await tester.tap(continueButton);
        await tester.runAsync(() async {
          for (int i = 0; i < 30; i++) {
            await Future.delayed(const Duration(milliseconds: 50));
            await tester.pump();
          }
        });
      }
    }

    expect(answeredVocab, isTrue, reason: 'expected to encounter and answer the Katze vocab question');
    expect(answeredGender, isTrue, reason: 'expected to encounter and answer the Katze gender question');

    SavedWord? updated;
    await tester.runAsync(() async {
      updated = await vocab.getSavedWord('katze');
    });
    expect(updated, isNotNull);
    expect(updated!.repetitions, greaterThan(0), reason: 'answering both questions should have advanced SRS repetitions');
    expect(updated!.lastReviewed, isNotNull);

    expect(profile.todayReviewsCount, greaterThan(0));
    expect(profile.isDailyGoalAchieved || profile.dailyTasksCompleted >= 1, isTrue);

    await tester.pumpWidget(Container());
    await tester.pump(const Duration(seconds: 1));
  });
}
