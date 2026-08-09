import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' hide equals;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:takt/services/dictionary_service.dart';
import 'package:takt/services/goethe_curriculum_service.dart';
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

    // Entry 1: Bank (park bench)
    final b1 = await dictDb.insert('words', {
      'word': 'Bank',
      'pos': 'noun',
      'gender': 'f',
      'ipa': '/baŋk/',
      'base_form': 'Bank',
      'freq_rank': 1229,
    });
    await dictDb.insert('definitions', {
      'word_id': b1,
      'definition': 'bench (seat to sit in park or garden)',
    });
    await dictDb.insert('examples', {
      'word_id': b1,
      'de': 'Wir sitzen auf der Bank im Park.',
      'en': 'We sit on the bench in the park.',
    });

    // Entry 2: Bank (financial institution)
    final b2 = await dictDb.insert('words', {
      'word': 'Bank',
      'pos': 'noun',
      'gender': 'f',
      'ipa': '/baŋk/',
      'base_form': 'Bank',
      'freq_rank': 1229,
    });
    await dictDb.insert('definitions', {
      'word_id': b2,
      'definition': 'bank (financial institution for money, account)',
    });
    await dictDb.insert('examples', {
      'word_id': b2,
      'de': 'Ich bringe mein Geld zur Bank.',
      'en': 'I bring my money to the bank.',
    });

    // Entry 3: klein (adjective)
    final k1 = await dictDb.insert('words', {
      'word': 'klein',
      'pos': 'adj',
      'gender': '',
      'ipa': '/klaɪ̯n/',
      'base_form': null,
      'freq_rank': 10987,
    });
    await dictDb.insert('definitions', {
      'word_id': k1,
      'definition': 'small, little, wee (in physical size or extent)',
    });
    await dictDb.insert('definitions', {
      'word_id': k1,
      'definition': 'small, little, young (not grown up)',
    });
    await dictDb.insert('definitions', {
      'word_id': k1,
      'definition': 'insignificant (of little influence or means)',
    });

    // Entry 4: kleiner (inflected adjective form)
    await dictDb.insert('words', {
      'word': 'kleiner',
      'pos': 'adj',
      'gender': '',
      'ipa': '/ˈklaɪ̯nɐ/',
      'base_form': 'klein',
      'freq_rank': 11938,
    });

    // Entry 5: Kleiner (nominalized noun: boy, young man)
    final kNoun = await dictDb.insert('words', {
      'word': 'Kleiner',
      'pos': 'noun',
      'gender': 'm',
      'ipa': '',
      'base_form': null,
      'freq_rank': 11040,
    });
    await dictDb.insert('definitions', {
      'word_id': kNoun,
      'definition': 'boy, young man',
    });

    // Entry 6: weit (root adjective: wide, large, far)
    final weitId = await dictDb.insert('words', {
      'word': 'weit',
      'pos': 'adj',
      'gender': '',
      'ipa': '/vaɪ̯t/',
      'base_form': null,
      'freq_rank': 2500,
    });
    await dictDb.insert('definitions', {
      'word_id': weitId,
      'definition': 'wide',
    });
    await dictDb.insert('definitions', {
      'word_id': weitId,
      'definition': 'large',
    });
    await dictDb.insert('definitions', {
      'word_id': weitId,
      'definition': 'far',
    });

    // Entry 7: weiter (adverb: further, farther, on)
    final weiterAdvId = await dictDb.insert('words', {
      'word': 'weiter',
      'pos': 'adv',
      'gender': '',
      'ipa': '/ˈvaɪ̯tɐ/',
      'base_form': 'weit',
      'freq_rank': 2200,
    });
    await dictDb.insert('definitions', {
      'word_id': weiterAdvId,
      'definition': 'further, farther, more',
    });
    await dictDb.insert('definitions', {
      'word_id': weiterAdvId,
      'definition': 'on, onward (expresses continuation)',
    });
  });

  tearDownAll(() async {
    await DictionaryService.resetForTesting();
    await VocabularyService.resetForTesting();
  });

  group('Frequency, Goethe Curriculum & WSD Tests', () {
    test('Zipf score and frequency stars calculation', () {
      expect(DictionaryService.getZipfScore(4), 7.0);
      expect(DictionaryService.getZipfScore(50), 6.6);
      expect(DictionaryService.getZipfScore(300), 6.0);
      expect(DictionaryService.getFrequencyStars(300), 5);
      expect(DictionaryService.getFrequencyLabel(300), 'Top 600 Core Everyday');

      expect(DictionaryService.getZipfScore(1200), 5.3);
      expect(DictionaryService.getFrequencyStars(1200), 4);

      expect(DictionaryService.getZipfScore(3500), 4.6);
      expect(DictionaryService.getFrequencyStars(3500), 3);

      expect(DictionaryService.getZipfScore(12000), 3.3);
      expect(DictionaryService.getZipfScore(40000), 1.8);
      expect(DictionaryService.getFrequencyStars(40000), 1);
    });

    test('Goethe-Institut curriculum level verification', () {
      expect(GoetheCurriculumService.getGoetheLevel('kühlschrank'), 'A1');
      expect(GoetheCurriculumService.getGoetheLevel('fahrkarte'), 'A1');
      expect(GoetheCurriculumService.getGoetheLevel('bahnhof'), 'A1');
      expect(GoetheCurriculumService.isGoetheCertified('wasser'), isTrue);

      expect(GoetheCurriculumService.getGoetheLevel('abenteuer'), 'A2');
      expect(GoetheCurriculumService.getGoetheLevel('bescheinigung'), 'B1');
      expect(GoetheCurriculumService.getGoetheLevel('argumentieren'), 'B1');

      // CEFR level override for certified Goethe words
      expect(DictionaryService.getCefrLevel(2500, word: 'kühlschrank'), 'A1');
      expect(DictionaryService.getCefrLevel(4500, word: 'abenteuer'), 'A2');
      expect(DictionaryService.getCefrLevel(9500, word: 'bescheinigung'), 'B1');

      // Inflected forms resolving to base lemma
      expect(GoetheCurriculumService.getGoetheLevel('gestiegen', baseForm: 'steigen'), 'B1');
      expect(DictionaryService.getCefrLevel(20372, word: 'gestiegen', baseForm: 'steigen'), 'B1');
      expect(DictionaryService.getCefrLevel(5000, word: 'häuser', baseForm: 'haus'), 'A1');
    });

    test('Sense usage badge parsing', () {
      final primaryBadges = DictionaryService.parseSenseBadges('good, ethical', 0);
      expect(primaryBadges.any((b) => b['type'] == 'primary'), isTrue);

      final colloquialBadges = DictionaryService.parseSenseBadges('informal greeting (slang)', 1);
      expect(colloquialBadges.any((b) => b['type'] == 'colloquial'), isTrue);

      final figurativeBadges = DictionaryService.parseSenseBadges('figurative meaning', 1);
      expect(figurativeBadges.any((b) => b['type'] == 'figurative'), isTrue);

      final techBadges = DictionaryService.parseSenseBadges('technical term in physics', 1);
      expect(techBadges.any((b) => b['type'] == 'specialized'), isTrue);

      final archaicBadges = DictionaryService.parseSenseBadges('archaic or dated form', 1);
      expect(archaicBadges.any((b) => b['type'] == 'archaic'), isTrue);

      // Langsam senses: literal slowly vs informal idiom
      final langsamPrimary = DictionaryService.parseSenseBadges('slowly (at a slow pace), gradually, carefully', 0);
      expect(langsamPrimary.any((b) => b['type'] == 'primary'), isTrue);

      final langsamInformal = DictionaryService.parseSenseBadges(
        "it's getting to the point where; just about; used to indicate that an event is approaching that point.",
        1,
      );
      expect(langsamInformal.any((b) => b['type'] == 'colloquial'), isTrue);
      expect(langsamInformal.any((b) => b['type'] == 'primary'), isFalse);

      // Context badge on secondary meaning
      final contextBadges = DictionaryService.parseSenseBadges(
        'bank (financial institution for money, account)',
        1,
        contextMatchedIndex: 1,
      );
      expect(contextBadges.any((b) => b['type'] == 'context'), isTrue);
      expect(contextBadges.any((b) => b['type'] == 'primary'), isFalse);
    });

    test('Contextual Word Sense Disambiguation (WSD) preserves dictionary order and flags context sense', () async {
      final dict = DictionaryService();

      // Test 1: Context sentence is about park bench (Primary meaning at index 0)
      final parkEntries = await dict.lookupConsolidatedWord(
        'Bank',
        contextSentence: 'Wir sitzen auf der Bank im Park.',
      );

      expect(parkEntries, isNotEmpty);
      // Preserves bench as #1
      expect(parkEntries.first['definition'].toString().contains('bench'), isTrue);
      // No context badge needed because it's already primary (index 0)
      expect(parkEntries.first['context_matched_sense_index'], isNull);

      // Test 2: Context sentence is about money / financial bank (Secondary meaning at index 1)
      final moneyEntries = await dict.lookupConsolidatedWord(
        'Bank',
        contextSentence: 'Ich gehe zum Konto und hebe mein Geld bei der Bank ab.',
      );

      expect(moneyEntries, isNotEmpty);
      // Preserves dictionary order (#1 bench)
      expect(moneyEntries.first['definition'].toString().contains('bench'), isTrue);
      // Flags secondary meaning (index 1) as context-matched
      expect(moneyEntries.first['context_matched_sense_index'], 1);

      // Test 3: Attributive adjective in chained noun phrase (ein kleiner, goldener Schmetterling)
      final butterflyEntries = await dict.lookupConsolidatedWord(
        'kleiner',
        contextSentence: 'Es war ein kleiner, goldener Schmetterling.',
      );

      expect(butterflyEntries, isNotEmpty);
      expect(butterflyEntries.first['pos'], 'adj');
      expect(butterflyEntries.first['definition'].toString().contains('small'), isTrue);
      expect(butterflyEntries.first['definition'].toString().contains('boy'), isFalse);

      // Test 4: Separable verb particle / adverb 'weiter' in "Du kommst weiter."
      final weiterEntries = await dict.lookupConsolidatedWord(
        'weiter',
        contextSentence: 'Du kommst weiter.',
      );

      expect(weiterEntries, isNotEmpty);
      expect(weiterEntries.first['pos'], 'adv');
      expect(weiterEntries.first['definition'].toString().contains('further'), isTrue);
      expect(weiterEntries.first['definition'].toString().contains('wide'), isFalse);
    });
  });
}
