import 'dart:io';
import 'package:path/path.dart' hide equals;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:takt/services/dictionary_service.dart';
import 'package:takt/services/vocabulary_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
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

    final wordId = await dictDb.insert('words', {
      'word': 'Buddhismus',
      'pos': 'noun',
      'gender': 'm',
      'ipa': null,
      'base_form': 'Buddhismus',
      'freq_rank': 4200,
    });
    await dictDb.insert('definitions', {
      'word_id': wordId,
      'definition': 'buddhism',
    });

    // Seed Titel with lower ID verb stub and higher ID defined noun
    await dictDb.insert('words', {
      'id': 6938,
      'word': 'titel',
      'pos': 'verb',
      'gender': null,
      'ipa': null,
      'base_form': 'titeln',
      'freq_rank': 3128,
    });
    final nounId = await dictDb.insert('words', {
      'id': 11641,
      'word': 'Titel',
      'pos': 'noun',
      'gender': 'm',
      'ipa': '/ˈtiːtl/',
      'base_form': null,
      'freq_rank': 3128,
    });
    await dictDb.insert('definitions', {
      'word_id': nounId,
      'definition': 'title',
    });

    // Seed kleine (adj) and Kleiner (noun)
    final adjId = await dictDb.insert('words', {
      'id': 9459,
      'word': 'kleine',
      'pos': 'adj',
      'gender': null,
      'ipa': '/ˈklaɪ̯nə/',
      'base_form': 'klein',
      'freq_rank': 200,
    });
    await dictDb.insert('definitions', {
      'word_id': adjId,
      'definition': 'small, little',
    });

    final kleinerNounId = await dictDb.insert('words', {
      'id': 164153,
      'word': 'Kleiner',
      'pos': 'noun',
      'gender': 'm',
      'ipa': '/ˈklaɪ̯nɐ/',
      'base_form': null,
      'freq_rank': 4500,
    });
    await dictDb.insert('definitions', {
      'word_id': kleinerNounId,
      'definition': 'boy, young man',
    });
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

  tearDownAll(() async {
    await DictionaryService.resetForTesting();
    await VocabularyService.resetForTesting();
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

    test('lookupConsolidatedWord prioritizes defined Noun over undefined Verb stub for Titel', () async {
      final results = await DictionaryService().lookupConsolidatedWord('Titel');
      expect(results, isNotEmpty);
      final first = results.first;
      expect(first['word'], equals('Titel'));
      expect(DictionaryService.normalizePos(first['pos']?.toString()), equals('noun'));
      expect(first['gender'], equals('m'));
      expect((first['definitions'] as List), contains('title'));
    });

    test('lookupConsolidatedWord disambiguates attributive adjective before noun in context sentence', () async {
      final results = await DictionaryService().lookupConsolidatedWord(
        'kleine',
        contextSentence: 'der kleine Mann',
      );
      expect(results, isNotEmpty);
      final first = results.first;
      expect(first['word'], equals('kleine'));
      expect(DictionaryService.normalizePos(first['pos']?.toString()), equals('adj'));
      expect(first['base_form'], equals('klein'));
      expect((first['definitions'] as List), contains('small, little'));
    });

    test('fetchWiktionaryFallback handles non-existent or network errors gracefully', () async {
      final result = await DictionaryService().fetchWiktionaryFallback('nonexistentwordxyz123');
      expect(result, isNull);
    });
  });
}
