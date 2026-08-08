import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:takt/models/german_phrase.dart';
import 'package:takt/services/phrase_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('PhraseService', () {
    test('initializes and parses full catalog', () async {
      SharedPreferences.setMockInitialValues({});
      final service = PhraseService();
      await service.init();

      expect(service.isInitialized, isTrue);
      expect(service.totalCount, greaterThanOrEqualTo(1000));
      expect(service.getCategories(), isNotEmpty);
      expect(service.getLevels(), containsAll(['All', 'A1', 'A2', 'B1', 'B2']));
    });

    test('filters phrases by category and level', () async {
      SharedPreferences.setMockInitialValues({});
      final service = PhraseService();
      await service.init();

      final diningPhrases = service.filterPhrases(category: 'Restaurant & Dining');
      expect(diningPhrases, isNotEmpty);
      for (final p in diningPhrases) {
        expect(p.category, 'Restaurant & Dining');
      }

      final a1Phrases = service.filterPhrases(level: 'A1');
      expect(a1Phrases, isNotEmpty);
      for (final p in a1Phrases) {
        expect(p.level, 'A1');
      }
    });

    test('searches phrases across German text and English translation', () async {
      SharedPreferences.setMockInitialValues({});
      final service = PhraseService();
      await service.init();

      final searchByGerman = service.filterPhrases(query: 'Rest');
      expect(searchByGerman, isNotEmpty);

      final searchByEnglish = service.filterPhrases(query: 'change');
      expect(searchByEnglish, isNotEmpty);
    });

    test('toggles and persists bookmarks', () async {
      SharedPreferences.setMockInitialValues({});
      final service = PhraseService();
      await service.init();

      const phraseId = 'phr_der_rest_ist_fuer_sie';
      expect(service.isBookmarked(phraseId), isFalse);

      await service.toggleBookmark(phraseId);
      expect(service.isBookmarked(phraseId), isTrue);

      final bookmarkedOnly = service.filterPhrases(bookmarkedOnly: true);
      expect(bookmarkedOnly.any((p) => p.id == phraseId), isTrue);

      await service.toggleBookmark(phraseId);
      expect(service.isBookmarked(phraseId), isFalse);
    });

    test('generates interactive practice quiz session', () async {
      SharedPreferences.setMockInitialValues({});
      final service = PhraseService();
      await service.init();

      final exercises = service.generatePracticeSession(count: 10);
      expect(exercises.length, 10);

      for (final ex in exercises) {
        expect(ex.prompt, isNotEmpty);
        expect(ex.options.length, greaterThanOrEqualTo(2));
        expect(ex.options, contains(ex.correctAnswer));
        expect(ex.explanation, isNotEmpty);
      }
    });
  });
}
