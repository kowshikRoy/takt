import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takt/models/image_extraction_result.dart';
import 'package:takt/screens/create/image_extraction_review_screen.dart';

ImageExtractionResult _fixture({bool withLesson = true}) {
  return ImageExtractionResult.fromJson({
    'content_type': 'vocab_list',
    'title': 'Kitchen Vocabulary',
    'vocabulary': [
      {
        'word': 'Tisch',
        'gender': 'm',
        'pos': 'noun',
        'translation': 'table',
        'example_sentence': 'Der Tisch steht im Wohnzimmer.',
      },
      {
        'word': 'Stuhl',
        'gender': 'm',
        'translation': 'chair',
      },
    ],
    if (withLesson) 'lesson_text': 'Anna sitzt am Tisch und trinkt Kaffee.',
    'notes': 'Some handwriting was illegible.',
  });
}

void main() {
  group('ImageExtractionResult.fromJson', () {
    test('parses vocabulary and defaults selected to true', () {
      final result = _fixture();
      expect(result.title, 'Kitchen Vocabulary');
      expect(result.vocabulary, hasLength(2));
      expect(result.vocabulary.every((v) => v.selected), isTrue);
      expect(result.vocabulary.first.word, 'Tisch');
      expect(result.vocabulary.first.translation, 'table');
    });

    test('defaults saveLessonText to true only when lessonText is present', () {
      expect(_fixture(withLesson: true).saveLessonText, isTrue);
      final noLesson = _fixture(withLesson: false);
      expect(noLesson.lessonText, isNull);
      expect(noLesson.saveLessonText, isFalse);
    });
  });

  group('ImageExtractionReviewScreen', () {
    testWidgets('vocab checkboxes start checked and can be toggled off', (tester) async {
      final result = _fixture();
      await tester.pumpWidget(MaterialApp(home: ImageExtractionReviewScreen(result: result)));
      await tester.pumpAndSettle();

      final checkboxFinder = find.byType(Checkbox);
      expect(checkboxFinder, findsNWidgets(2));
      for (final element in checkboxFinder.evaluate()) {
        expect((element.widget as Checkbox).value, isTrue);
      }

      await tester.tap(checkboxFinder.first);
      await tester.pumpAndSettle();

      expect(result.vocabulary.first.selected, isFalse);
      expect(result.vocabulary.last.selected, isTrue);
    });

    testWidgets('Save is disabled once everything is deselected', (tester) async {
      final result = _fixture();
      await tester.pumpWidget(MaterialApp(home: ImageExtractionReviewScreen(result: result)));
      await tester.pumpAndSettle();

      ElevatedButton saveButton() => tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Save'));
      expect(saveButton().onPressed, isNotNull);

      for (final checkbox in find.byType(Checkbox).evaluate().toList()) {
        await tester.tap(find.byWidgetPredicate((w) => w == checkbox.widget));
        await tester.pumpAndSettle();
      }
      final switchFinder = find.byType(Switch);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(saveButton().onPressed, isNull);
    });

    testWidgets('lesson-text switch defaults on and reflects toggling', (tester) async {
      final result = _fixture();
      await tester.pumpWidget(MaterialApp(home: ImageExtractionReviewScreen(result: result)));
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(result.saveLessonText, isFalse);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    });
  });
}
