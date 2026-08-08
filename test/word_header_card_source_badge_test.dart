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
    testWidgets('Displays Dictionary badge when saved word is from dictionary', (tester) async {
      final data = {
        'word': 'Haus',
        'pos': 'noun',
        'gender': 'n',
        'definitions': ['house, building'],
        'source': 'dictionary_saved',
        'isFromUserDatabase': true,
      };

      await tester.pumpWidget(buildTestCard(data));
      await tester.pump();

      expect(find.text('Dictionary'), findsOneWidget);
      expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);
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
        'source': 'wiktionary_fetched',
        'isWiktionaryFallback': true,
      };

      await tester.pumpWidget(buildTestCard(data));
      await tester.pump();

      expect(find.text('Wiktionary'), findsOneWidget);
      expect(find.byIcon(Icons.public_rounded), findsOneWidget);
    });

    testWidgets('Displays Custom Note badge for custom edited words', (tester) async {
      final data = {
        'word': 'Titel',
        'pos': 'noun',
        'gender': 'm',
        'definitions': ['headline, title'],
        'source': 'user_edited',
        'isFromUserDatabase': true,
      };

      await tester.pumpWidget(buildTestCard(data));
      await tester.pump();

      expect(find.text('Custom Note'), findsOneWidget);
      expect(find.byIcon(Icons.edit_note_rounded), findsOneWidget);
    });
  });
}
