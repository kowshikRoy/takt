import 'package:flutter_test/flutter_test.dart';
import 'package:takt/screens/story_reader_screen.dart';
import 'package:takt/screens/video_screen.dart';
import 'package:takt/models/saved_word.dart';

void main() {
  group('Key Vocabulary Calculation & Models', () {
    test('KeyStoryVocab maps freqRank correctly to CEFR difficulty levels', () {
      final a1Word = KeyStoryVocab(
        word: 'Haus',
        primaryDefinition: 'house',
        paragraphIndex: 0,
        paragraphOriginal: 'Das Haus ist schön.',
        paragraphTranslated: 'The house is beautiful.',
        freqRank: 150,
      );
      expect(a1Word.difficultyLabel, 'A1');

      final a2Word = KeyStoryVocab(
        word: 'Fenster',
        primaryDefinition: 'window',
        paragraphIndex: 0,
        paragraphOriginal: 'Das Fenster ist offen.',
        paragraphTranslated: 'The window is open.',
        freqRank: 750,
      );
      expect(a2Word.difficultyLabel, 'A2');

      final b1Word = KeyStoryVocab(
        word: 'Begeisterung',
        primaryDefinition: 'enthusiasm',
        paragraphIndex: 0,
        paragraphOriginal: 'Voller Begeisterung.',
        paragraphTranslated: 'Full of enthusiasm.',
        freqRank: 2500,
      );
      expect(b1Word.difficultyLabel, 'B1');

      final b2Word = KeyStoryVocab(
        word: 'Zweckmäßigkeit',
        primaryDefinition: 'expediency',
        paragraphIndex: 0,
        paragraphOriginal: 'Aus Gründen der Zweckmäßigkeit.',
        paragraphTranslated: 'For reasons of expediency.',
        freqRank: 6000,
      );
      expect(b2Word.difficultyLabel, 'B2');

      final c1Word = KeyStoryVocab(
        word: 'unabdingbar',
        primaryDefinition: 'indispensable',
        paragraphIndex: 0,
        paragraphOriginal: 'Es ist unabdingbar.',
        paragraphTranslated: 'It is indispensable.',
        freqRank: 15000,
      );
      expect(c1Word.difficultyLabel, 'C1');
    });

    test('KeyMediaVocab fullWordWithArticle formats gender articles correctly', () {
      final masc = KeyMediaVocab(
        word: 'Tisch',
        gender: 'm',
        primaryDefinition: 'table',
        cueIndex: 0,
        cueStartTime: 0.0,
        cueOriginal: 'Der Tisch ist groß.',
        cueTranslated: 'The table is big.',
        difficultyLabel: 'A1',
      );
      expect(masc.article, 'der');
      expect(masc.fullWordWithArticle, 'der Tisch');

      final fem = KeyMediaVocab(
        word: 'Sonne',
        gender: 'f',
        primaryDefinition: 'sun',
        cueIndex: 0,
        cueStartTime: 0.0,
        cueOriginal: 'Die Sonne scheint.',
        cueTranslated: 'The sun is shining.',
        difficultyLabel: 'A1',
      );
      expect(fem.article, 'die');
      expect(fem.fullWordWithArticle, 'die Sonne');

      final neu = KeyMediaVocab(
        word: 'Buch',
        gender: 'n',
        primaryDefinition: 'book',
        cueIndex: 0,
        cueStartTime: 0.0,
        cueOriginal: 'Das Buch ist gut.',
        cueTranslated: 'The book is good.',
        difficultyLabel: 'A1',
      );
      expect(neu.article, 'das');
      expect(neu.fullWordWithArticle, 'das Buch');
    });

    test('SavedWord unified ID matches lowercased word string', () {
      final word = 'Gesellschaft';
      final saved = SavedWord(
        id: word.toLowerCase().trim(),
        word: word,
        primaryDefinition: 'society',
      );
      expect(saved.id, 'gesellschaft');
    });
  });
}
