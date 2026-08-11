import 'package:flutter_test/flutter_test.dart';
import 'package:takt/services/dictionary_service.dart';

void main() {
  group('DictionaryService.curateRelatedWords', () {
    test('caps a long raw list down to maxResults instead of showing everything', () {
      final manySynonyms = List.generate(15, (i) => 'Synonym$i');

      final curated = DictionaryService.curateRelatedWords(
        synonyms: manySynonyms,
        related: const [],
        headword: 'Auto',
        maxResults: 8,
      );

      expect(curated.length, 8);
    });

    test('prioritizes synonyms ahead of broader related terms when both exist', () {
      final curated = DictionaryService.curateRelatedWords(
        synonyms: ['Wagen', 'Kiste'],
        related: ['Straße', 'Motor', 'Garage', 'Reifen'],
        headword: 'Auto',
        maxResults: 4,
      );

      // With a cap of 4 and only 2 synonyms, all synonyms must survive the cut
      // ahead of any "related" entries.
      expect(curated.where((c) => c['type'] == 'synonym').length, 2);
      expect(curated[0]['word'], 'Wagen');
      expect(curated[1]['word'], 'Kiste');
      expect(curated.sublist(2).every((c) => c['type'] == 'related'), isTrue);
    });

    test('drops the headword itself from the related list (case-insensitive)', () {
      final curated = DictionaryService.curateRelatedWords(
        synonyms: ['auto', 'Wagen'],
        related: const [],
        headword: 'Auto',
      );

      expect(curated.map((c) => c['word']), isNot(contains('auto')));
      expect(curated.map((c) => c['word']), contains('Wagen'));
    });

    test('deduplicates case-insensitively, keeping the synonym-typed entry when duplicated', () {
      final curated = DictionaryService.curateRelatedWords(
        synonyms: ['Wagen'],
        related: ['wagen', 'Kiste'],
        headword: 'Auto',
      );

      final wagenEntries = curated.where((c) => c['word']!.toLowerCase() == 'wagen');
      expect(wagenEntries.length, 1);
      expect(wagenEntries.first['type'], 'synonym');
    });

    test('returns an empty list when there is nothing to show', () {
      final curated = DictionaryService.curateRelatedWords(
        synonyms: const [],
        related: const [],
        headword: 'Auto',
      );

      expect(curated, isEmpty);
    });

    test('ignores blank/whitespace-only entries', () {
      final curated = DictionaryService.curateRelatedWords(
        synonyms: ['', '   ', 'Wagen'],
        related: const [],
        headword: 'Auto',
      );

      expect(curated.length, 1);
      expect(curated.first['word'], 'Wagen');
    });
  });
}
