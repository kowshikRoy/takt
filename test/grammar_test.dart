import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:takt/models/grammar_lesson.dart';
import 'package:takt/services/grammar_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const sampleJson = '''
  {
    "id": "lesson_modalverben_praeteritum",
    "level": "A2",
    "title": "Modalverben im Präteritum",
    "subtitle": "Talking about past obligations",
    "category": "Verben & Zeiten",
    "summary": "Learn how modal verbs conjugate in the past.",
    "sections": [
      {
        "id": "sec1",
        "type": "explanation",
        "title": "When to use",
        "explanation_payload": {
          "text": "Modal verbs express necessity.",
          "bullet_points": ["müssen → had to", "können → could"]
        }
      },
      {
        "id": "sec2",
        "type": "formula",
        "title": "Word Order",
        "formula_payload": {
          "formula_structure": "Subject + Modalverb (Pos 2) + ... + Infinitiv (End)",
          "blocks": [
            {
              "position": "Pos 1",
              "label": "Subjekt",
              "example_word": "Ich",
              "color_tag": "neutral"
            },
            {
              "position": "Pos 2",
              "label": "Modalverb",
              "example_word": "musste",
              "color_tag": "primary"
            }
          ]
        }
      },
      {
        "id": "sec3",
        "type": "table",
        "title": "Conjugations",
        "table_payload": {
          "headers": ["Pronoun", "müssen"],
          "rows": [["ich", "musste"], ["du", "musstest"]],
          "footnote": "Note: ich == er/sie/es"
        }
      },
      {
        "id": "sec4",
        "type": "examples",
        "title": "Examples",
        "example_payload": [
          {
            "german": "Ich musste lernen.",
            "english": "I had to learn.",
            "note": "Modal verb in Pos 2",
            "highlighted_words": ["musste", "lernen"]
          }
        ]
      },
      {
        "id": "sec5",
        "type": "exceptions",
        "title": "Umlaut loss",
        "exception_payload": [
          {
            "rule_name": "No umlauts",
            "description": "Umlauts disappear in Präteritum.",
            "example_sentences": ["müssen → musste"]
          }
        ]
      },
      {
        "id": "sec6",
        "type": "tip",
        "title": "Teacher tip",
        "tip_payload": {
          "title": "möchten vs wollten",
          "content": "Never use mochte for wanted.",
          "is_warning": true
        }
      }
    ]
  }
  ''';

  group('GrammarLesson & Sealed Sections', () {
    test('parses all 6 polymorphic section types correctly', () {
      final Map<String, dynamic> data = jsonDecode(sampleJson);
      final lesson = GrammarLesson.fromJson(data);

      expect(lesson.id, 'lesson_modalverben_praeteritum');
      expect(lesson.level, 'A2');
      expect(lesson.title, 'Modalverben im Präteritum');
      expect(lesson.category, 'Verben & Zeiten');
      expect(lesson.sections.length, 6);

      // Section 1: Explanation
      final s1 = lesson.sections[0];
      expect(s1, isA<ExplanationSection>());
      final expl = s1 as ExplanationSection;
      expect(expl.payload.text, 'Modal verbs express necessity.');
      expect(expl.payload.bulletPoints?.length, 2);

      // Section 2: Formula
      final s2 = lesson.sections[1];
      expect(s2, isA<FormulaSection>());
      final form = s2 as FormulaSection;
      expect(form.payload.blocks.length, 2);
      expect(form.payload.blocks[0].exampleWord, 'Ich');
      expect(form.payload.blocks[1].colorTag, 'primary');

      // Section 3: Table
      final s3 = lesson.sections[2];
      expect(s3, isA<TableSection>());
      final tab = s3 as TableSection;
      expect(tab.payload.headers, ['Pronoun', 'müssen']);
      expect(tab.payload.rows.length, 2);
      expect(tab.payload.footnote, 'Note: ich == er/sie/es');

      // Section 4: Examples
      final s4 = lesson.sections[3];
      expect(s4, isA<ExamplesSection>());
      final ex = s4 as ExamplesSection;
      expect(ex.examples.first.german, 'Ich musste lernen.');
      expect(ex.examples.first.highlightedWords, ['musste', 'lernen']);

      // Section 5: Exceptions
      final s5 = lesson.sections[4];
      expect(s5, isA<ExceptionsSection>());
      final exc = s5 as ExceptionsSection;
      expect(exc.exceptions.first.ruleName, 'No umlauts');

      // Section 6: Tip
      final s6 = lesson.sections[5];
      expect(s6, isA<TipSection>());
      final tip = s6 as TipSection;
      expect(tip.payload.title, 'möchten vs wollten');
      expect(tip.payload.isWarning, true);
    });

    test('round-trips through toJson()', () {
      final Map<String, dynamic> data = jsonDecode(sampleJson);
      final lesson = GrammarLesson.fromJson(data);
      final reEncoded = lesson.toJson();

      expect(reEncoded['id'], lesson.id);
      expect(reEncoded['level'], lesson.level);
      expect(reEncoded['title'], lesson.title);
      expect((reEncoded['sections'] as List).length, 6);
    });

    test('pattern matching is exhaustive', () {
      final Map<String, dynamic> data = jsonDecode(sampleJson);
      final lesson = GrammarLesson.fromJson(data);

      for (final section in lesson.sections) {
        final description = switch (section) {
          ExplanationSection(:final payload) => 'Explanation: ${payload.text}',
          FormulaSection(:final payload) => 'Formula: ${payload.formulaStructure}',
          TableSection(:final payload) => 'Table: ${payload.headers.join(",")}',
          ExamplesSection(:final examples) => 'Examples: ${examples.length}',
          ExceptionsSection(:final exceptions) => 'Exceptions: ${exceptions.length}',
          TipSection(:final payload) => 'Tip: ${payload.title}',
        };
        expect(description, isNotEmpty);
      }
    });
  });

  group('GrammarService', () {
    test('tracks completed lessons and persists in SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final service = GrammarService();
      await service.init();

      expect(service.isLessonCompleted('lesson_modalverben_praeteritum'), isFalse);

      final marked = await service.markLessonCompleted('lesson_modalverben_praeteritum');
      expect(marked, isTrue);
      expect(service.isLessonCompleted('lesson_modalverben_praeteritum'), isTrue);

      // Duplicate mark returns false
      final markedAgain = await service.markLessonCompleted('lesson_modalverben_praeteritum');
      expect(markedAgain, isFalse);
    });
  });

  group('assets/grammar/german_grammar_lessons.json Content & Schema Validation', () {
    test('all lessons in assets file parse cleanly and satisfy schema constraints', () {
      final file = File('assets/grammar/german_grammar_lessons.json');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      final List<dynamic> jsonList = jsonDecode(content);
      expect(jsonList.length, greaterThanOrEqualTo(9));

      final seenIds = <String>{};
      for (final item in jsonList) {
        final Map<String, dynamic> lessonMap = item as Map<String, dynamic>;
        final lesson = GrammarLesson.fromJson(lessonMap);

        // ID must be unique and valid
        expect(lesson.id, isNotEmpty);
        expect(seenIds.contains(lesson.id), isFalse, reason: 'Duplicate ID: ${lesson.id}');
        seenIds.add(lesson.id);

        // Core fields must not be empty
        expect(lesson.title, isNotEmpty);
        expect(lesson.subtitle, isNotEmpty);
        expect(lesson.level, isNotEmpty);
        expect(lesson.category, isNotEmpty);
        expect(lesson.summary, isNotEmpty);
        expect(lesson.sections, isNotEmpty);

        // Every section should correctly pattern match and serialize
        for (final section in lesson.sections) {
          expect(section.id, isNotEmpty);
          expect(section.type, isNotEmpty);
          final reserialized = section.toJson();
          expect(reserialized['id'], section.id);
          expect(reserialized['type'], section.type);
        }
      }

      // Check all 5 A1 lessons are present
      expect(seenIds.contains('lesson_svo_sentence_structure'), isTrue);
      expect(seenIds.contains('lesson_personal_pronouns'), isTrue);
      expect(seenIds.contains('lesson_question_formation'), isTrue);
      expect(seenIds.contains('lesson_noun_genders_articles'), isTrue);
      expect(seenIds.contains('lesson_numbers_and_age'), isTrue);
    });
  });
}
