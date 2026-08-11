import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takt/models/saved_word.dart';
import 'package:takt/widgets/vocab_status_pills.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VocabStatusPills (2-Button Study Deck & Known)', () {
    testWidgets('renders Study Deck and Known buttons at rest', (tester) async {
      VocabCategory? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VocabStatusPills(
              currentCategory: null,
              onCategorySelected: (cat) => selected = cat,
            ),
          ),
        ),
      );

      expect(find.text('Study Deck'), findsOneWidget);
      expect(find.text('Known'), findsOneWidget);

      // Tap Study Deck
      await tester.tap(find.text('Study Deck'));
      await tester.pumpAndSettle();
      expect(selected, equals(VocabCategory.reviewLater));

      // Tap Known
      await tester.tap(find.text('Known'));
      await tester.pumpAndSettle();
      expect(selected, equals(VocabCategory.mastered));
    });

    testWidgets('shows In Deck when category is reviewLater or learning', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VocabStatusPills(
              currentCategory: VocabCategory.learning,
              onCategorySelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('In Deck'), findsOneWidget);
      expect(find.text('Known'), findsOneWidget);
    });

    testWidgets('shows Known ✓ when category is mastered', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VocabStatusPills(
              currentCategory: VocabCategory.mastered,
              onCategorySelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Study Deck'), findsOneWidget);
      expect(find.text('Known ✓'), findsOneWidget);
    });

    testWidgets('renders Deck, Known, and Explore in a single line when onExplore is provided', (tester) async {
      bool explored = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VocabStatusPills(
              currentCategory: null,
              onCategorySelected: (_) {},
              onExplore: () => explored = true,
            ),
          ),
        ),
      );

      expect(find.text('Deck'), findsOneWidget);
      expect(find.text('Known'), findsOneWidget);
      expect(find.text('Explore'), findsOneWidget);

      await tester.tap(find.text('Explore'));
      await tester.pumpAndSettle();
      expect(explored, isTrue);
    });
  });
}
