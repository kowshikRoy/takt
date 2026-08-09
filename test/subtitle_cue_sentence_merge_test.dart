import 'package:flutter_test/flutter_test.dart';
import 'package:takt/models/subtitle_cue.dart';

void main() {
  group('SubtitleCue Sentence Merge Tests', () {
    test('isSentenceTerminal correctly identifies terminal punctuation vs abbreviations', () {
      expect(SubtitleCue.isSentenceTerminal('Hallo.'), isTrue);
      expect(SubtitleCue.isSentenceTerminal('Wie geht es dir?'), isTrue);
      expect(SubtitleCue.isSentenceTerminal('Auf Wiedersehen!'), isTrue);
      expect(SubtitleCue.isSentenceTerminal('Er sagte: "Komm!"'), isTrue);
      expect(SubtitleCue.isSentenceTerminal('Das ist super…'), isTrue);

      // Non-terminals and abbreviations
      expect(SubtitleCue.isSentenceTerminal('Hallo'), isFalse);
      expect(SubtitleCue.isSentenceTerminal('Wir haben z.B.'), isFalse);
      expect(SubtitleCue.isSentenceTerminal('Dr.'), isFalse);
      expect(SubtitleCue.isSentenceTerminal('Heute ist der 1.'), isFalse);
      expect(SubtitleCue.isSentenceTerminal('Wenn ich komme,'), isFalse);
    });

    test('mergeFragmentedCues combines Whisper chunks into complete sentences', () {
      final fragmented = [
        SubtitleCue(start: 0.0, end: 1.5, original: 'Hallo und herzlich', translated: 'Hello and warmly'),
        SubtitleCue(start: 1.5, end: 3.2, original: 'willkommen zu unserem neuen', translated: 'welcome to our new'),
        SubtitleCue(start: 3.2, end: 4.8, original: 'Video.', translated: 'video.'),
        SubtitleCue(start: 5.2, end: 7.0, original: 'Heute lernen wir,', translated: 'Today we learn,'),
        SubtitleCue(start: 7.1, end: 9.3, original: 'wie man auf Deutsch', translated: 'how to in German'),
        SubtitleCue(start: 9.3, end: 11.0, original: 'im Supermarkt einkauft!', translated: 'shop at the supermarket!'),
      ];

      final merged = SubtitleCue.mergeFragmentedCues(fragmented);

      expect(merged.length, 2);
      expect(merged[0].start, 0.0);
      expect(merged[0].end, 4.8);
      expect(merged[0].original, 'Hallo und herzlich willkommen zu unserem neuen Video.');
      expect(merged[0].translated, 'Hello and warmly welcome to our new video.');

      expect(merged[1].start, 5.2);
      expect(merged[1].end, 11.0);
      expect(merged[1].original, 'Heute lernen wir, wie man auf Deutsch im Supermarkt einkauft!');
      expect(merged[1].translated, 'Today we learn, how to in German shop at the supermarket!');
    });

    test('mergeFragmentedCues preserves already complete separate sentences', () {
      final sentences = [
        SubtitleCue(start: 0.0, end: 2.0, original: 'Guten Tag!', translated: 'Good day!'),
        SubtitleCue(start: 2.5, end: 5.0, original: 'Wie heißen Sie?', translated: 'What is your name?'),
        SubtitleCue(start: 5.5, end: 8.0, original: 'Ich heiße Anna.', translated: 'My name is Anna.'),
      ];

      final merged = SubtitleCue.mergeFragmentedCues(sentences);

      expect(merged.length, 3);
      expect(merged[0].original, 'Guten Tag!');
      expect(merged[1].original, 'Wie heißen Sie?');
      expect(merged[2].original, 'Ich heiße Anna.');
    });

    test('mergeFragmentedCues does not break on abbreviations', () {
      final cues = [
        SubtitleCue(start: 0.0, end: 2.0, original: 'Wir verkaufen Obst, z.B.', translated: 'We sell fruit, e.g.'),
        SubtitleCue(start: 2.1, end: 4.5, original: 'Äpfel, Birnen und Bananen.', translated: 'apples, pears and bananas.'),
      ];

      final merged = SubtitleCue.mergeFragmentedCues(cues);

      expect(merged.length, 1);
      expect(merged[0].original, 'Wir verkaufen Obst, z.B. Äpfel, Birnen und Bananen.');
    });
  });
}
