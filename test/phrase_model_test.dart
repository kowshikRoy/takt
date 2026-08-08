import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:takt/models/german_phrase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sampleJson = '''
  {
    "id": "phr_der_rest_ist_fuer_sie",
    "german": "Der Rest ist für Sie.",
    "english": "Keep the change.",
    "literalTranslation": "The rest is for you.",
    "category": "Restaurant & Dining",
    "level": "A1",
    "formality": "formal",
    "situation": "When paying your bill at a restaurant, café, or in a taxi to tip the server/driver.",
    "culturalNote": "In Germany, tipping is given directly when handing cash.",
    "dialogue": {
      "speakerA": "Das macht dann 18 Euro 50, bitte.",
      "speakerB": "Hier sind 20 Euro. Der Rest ist für Sie!",
      "englishA": "That makes 18.50 euros, please.",
      "englishB": "Here is 20 euros. Keep the change!"
    },
    "tags": ["tipping", "restaurant", "paying"],
    "relatedPhrases": ["Stimmt so!"]
  }
  ''';

  group('GermanPhrase Model', () {
    test('parses sample JSON correctly into GermanPhrase', () {
      final Map<String, dynamic> data = jsonDecode(sampleJson);
      final phrase = GermanPhrase.fromJson(data);

      expect(phrase.id, 'phr_der_rest_ist_fuer_sie');
      expect(phrase.german, 'Der Rest ist für Sie.');
      expect(phrase.english, 'Keep the change.');
      expect(phrase.literalTranslation, 'The rest is for you.');
      expect(phrase.category, 'Restaurant & Dining');
      expect(phrase.level, 'A1');
      expect(phrase.formality, 'formal');
      expect(phrase.dialogue, isNotNull);
      expect(phrase.dialogue!.speakerA, 'Das macht dann 18 Euro 50, bitte.');
      expect(phrase.dialogue!.speakerB, 'Hier sind 20 Euro. Der Rest ist für Sie!');
      expect(phrase.tags, contains('tipping'));
      expect(phrase.relatedPhrases, contains('Stimmt so!'));
    });

    test('round-trips through toJson()', () {
      final Map<String, dynamic> data = jsonDecode(sampleJson);
      final phrase = GermanPhrase.fromJson(data);
      final reEncoded = phrase.toJson();

      expect(reEncoded['id'], phrase.id);
      expect(reEncoded['german'], phrase.german);
      expect(reEncoded['english'], phrase.english);
      expect(reEncoded['dialogue']['speakerA'], phrase.dialogue!.speakerA);
    });

    test('validates all 1,000+ phrases in assets/phrases/german_phrases.json', () {
      final file = File('assets/phrases/german_phrases.json');
      expect(file.existsSync(), isTrue, reason: 'assets/phrases/german_phrases.json must exist');

      final content = file.readAsStringSync();
      final List<dynamic> jsonList = jsonDecode(content);

      expect(jsonList.length, greaterThanOrEqualTo(1000),
          reason: 'Must contain at least 1,000 phrases');

      final uniqueIds = <String>{};

      for (int i = 0; i < jsonList.length; i++) {
        final map = jsonList[i] as Map<String, dynamic>;
        final phrase = GermanPhrase.fromJson(map);

        expect(phrase.id, isNotEmpty, reason: 'Phrase at index $i missing id');
        expect(uniqueIds.contains(phrase.id), isFalse,
            reason: 'Duplicate id ${phrase.id} at index $i');
        uniqueIds.add(phrase.id);

        expect(phrase.german, isNotEmpty, reason: 'Phrase ${phrase.id} missing german');
        expect(phrase.english, isNotEmpty, reason: 'Phrase ${phrase.id} missing english');
        expect(phrase.category, isNotEmpty, reason: 'Phrase ${phrase.id} missing category');
        expect(phrase.level, isIn(['A1', 'A2', 'B1', 'B2']),
            reason: 'Phrase ${phrase.id} invalid level ${phrase.level}');
        expect(phrase.formality, isIn(['formal', 'informal', 'neutral']),
            reason: 'Phrase ${phrase.id} invalid formality ${phrase.formality}');
      }
    });
  });
}
