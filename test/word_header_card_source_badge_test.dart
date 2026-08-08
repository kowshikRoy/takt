import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takt/widgets/word_header_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestCard(Map<String, dynamic> wordData) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: WordHeaderCard(
            wordData: wordData,
            savedWordIds: const {},
            savedWordCategories: const {},
            onCategorySelected: (_) {},
          ),
        ),
      ),
    );
  }

  group('WordHeaderCard Meaning Source Badge Tests', () {
    testWidgets('Displays My Library badge when meaning is from user database', (tester) async {
      final data = {
        'word': 'Haus',
        'pos': 'noun',
        'gender': 'n',
        'definitions': ['house, building'],
        'source': 'user_database',
        'isFromUserDatabase': true,
      };

      await tester.pumpWidget(buildTestCard(data));
      await tester.pump();

      expect(find.text('My Library'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
    });

    testWidgets('Displays Dictionary badge for offline dictionary match', (tester) async {
      final data = {
        'word': 'gehen',
        'pos': 'verb',
        'definitions': ['to walk, to go'],
        'source': 'german_dictionary',
      };

      await tester.pumpWidget(buildTestCard(data));
      await tester.pump();

      expect(find.text('Dictionary'), findsOneWidget);
      expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);
    });

    testWidgets('Displays Wiktionary badge for Wiktionary fallback matches', (tester) async {
      final data = {
        'word': 'Takt',
        'pos': 'noun',
        'gender': 'm',
        'definitions': ['beat, rhythm, cycle'],
        'source': 'wiktionary',
        'isWiktionaryFallback': true,
      };

      await tester.pumpWidget(buildTestCard(data));
      await tester.pump();

      expect(find.text('Wiktionary'), findsOneWidget);
      expect(find.byIcon(Icons.public_rounded), findsOneWidget);
    });

    testWidgets('Displays Google Translate badge for machine translation safety net', (tester) async {
      final data = {
        'word': 'unbekannt',
        'pos': 'adj',
        'definitions': ['unknown'],
        'source': 'nmt_translation',
        'isNmtTranslation': true,
      };

      await tester.pumpWidget(buildTestCard(data));
      await tester.pump();

      expect(find.text('Google Translate'), findsOneWidget);
      expect(find.byIcon(Icons.g_translate_rounded), findsOneWidget);
    });
  });
}
