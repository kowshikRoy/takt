import 'dart:io';
import 'package:path/path.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:takt/models/saved_word.dart';
import 'package:takt/services/matching_pairs_service.dart';
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

  SavedWord savedWord(
    String id, {
    required int repetitions,
    int interval = 0,
    String? primaryDefinition,
  }) {
    return SavedWord(
      id: id,
      word: id,
      primaryDefinition: primaryDefinition ?? 'meaning of $id',
      category: VocabCategory.learning,
      dueDate: DateTime.now().subtract(const Duration(minutes: 5)),
      repetitions: repetitions,
      interval: interval,
    );
  }

  group('MatchingPairsService.buildRound', () {
    test('with zero saved words, returns a full fallback board with no duplicates', () async {
      final service = MatchingPairsService();
      final pairs = await service.buildRound();

      expect(pairs.length, MatchingPairsService.pairsPerRound);
      expect(pairs.map((p) => p.german).toSet().length, pairs.length);
      expect(pairs.map((p) => p.english).toSet().length, pairs.length);
    });

    test('blends usable saved words with fallback pairs when some are unusable', () async {
      final vocab = VocabularyService();
      // 2 usable words, 1 with an empty definition (unusable), 1 duplicating
      // another word's definition (unusable — ambiguous match).
      await vocab.upsertWord(savedWord('word0', repetitions: 0), notify: false, triggerSync: false);
      await vocab.upsertWord(savedWord('word1', repetitions: 0), notify: false, triggerSync: false);
      await vocab.upsertWord(
        savedWord('word2', repetitions: 0, primaryDefinition: ''),
        notify: false,
        triggerSync: false,
      );
      await vocab.upsertWord(
        savedWord('word3', repetitions: 0, primaryDefinition: 'meaning of word0'),
        notify: false,
        triggerSync: false,
      );

      final service = MatchingPairsService();
      final pairs = await service.buildRound();

      expect(pairs.length, MatchingPairsService.pairsPerRound);
      expect(pairs.map((p) => p.german.toLowerCase()).toSet().length, pairs.length);
      expect(pairs.map((p) => p.english.toLowerCase()).toSet().length, pairs.length);
      // word1 has a unique definition, so it's always includable. word0 and
      // word3 share a definition ("meaning of word0") — only one of the two
      // can ever be selected, whichever the pairwise-distinct guard sees
      // first; word2 (empty definition) is never includable.
      final germans = pairs.map((p) => p.german).toSet();
      expect(germans.contains('word1'), isTrue);
      expect(germans.contains('word0') ^ germans.contains('word3'), isTrue,
          reason: 'exactly one of the two colliding-definition words should be picked');
      expect(germans.contains('word2'), isFalse);
    });

    test('with 6+ distinct usable saved words, uses only real saved words, struggling first', () async {
      final vocab = VocabularyService();
      for (var i = 0; i < 4; i++) {
        // Struggling (never reviewed) words.
        await vocab.upsertWord(savedWord('struggling$i', repetitions: 0), notify: false, triggerSync: false);
      }
      for (var i = 0; i < 4; i++) {
        // Mastered words (masteryLevel 4) — should be deprioritized behind
        // the struggling (masteryLevel 0) ones above.
        await vocab.upsertWord(
          savedWord('mastered$i', repetitions: 6, interval: 40),
          notify: false,
          triggerSync: false,
        );
      }

      final service = MatchingPairsService();
      final pairs = await service.buildRound();

      expect(pairs.length, MatchingPairsService.pairsPerRound);
      final germans = pairs.map((p) => p.german).toSet();
      // All 4 struggling words should be present since they're prioritized
      // over the mastered ones and there's room for all of them.
      for (var i = 0; i < 4; i++) {
        expect(germans.contains('struggling$i'), isTrue);
      }
    });
  });
}
