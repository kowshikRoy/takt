import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' hide equals;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:takt/models/saved_word.dart';
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
    await dictDb.execute(
      'CREATE TABLE tags (id INTEGER PRIMARY KEY, tags TEXT)',
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

    // Entry 8: treffen (base verb: to meet, to hit)
    final treffenId = await dictDb.insert('words', {
      'word': 'treffen',
      'pos': 'verb',
      'gender': '',
      'ipa': '',
      'base_form': null,
      'freq_rank': 415,
    });
    await dictDb.insert('definitions', {
      'word_id': treffenId,
      'definition': 'to meet; to encounter',
    });
    await dictDb.insert('definitions', {
      'word_id': treffenId,
      'definition': 'to hit; to strike',
    });

    // Entry 9: getroffen (verb) — a past-participle stub with no definitions of
    // its own, tagged via forms/tags as "participle, past" of treffen.
    await dictDb.insert('words', {
      'word': 'getroffen',
      'pos': 'verb',
      'gender': '',
      'ipa': '',
      'base_form': 'treffen',
      'freq_rank': 771,
    });
    final participleTagId = await dictDb.insert('tags', {
      'tags': '["participle", "past"]',
    });
    await dictDb.insert('forms', {
      'word_id': treffenId,
      'form': 'getroffen',
      'tag_id': participleTagId,
    });

    // Entry 10: getroffen (adj) — a genuine standalone adjective sense.
    final getroffenAdjId = await dictDb.insert('words', {
      'word': 'getroffen',
      'pos': 'adj',
      'gender': '',
      'ipa': '',
      'base_form': null,
      'freq_rank': 771,
    });
    await dictDb.insert('definitions', {
      'word_id': getroffenAdjId,
      'definition': 'hit, struck, met',
    });
    await dictDb.insert('definitions', {
      'word_id': getroffenAdjId,
      'definition': 'taken, made (decision etc.)',
    });

    // Entry 11: leisten (base verb: to perform/provide/afford) — plus several
    // of its own inflected forms (leistet, geleistet, leisteten), all sharing
    // pos='verb' via base_form='leisten'. These are DIFFERENT words that
    // happen to share a POS, and must never be merged into one entry.
    final leistenId = await dictDb.insert('words', {
      'word': 'leisten',
      'pos': 'verb',
      'gender': '',
      'ipa': '',
      'base_form': null,
      'freq_rank': 900,
    });
    await dictDb.insert('definitions', {
      'word_id': leistenId,
      'definition': 'to perform (a task, work), to accomplish (a task)',
    });
    await dictDb.insert('definitions', {
      'word_id': leistenId,
      'definition': 'to provide (aid, service)',
    });
    await dictDb.insert('definitions', {
      'word_id': leistenId,
      'definition': 'to afford, to pay for',
    });

    Future<void> insertLeistenForm(String form, List<String> tags) async {
      await dictDb.insert('words', {
        'word': form,
        'pos': 'verb',
        'gender': '',
        'ipa': '',
        'base_form': 'leisten',
        'freq_rank': 900,
      });
      final tagId = await dictDb.insert('tags', {
        'tags': '["${tags.join('", "')}"]',
      });
      await dictDb.insert('forms', {
        'word_id': leistenId,
        'form': form,
        'tag_id': tagId,
      });
    }

    await insertLeistenForm('geleistet', ['participle', 'past']);
    await insertLeistenForm('leistet', ['third-person', 'present', 'singular']);
    await insertLeistenForm('leisteten', ['first-person', 'preterite', 'plural']);

    // Entries 12-14: a real homonym pair, mirroring "Versuchen" in the actual
    // dictionary — same spelling, same POS (noun), but two unrelated senses:
    // the nominalized verb ("das Versuchen" = the trying, neuter) and the
    // dative plural of a different noun ("Versuchen" = to/for attempts).
    final versuchenVerbId = await dictDb.insert('words', {
      'word': 'versuchen',
      'pos': 'verb',
      'gender': '',
      'ipa': '',
      'base_form': null,
      'freq_rank': 400,
    });
    await dictDb.insert('definitions', {
      'word_id': versuchenVerbId,
      'definition': 'to try, to attempt',
    });
    final infinitiveTagId = await dictDb.insert('tags', {'tags': '["infinitive"]'});
    await dictDb.insert('forms', {
      'word_id': versuchenVerbId,
      'form': 'versuchen',
      'tag_id': infinitiveTagId,
    });
    await dictDb.insert('words', {
      'word': 'Versuchen',
      'pos': 'noun',
      'gender': 'n',
      'ipa': '',
      'base_form': 'versuchen',
      'freq_rank': 400,
    });

    final versuchNounId = await dictDb.insert('words', {
      'word': 'Versuch',
      'pos': 'noun',
      'gender': 'm',
      'ipa': '',
      'base_form': null,
      'freq_rank': 800,
    });
    await dictDb.insert('definitions', {
      'word_id': versuchNounId,
      'definition': 'attempt, experiment, try',
    });
    final dativePluralTagId = await dictDb.insert('tags', {'tags': '["dative", "plural"]'});
    await dictDb.insert('forms', {
      'word_id': versuchNounId,
      'form': 'Versuchen',
      'tag_id': dativePluralTagId,
    });

    // Entries 15-16: a headword with its own real definitions ("Anruf") plus
    // one of its own declined forms ("Anrufen", dative plural) — same POS,
    // same freq_rank, so every earlier sort tier ties. The headword's own
    // content must still win the final ordering, not the inflected stub.
    final anrufId = await dictDb.insert('words', {
      'word': 'Anruf',
      'pos': 'noun',
      'gender': 'm',
      'ipa': '',
      'base_form': null,
      'freq_rank': 1205,
    });
    await dictDb.insert('definitions', {'word_id': anrufId, 'definition': 'a call, a phone call'});
    final anrufDativePluralTagId = await dictDb.insert('tags', {'tags': '["dative", "plural"]'});
    await dictDb.insert('forms', {
      'word_id': anrufId,
      'form': 'Anrufen',
      'tag_id': anrufDativePluralTagId,
    });
    await dictDb.insert('words', {
      'word': 'Anrufen',
      'pos': 'noun',
      'gender': 'm',
      'ipa': '',
      'base_form': 'Anruf',
      'freq_rank': 1205,
    });
  });

  tearDownAll(() async {
    await DictionaryService.resetForTesting();
    await VocabularyService.resetForTesting();
  });

  group('Frequency, Goethe Curriculum & WSD Tests', () {
    test('Frequency stars calculation', () {
      expect(DictionaryService.getFrequencyStars(300), 5);
      expect(DictionaryService.getFrequencyLabel(300), 'Top 600 Core Everyday');

      expect(DictionaryService.getFrequencyStars(1200), 4);

      expect(DictionaryService.getFrequencyStars(3500), 3);

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

    test('Inflected verb form with no own definitions gets a "form of" gloss, not the base verb\'s raw definitions', () async {
      final dict = DictionaryService();

      final allSenses = await dict.lookupWordAllPOS('getroffen');
      expect(allSenses.length, 2);

      // The adjective sense has genuine definitions of its own, so it's prioritized first.
      final adjSense = allSenses.firstWhere((s) => s['pos'] == 'adj');
      expect(allSenses.first['pos'], 'adj');
      expect(adjSense['definitions'], contains('hit, struck, met'));

      // The verb sense (a bare past-participle stub) gets a synthesized gloss
      // built from its forms/tags data, instead of silently inheriting
      // treffen's own infinitive-verb definitions verbatim.
      final verbSense = allSenses.firstWhere((s) => s['pos'] == 'verb');
      expect(verbSense['base_form'], 'treffen');
      expect(verbSense['definitions'], ['Past participle of treffen']);
      expect(verbSense['definitions'].toString().contains('to meet'), isFalse);

      // lookupWord() returns only the top (adjective) sense.
      final singleResult = await dict.lookupWord('getroffen');
      expect(singleResult?['pos'], 'adj');
    });

    test('Looking up a verb with a targeted POS does not merge in unrelated inflected forms that share the same POS', () async {
      final dict = DictionaryService();

      // A targeted pos:'verb' search for "leisten" also matches geleistet/
      // leistet/leisteten in the DB (base_form='leisten', pos='verb') — they
      // must stay as separate results, not get folded into "leisten"'s
      // own definitions just because they share a part of speech.
      final results = await dict.lookupConsolidatedWord('leisten', pos: 'verb');
      expect(results, isNotEmpty);

      final leistenEntry = results.firstWhere((r) => r['word'] == 'leisten');
      final defs = List<String>.from(leistenEntry['definitions'] ?? []);

      expect(defs.length, 3);
      expect(defs.any((d) => d.contains('to perform')), isTrue);
      expect(defs.any((d) => d.contains('to provide')), isTrue);
      expect(defs.any((d) => d.contains('to afford')), isTrue);

      // None of the other words' synthesized "form of" glosses should have
      // leaked into leisten's own definitions.
      expect(defs.any((d) => d.contains('Past participle')), isFalse);
      expect(defs.any((d) => d.contains('Third-person')), isFalse);
      expect(defs.any((d) => d.contains('First-person')), isFalse);
    });

    test('hydrateSavedWord never mixes a stale persisted gender with a freshly-fetched, different-sense definition', () async {
      final dict = DictionaryService();

      // Simulate a saved word whose gender was persisted incorrectly (e.g.
      // from before a dictionary fix, or from the wrong sense of this
      // word/POS homonym) — deliberately 'm', which matches neither of the
      // two real senses ('n' for the nominalized verb, empty for the dative
      // plural of Versuch).
      final saved = SavedWord(
        id: 'test-versuchen',
        word: 'Versuchen',
        pos: 'noun',
        gender: 'm',
        primaryDefinition: 'stale definition',
        definitions: const ['stale definition'],
        source: 'dictionary_saved',
      );

      final hydrated = await dict.hydrateSavedWord(saved);

      // Whichever sense the fresh lookup resolved to, gender and
      // definitions must describe the SAME sense — never a stale gender
      // paired with an unrelated fresh definition (or vice versa).
      final gender = hydrated['gender']?.toString() ?? '';
      final defs = List<String>.from(hydrated['definitions'] ?? []);
      expect(defs, isNot(contains('stale definition')));

      if (defs.any((d) => d.contains('Infinitive'))) {
        // Resolved to the nominalized-verb sense -> must be neuter, not the
        // stale persisted 'm'.
        expect(gender, 'n');
      } else if (defs.any((d) => d.contains('Dative plural'))) {
        // Resolved to the dative-plural-of-Versuch sense -> that sense has
        // no gender of its own.
        expect(gender, isEmpty);
      } else {
        fail('Unexpected definitions for a fresh lookup: $defs');
      }
    });

    test('A headword with its own definitions is never outranked by its own inflected-form stub when every other sort tier ties', () async {
      final dict = DictionaryService();

      // "Anruf" (real definitions) and "Anrufen" (its dative-plural stub,
      // synthesized gloss only) share POS and freq_rank, so context-match,
      // POS-match, and frequency all tie — only the "has its own real
      // definition" tiebreak can correctly order them.
      final results = await dict.lookupConsolidatedWord('Anruf', pos: 'noun');
      expect(results, isNotEmpty);
      expect(results.first['word'], 'Anruf');
      expect(results.first['definitions'], contains('a call, a phone call'));
    });
  });
}
