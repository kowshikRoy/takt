import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:takt/models/saved_word.dart';
import 'package:takt/screens/word_detail_screen.dart';
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
    final dbPath = join(dbDir, 'german_dictionary.db');
    if (await File(dbPath).exists()) {
      await File(dbPath).delete();
    }
    final db = await databaseFactory.openDatabase(dbPath);
    await db.execute(
      'CREATE TABLE words (id INTEGER PRIMARY KEY, word TEXT, pos TEXT, gender TEXT, ipa TEXT, base_form TEXT, freq_rank INTEGER)',
    );
    await db.execute(
      'CREATE TABLE definitions (id INTEGER PRIMARY KEY, word_id INTEGER, definition TEXT)',
    );
    await db.execute(
      'CREATE TABLE forms (id INTEGER PRIMARY KEY, word_id INTEGER, form TEXT, tag_id INTEGER)',
    );
    await db.execute(
      'CREATE TABLE tags (id INTEGER PRIMARY KEY, tags TEXT)',
    );
    await db.execute(
      'CREATE TABLE examples (id INTEGER PRIMARY KEY, word_id INTEGER, de TEXT, en TEXT)',
    );

    await db.insert('words', {
      'id': 1,
      'word': 'Haus',
      'pos': 'noun',
      'gender': 'n',
      'ipa': '/haʊ̯s/',
      'base_form': null,
      'freq_rank': 100,
    });
    await db.insert('definitions', {
      'id': 1,
      'word_id': 1,
      'definition': 'house, building, home',
    });
    await db.insert('examples', {
      'id': 1,
      'word_id': 1,
      'de': 'Er baut ein großes Haus.',
      'en': 'He is building a large house.',
    });
    await db.close();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await VocabularyService.resetForTesting();
  });

  testWidgets(
    'WordDetailScreen displays multi-source encounters from movies, articles, and books in Examples tab',
    (tester) async {
      final vocabService = VocabularyService();

      final saved = SavedWord(
        id: 'haus',
        word: 'Haus',
        gender: 'n',
        pos: 'noun',
        primaryDefinition: 'house, building',
        contextExamples: [
          WordContextExample(
            sentence: 'Wir gehen heute in das neue Haus.',
            translation: 'We are going into the new house today.',
            sourceTitle: 'YouTube - Easy German Episode 50',
            sourceType: 'video',
          ),
          WordContextExample(
            sentence: 'Das alte Haus am Fluss stand viele Jahre leer.',
            translation: 'The old house by the river was empty for many years.',
            sourceTitle: 'Der Zauberer von Oz (Kapitel 2)',
            sourceType: 'article',
          ),
          WordContextExample(
            sentence: 'Lektion 3: Wohnen und Leben im Haus.',
            translation: 'Lesson 3: Living in the house.',
            sourceTitle: 'Schritte International A1 (Unit 3)',
            sourceType: 'book',
          ),
        ],
      );

      await vocabService.upsertWord(saved, notify: false, triggerSync: false);

      await tester.pumpWidget(
        MaterialApp(
          home: WordDetailScreen(
            word: 'Haus',
            wordData: {
              'word': 'Haus',
              'pos': 'noun',
              'gender': 'n',
              'definitions': ['house, building, home'],
              'examples': [
                {
                  'de': 'Er baut ein großes Haus.',
                  'en': 'He is building a large house.',
                }
              ],
            },
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Check that Real-World Encounters header is rendered
      expect(find.textContaining('REAL-WORLD ENCOUNTERS'), findsOneWidget);

      // Check that all 3 sources badges are visible
      expect(find.text('Movie / Media'), findsOneWidget);
      expect(find.text('Article'), findsOneWidget);
      expect(find.text('Book'), findsOneWidget);

      // Check that sentences and source titles are rendered
      expect(find.textContaining('Easy German Episode 50'), findsOneWidget);
      expect(find.textContaining('Der Zauberer von Oz'), findsOneWidget);
      expect(find.textContaining('Schritte International A1'), findsOneWidget);

      // Check that standard dictionary examples are also present
      expect(find.textContaining('DICTIONARY EXAMPLES'), findsOneWidget);
      expect(find.textContaining('Er baut ein großes'), findsOneWidget);
    },
  );
}
