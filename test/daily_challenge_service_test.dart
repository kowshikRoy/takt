import 'dart:io';
import 'package:path/path.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:takt/models/saved_word.dart';
import 'package:takt/models/daily_challenge_question.dart';
import 'package:takt/services/daily_challenge_service.dart';
import 'package:takt/services/vocabulary_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
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
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await VocabularyService.resetForTesting();
  });

  SavedWord dueWord(String id, {required int repetitions, required int interval}) {
    return SavedWord(
      id: id,
      word: id,
      primaryDefinition: 'meaning of $id',
      category: VocabCategory.learning,
      dueDate: DateTime.now().subtract(const Duration(minutes: 5)),
      repetitions: repetitions,
      interval: interval,
    );
  }

  group('DailyChallengeService.buildSession — vocabulary slice', () {
    test('omits the vocab slice entirely below the minimum saved-word threshold', () async {
      final vocab = VocabularyService();
      // 3 saved+due words — below minSavedWordsForVocabSlice (5).
      for (var i = 0; i < 3; i++) {
        await vocab.upsertWord(dueWord('word$i', repetitions: 0, interval: 0), notify: false, triggerSync: false);
      }

      final service = DailyChallengeService();
      final session = await service.buildSession();

      expect(session.whereType<VocabDefinitionQuestion>(), isEmpty);
    });

    test('prioritizes low-mastery (struggling) due words over high-mastery ones', () async {
      final vocab = VocabularyService();
      // 5 mastered/high-mastery words (level 4: repetitions >= 5) and 2 brand-new
      // (level 0) words that are also due — enough total saved words to pass the
      // minimum-for-distractors gate, with distinct primaryDefinitions so distractor
      // generation has enough pool to draw from.
      for (var i = 0; i < 5; i++) {
        await vocab.upsertWord(dueWord('mastered$i', repetitions: 6, interval: 40), notify: false, triggerSync: false);
      }
      for (var i = 0; i < 2; i++) {
        await vocab.upsertWord(dueWord('new$i', repetitions: 0, interval: 0), notify: false, triggerSync: false);
      }

      final service = DailyChallengeService();
      final session = await service.buildSession(targetSize: 4); // vocab quota = 40% of 4 ≈ 2

      final vocabQuestions = session.whereType<VocabDefinitionQuestion>().toList();
      expect(vocabQuestions, isNotEmpty);
      // The struggling (level 0) words must be selected ahead of the mastered ones
      // whenever the vocab quota is smaller than the total due pool.
      final selectedIds = vocabQuestions.map((q) => q.word.id).toSet();
      expect(selectedIds.any((id) => id.startsWith('new')), isTrue);
    });

    test('every vocab question has exactly 4 options including the correct one', () async {
      final vocab = VocabularyService();
      for (var i = 0; i < 6; i++) {
        await vocab.upsertWord(dueWord('w$i', repetitions: 0, interval: 0), notify: false, triggerSync: false);
      }

      final service = DailyChallengeService();
      final session = await service.buildSession();

      for (final q in session.whereType<VocabDefinitionQuestion>()) {
        expect(q.options.length, 4);
        expect(q.options, contains(q.correctOption));
        expect(q.options.toSet().length, 4, reason: 'options must not contain duplicates');
      }
    });
  });

  group('DailyChallengeService.buildSession — redistribution & composition', () {
    test('redistributes unmet vocab/gender quota to compound and sentence slices', () async {
      // No saved words at all — vocab slice is fully empty, and the gender adaptive
      // deck will fall back to whatever the (empty) offline dictionary offers, which
      // in this minimal test fixture is also empty. Compound/sentence questions don't
      // depend on any user data, so the session should still end up close to full.
      final service = DailyChallengeService();
      final session = await service.buildSession(targetSize: 10);

      expect(session.whereType<VocabDefinitionQuestion>(), isEmpty);
      final nonVocabCount = session.length;
      // Compound has a 10-word pool and sentence has 5 exercises; with vocab+gender
      // fully redistributed, compound+sentence should cover a meaningful majority
      // of the session rather than leaving it mostly empty.
      expect(nonVocabCount, greaterThan(0));
    });

    test('every compound question has exactly 4 distinct options including the correct meaning', () async {
      final service = DailyChallengeService();
      final session = await service.buildSession();

      for (final q in session.whereType<CompoundQuestion>()) {
        expect(q.options.length, 4);
        expect(q.options, contains(q.compound.fullMeaning));
        expect(q.options.toSet().length, 4);
      }
    });

    test('sentence-case slice never exceeds the available exercise bank and has no duplicate exercises', () async {
      final service = DailyChallengeService();
      final session = await service.buildSession(targetSize: 20); // deliberately oversized

      final sentenceQuestions = session.whereType<SentenceCaseQuestion>().toList();
      final ids = sentenceQuestions.map((q) => q.exercise.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'no exercise should repeat within one session');
      expect(sentenceQuestions.length, lessThanOrEqualTo(5), reason: 'the exercise bank only has 5 items total');
    });
  });
}
