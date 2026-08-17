import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:takt/models/grammar_drill.dart';
import 'package:takt/services/grammar_drill_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  void expectValidTopics(List<GrammarDrillTopic> topics) {
    expect(topics.map((t) => t.id).toSet(), {
      GrammarDrillTopicId.verbConjugation,
      GrammarDrillTopicId.casesPrepositions,
      GrammarDrillTopicId.pronouns,
    });

    for (final topic in topics) {
      expect(topic.sheets, isNotEmpty, reason: '${topic.id} should have at least one sheet');
      for (final sheet in topic.sheets) {
        expect(sheet.questions, isNotEmpty, reason: '${sheet.id} should have at least one question');
        for (final question in sheet.questions) {
          expect(question.blanks, isNotEmpty, reason: '${question.id} should have at least one blank');
          for (final blank in question.blanks) {
            expect(blank.correctAnswer, isNotEmpty);
            if (blank.options != null) {
              expect(blank.options!.length, greaterThanOrEqualTo(2));
              expect(blank.options, contains(blank.correctAnswer),
                  reason: '${question.id} options must contain the correct answer');
            }
          }
        }
      }
    }
  }

  group('GrammarDrillService', () {
    test('embedded fallback content is valid before loading the asset', () {
      final service = GrammarDrillService();
      expectValidTopics(service.getTopics());
    });

    test('loadAssetTopics loads the curated content bank', () async {
      final service = GrammarDrillService();
      final fallbackQuestionCount = service
          .getTopics()
          .fold<int>(0, (sum, t) => sum + t.sheets.fold(0, (s, sheet) => s + sheet.questions.length));

      await service.loadAssetTopics();
      final topics = service.getTopics();
      expectValidTopics(topics);

      final loadedQuestionCount =
          topics.fold<int>(0, (sum, t) => sum + t.sheets.fold(0, (s, sheet) => s + sheet.questions.length));
      expect(loadedQuestionCount, greaterThan(fallbackQuestionCount),
          reason: 'asset JSON should load richer content than the tiny embedded fallback');
    });

    test('getBestScore returns null until a score is saved', () async {
      final service = GrammarDrillService();
      expect(await service.getBestScore('nonexistent_sheet'), isNull);
    });

    test('saveBestScore only overwrites with a higher score', () async {
      final service = GrammarDrillService();
      await service.saveBestScore('sheet_x', 0.5);
      expect(await service.getBestScore('sheet_x'), 0.5);

      await service.saveBestScore('sheet_x', 0.3);
      expect(await service.getBestScore('sheet_x'), 0.5, reason: 'lower score should not overwrite');

      await service.saveBestScore('sheet_x', 0.9);
      expect(await service.getBestScore('sheet_x'), 0.9, reason: 'higher score should overwrite');
    });
  });
}
