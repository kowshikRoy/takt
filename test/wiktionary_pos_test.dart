import 'package:flutter_test/flutter_test.dart';
import 'package:takt/services/dictionary_service.dart';

void main() {
  group('DictionaryService POS Normalization & Wiktionary Precedence', () {
    test('normalizePos standardizes POS strings to canonical tags', () {
      expect(DictionaryService.normalizePos('Noun'), 'noun');
      expect(DictionaryService.normalizePos('substantiv'), 'noun');
      expect(DictionaryService.normalizePos('Nomen'), 'noun');
      expect(DictionaryService.normalizePos('v'), 'verb');
      expect(DictionaryService.normalizePos('Verb'), 'verb');
      expect(DictionaryService.normalizePos('Adjektiv'), 'adj');
      expect(DictionaryService.normalizePos('adj'), 'adj');
      expect(DictionaryService.normalizePos('Adverb'), 'adv');
      expect(DictionaryService.normalizePos('Präposition'), 'prep');
      expect(DictionaryService.normalizePos('Pronomen'), 'pron');
      expect(DictionaryService.normalizePos('Konjunktion'), 'conj');
      expect(DictionaryService.normalizePos('Interjektion'), 'interj');
      expect(DictionaryService.normalizePos('Numeral'), 'num');
      expect(DictionaryService.normalizePos('Redewendung'), 'phrase');
      expect(DictionaryService.normalizePos(''), '');
      expect(DictionaryService.normalizePos(null), '');
    });

    test('inferGender correctly identifies grammatical genders by noun suffixes', () {
      // Feminine suffixes (-ung, -heit, -keit, -schaft, -tion, -ei, -tät, -ik)
      expect(DictionaryService.inferGender('Zeitung'), 'f');
      expect(DictionaryService.inferGender('Freiheit'), 'f');
      expect(DictionaryService.inferGender('Möglichkeit'), 'f');
      expect(DictionaryService.inferGender('Freundschaft'), 'f');
      expect(DictionaryService.inferGender('Station'), 'f');
      expect(DictionaryService.inferGender('Bäckerei'), 'f');
      expect(DictionaryService.inferGender('Universität'), 'f');
      expect(DictionaryService.inferGender('Musik'), 'f');

      // Neuter suffixes (-chen, -tum, -ment, -um)
      expect(DictionaryService.inferGender('Mädchen'), 'n');
      expect(DictionaryService.inferGender('Eigentum'), 'n');
      expect(DictionaryService.inferGender('Dokument'), 'n');
      expect(DictionaryService.inferGender('Museum'), 'n');

      // Masculine suffixes (-ismus, -ling, -or, -ist)
      expect(DictionaryService.inferGender('Optimismus'), 'm');
      expect(DictionaryService.inferGender('Schmetterling'), 'm');
      expect(DictionaryService.inferGender('Motor'), 'm');
      expect(DictionaryService.inferGender('Polizist'), 'm');
    });

    test('inferGender respects explicit rawGender when valid', () {
      expect(DictionaryService.inferGender('Tisch', rawGender: 'm'), 'm');
      expect(DictionaryService.inferGender('Tisch', rawGender: 'masculine'), 'm');
      expect(DictionaryService.inferGender('Lampe', rawGender: 'f'), 'f');
      expect(DictionaryService.inferGender('Lampe', rawGender: 'feminine'), 'f');
      expect(DictionaryService.inferGender('Buch', rawGender: 'n'), 'n');
      expect(DictionaryService.inferGender('Buch', rawGender: 'neuter'), 'n');
    });
  });
}
