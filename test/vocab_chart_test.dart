import 'package:flutter_test/flutter_test.dart';
import 'package:takt/models/saved_word.dart';

void main() {
  group('Vocabulary Chart & SRS Retention Logic', () {
    test('Correctly groups words into 5 SRS mastery stages', () {
      final words = [
        SavedWord(
          id: 'w1',
          word: 'Apfel',
          primaryDefinition: 'apple',
          interval: 0,
          repetitions: 0,
          category: VocabCategory.learning,
        ),
        SavedWord(
          id: 'w2',
          word: 'Buch',
          primaryDefinition: 'book',
          interval: 3,
          repetitions: 1,
          category: VocabCategory.learning,
        ),
        SavedWord(
          id: 'w3',
          word: 'Katze',
          primaryDefinition: 'cat',
          interval: 12,
          repetitions: 2,
          category: VocabCategory.learning,
        ),
        SavedWord(
          id: 'w4',
          word: 'Hund',
          primaryDefinition: 'dog',
          interval: 30,
          repetitions: 3,
          category: VocabCategory.learning,
        ),
        SavedWord(
          id: 'w5',
          word: 'Schule',
          primaryDefinition: 'school',
          interval: 90,
          repetitions: 5,
          category: VocabCategory.mastered,
        ),
      ];

      int stage0 = 0;
      int stage1 = 0;
      int stage2 = 0;
      int stage3 = 0;
      int stage4 = 0;

      for (final w in words) {
        if (w.category == VocabCategory.mastered || w.masteryLevel >= 4) {
          stage4++;
        } else if (w.masteryLevel == 3) {
          stage3++;
        } else if (w.masteryLevel == 2) {
          stage2++;
        } else if (w.masteryLevel == 1) {
          stage1++;
        } else {
          stage0++;
        }
      }

      expect(stage0, 1); // Apfel
      expect(stage1, 1); // Buch
      expect(stage2, 1); // Katze
      expect(stage3, 1); // Hund
      expect(stage4, 1); // Schule
    });

    test('Daily word date bucket aggregation is accurate', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));

      final words = [
        SavedWord(
          id: 'w1',
          word: 'Zeit',
          primaryDefinition: 'time',
          createdAt: today.add(const Duration(hours: 2)),
        ),
        SavedWord(
          id: 'w2',
          word: 'Raum',
          primaryDefinition: 'space',
          createdAt: today.add(const Duration(hours: 4)),
        ),
        SavedWord(
          id: 'w3',
          word: 'Welt',
          primaryDefinition: 'world',
          createdAt: yesterday.add(const Duration(hours: 5)),
        ),
      ];

      final todayWords = words.where((w) =>
          !w.createdAt.isBefore(today) &&
          w.createdAt.isBefore(today.add(const Duration(days: 1)))).toList();
      final yesterdayWords = words.where((w) =>
          !w.createdAt.isBefore(yesterday) &&
          w.createdAt.isBefore(today)).toList();

      expect(todayWords.length, 2);
      expect(yesterdayWords.length, 1);
    });
  });
}
