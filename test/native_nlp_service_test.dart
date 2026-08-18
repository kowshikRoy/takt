import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takt/services/native_nlp_service.dart';
import 'package:takt/services/dictionary_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NativeNlpService Tests', () {
    test('Fallback token tagging identifies articles and capitalized nouns', () async {
      final nlp = NativeNlpService();
      final tagged = await nlp.getTaggedTokens('“Myoho-Renge-Kyo” ist der Titel der chinesischen Übersetzung');
      expect(tagged, isNotEmpty);

      final artikelTokens = tagged.where((t) => t['token']?.toLowerCase() == 'der').toList();
      expect(artikelTokens, isNotEmpty);
      expect(artikelTokens.first['pos'], equals('art'));

      final titelTokens = tagged.where((t) => t['token'] == 'Titel').toList();
      expect(titelTokens, isNotEmpty);
      expect(titelTokens.first['pos'], equals('noun'));
      expect(titelTokens.first['gender'], equals('m'));
    });

    test('MethodChannel receives and parses OpenNLP tagged tokens accurately', () async {
      const channel = MethodChannel('com.example.takt/pos_tagger');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'tagPOS') {
          return [
            {
              'token': 'Myoho-Renge-Kyo',
              'pos': 'noun',
              'lemma': 'Myoho-Renge-Kyo',
              'tag': 'PROPN',
              'engine': 'opennlp',
              'model': 'opennlp-de-ud-gsd-pos'
            },
            {
              'token': 'ist',
              'pos': 'verb',
              'lemma': 'ist',
              'tag': 'AUX',
              'engine': 'opennlp',
              'model': 'opennlp-de-ud-gsd-pos'
            },
            {
              'token': 'der',
              'pos': 'art',
              'lemma': 'der',
              'tag': 'DET',
              'engine': 'opennlp',
              'model': 'opennlp-de-ud-gsd-pos'
            },
            {
              'token': 'Titel',
              'pos': 'noun',
              'lemma': 'Titel',
              'tag': 'NOUN',
              'gender': 'm',
              'engine': 'opennlp',
              'model': 'opennlp-de-ud-gsd-pos'
            },
            {
              'token': 'der',
              'pos': 'art',
              'lemma': 'der',
              'tag': 'DET',
              'engine': 'opennlp',
              'model': 'opennlp-de-ud-gsd-pos'
            },
            {
              'token': 'chinesischen',
              'pos': 'adj',
              'lemma': 'chinesischen',
              'tag': 'ADJ',
              'engine': 'opennlp',
              'model': 'opennlp-de-ud-gsd-pos'
            },
            {
              'token': 'Übersetzung',
              'pos': 'noun',
              'lemma': 'Übersetzung',
              'tag': 'NOUN',
              'gender': 'f',
              'engine': 'opennlp',
              'model': 'opennlp-de-ud-gsd-pos'
            }
          ];
        }
        return null;
      });

      final nlp = NativeNlpService();
      final tagged = await nlp.getTaggedTokens('“Myoho-Renge-Kyo” ist der Titel der chinesischen Übersetzung');

      expect(tagged.length, equals(7));

      final titel = tagged.firstWhere((t) => t['token'] == 'Titel');
      expect(titel['pos'], equals('noun'));
      expect(titel['engine'], equals('opennlp'));
      expect(titel['gender'], equals('m'));
      expect(titel['tag'], equals('NOUN'));

      final verb = tagged.firstWhere((t) => t['token'] == 'ist');
      expect(verb['pos'], equals('verb'));
      expect(verb['engine'], equals('opennlp'));

      final adj = tagged.firstWhere((t) => t['token'] == 'chinesischen');
      expect(adj['pos'], equals('adj'));

      // Clear mock handler
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('processGermanText handles empty input gracefully', () async {
      final nlp = NativeNlpService();
      final result = await nlp.processGermanText('');
      expect(result['translation'], equals(''));
      expect(result['tokens'], isEmpty);
    });

    test('DictionaryService inferGender correctly infers gender for common German suffixes', () {
      expect(DictionaryService.inferGender('Titel'), equals(''));
      expect(DictionaryService.inferGender('Buddhismus'), equals('m'));
      expect(DictionaryService.inferGender('Übersetzung'), equals('f'));
      expect(DictionaryService.inferGender('Mädchen'), equals('n'));
      expect(DictionaryService.inferGender('Freiheit'), equals('f'));
      expect(DictionaryService.inferGender('Möglichkeit'), equals('f'));
      expect(DictionaryService.inferGender('Sozialismus'), equals('m'));
      expect(DictionaryService.inferGender('Wohnung'), equals('f'));
    });
  });
}
