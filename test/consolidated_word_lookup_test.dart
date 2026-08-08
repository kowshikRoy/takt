import 'dart:io';
import 'package:path/path.dart' hide equals;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:takt/services/dictionary_service.dart';
import 'package:takt/services/vocabulary_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await DictionaryService.resetForTesting();
    await VocabularyService.resetForTesting();

    final dbDir = await databaseFactory.getDatabasesPath();
    final dictDbPath = join(dbDir, 'german_dictionary.db');
    if (await File(dictDbPath).exists()) {
      await File(dictDbPath).delete();
    }
    final dictDb = await databaseFactory.openDatabase(dictDbPath);
    await dictDb.execute(
      'CREATE TABLE words (id INTEGER PRIMARY KEY, word TEXT, pos TEXT, gender TEXT, ipa TEXT, base_form TEXT, freq_rank INTEGER)',
    );
    await dictDb.execute(
      'CREATE TABLE definitions (id INTEGER PRIMARY KEY, word_id INTEGER, definition TEXT)',
    );
    await dictDb.execute(
      'CREATE TABLE forms (id INTEGER PRIMARY KEY, word_id INTEGER, form TEXT, tag_id INTEGER)',
    );
    await dictDb.execute(
      'CREATE TABLE examples (id INTEGER PRIMARY KEY, word_id INTEGER, de TEXT, en TEXT)',
    );
    await dictDb.close();

    final vocabDbPath = join(dbDir, 'vocabulary.db');
    if (await File(vocabDbPath).exists()) {
      await File(vocabDbPath).delete();
    }
    final vocabDb = await databaseFactory.openDatabase(vocabDbPath);
    await vocabDb.execute(
      'CREATE TABLE words (id TEXT PRIMARY KEY, word TEXT, baseForm TEXT, pos TEXT, gender TEXT, primaryDefinition TEXT, definitions TEXT, ipa TEXT, contextSentence TEXT, sourceTitle TEXT, contextExamples TEXT, category TEXT, interval INTEGER, easeFactor REAL, repetitions INTEGER, dueDate TEXT, lastReviewed TEXT, createdAt TEXT)',
    );
    await vocabDb.close();
  });

  group('Consolidated Word Lookup & POS Normalization Tests', () {
    test('normalizePos standardizes various POS formats', () {
      expect(DictionaryService.normalizePos('Noun'), equals('noun'));
      expect(DictionaryService.normalizePos('Substantiv'), equals('noun'));
      expect(DictionaryService.normalizePos('Verb'), equals('verb'));
      expect(DictionaryService.normalizePos('Adjektiv'), equals('adj'));
      expect(DictionaryService.normalizePos('Adverb'), equals('adv'));
      expect(DictionaryService.normalizePos('Präposition'), equals('prep'));
      expect(DictionaryService.normalizePos('Pronomen'), equals('pron'));
      expect(DictionaryService.normalizePos('Konjunktion'), equals('conj'));
      expect(DictionaryService.normalizePos('Redewendung'), equals('phrase'));
    });

    test('lookupConsolidatedWord trims spaces and handles empty queries gracefully', () async {
      final results = await DictionaryService().lookupConsolidatedWord('');
      expect(results, isEmpty);

      final spaceResults = await DictionaryService().lookupConsolidatedWord('   ');
      expect(spaceResults, isEmpty);
    });

    test('lookupConsolidatedWord resolves Buddhismus with noun POS and masculine gender', () async {
      final results = await DictionaryService().lookupConsolidatedWord('Buddhismus');
      expect(results, isNotEmpty);
      final first = results.first;
      expect(first['word'], equals('Buddhismus'));
      expect(DictionaryService.normalizePos(first['pos']?.toString()), equals('noun'));
      expect(first['gender'], equals('m'));
      expect((first['definitions'] as List).isNotEmpty, isTrue);
    });
  });
}
