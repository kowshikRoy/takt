import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/german_phrase.dart';
import '../models/saved_word.dart';
import 'app_logger.dart';
import 'vocabulary_service.dart';

class PhraseService extends ChangeNotifier {
  static final PhraseService _instance = PhraseService._internal();
  factory PhraseService() => _instance;
  PhraseService._internal();

  static const String _bookmarkedKey = 'takt_bookmarked_phrases_v1';
  static const String _masteredKey = 'takt_mastered_phrases_v1';

  List<GermanPhrase> _phrases = [];
  Set<String> _bookmarkedIds = {};
  Set<String> _masteredIds = {};
  bool _isInitialized = false;
  bool _isLoading = false;

  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  List<GermanPhrase> get allPhrases => List.unmodifiable(_phrases);
  Set<String> get bookmarkedIds => Set.unmodifiable(_bookmarkedIds);
  Set<String> get masteredIds => Set.unmodifiable(_masteredIds);
  int get totalCount => _phrases.length;

  Future<void> init() async {
    if (_isInitialized) return;
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _bookmarkedIds = (prefs.getStringList(_bookmarkedKey) ?? []).toSet();
      _masteredIds = (prefs.getStringList(_masteredKey) ?? []).toSet();

      final jsonString = await rootBundle.loadString(
        'assets/phrases/german_phrases.json',
      );
      final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
      _phrases = jsonList
          .map((e) => GermanPhrase.fromJson(e as Map<String, dynamic>))
          .toList();

      _isInitialized = true;
    } catch (e, st) {
      AppLogger.error(
        "Failed to initialize PhraseService",
        error: e,
        stackTrace: st,
        tag: 'PhraseService',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<GermanPhrase>> getPhrases() async {
    if (!_isInitialized) {
      await init();
    }
    return _phrases;
  }

  GermanPhrase? getPhraseById(String id) {
    try {
      return _phrases.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  List<String> getCategories() {
    final categories = <String>{};
    for (final p in _phrases) {
      categories.add(p.category);
    }
    // Ordered categories for clean UI presentation
    final standardOrder = [
      'Restaurant & Dining',
      'Everyday Small Talk & Social',
      'Shopping & Errands',
      'Travel, Transit & Directions',
      'Work, Office & Routine',
      'Idioms & Figurative Sayings',
      'Politeness, Reactions & Feelings',
    ];

    final result = <String>[];
    for (final cat in standardOrder) {
      if (categories.contains(cat)) {
        result.add(cat);
      }
    }
    for (final cat in categories) {
      if (!result.contains(cat)) {
        result.add(cat);
      }
    }
    return result;
  }

  List<String> getLevels() => const ['All', 'A1', 'A2', 'B1', 'B2'];

  /// Filters phrases with sub-millisecond multi-attribute search
  List<GermanPhrase> filterPhrases({
    String? category,
    String? level,
    String? formality,
    String? query,
    bool bookmarkedOnly = false,
  }) {
    final cleanQuery = _normalize(query ?? '');

    return _phrases.where((p) {
      if (category != null &&
          category.isNotEmpty &&
          category != 'All' &&
          p.category != category) {
        return false;
      }

      if (level != null &&
          level.isNotEmpty &&
          level != 'All' &&
          p.level.toUpperCase() != level.toUpperCase()) {
        return false;
      }

      if (formality != null &&
          formality.isNotEmpty &&
          formality != 'All' &&
          p.formality != formality) {
        return false;
      }

      if (bookmarkedOnly && !_bookmarkedIds.contains(p.id)) {
        return false;
      }

      if (cleanQuery.isNotEmpty) {
        final ger = _normalize(p.german);
        final eng = _normalize(p.english);
        final lit = _normalize(p.literalTranslation);
        final sit = _normalize(p.situation);
        final tags = p.tags.map(_normalize).join(' ');

        final matches = ger.contains(cleanQuery) ||
            eng.contains(cleanQuery) ||
            lit.contains(cleanQuery) ||
            sit.contains(cleanQuery) ||
            tags.contains(cleanQuery);

        if (!matches) return false;
      }

      return true;
    }).toList();
  }

  bool isBookmarked(String phraseId) => _bookmarkedIds.contains(phraseId);

  Future<void> toggleBookmark(String phraseId) async {
    if (_bookmarkedIds.contains(phraseId)) {
      _bookmarkedIds.remove(phraseId);
    } else {
      _bookmarkedIds.add(phraseId);
    }
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_bookmarkedKey, _bookmarkedIds.toList());
    } catch (e) {
      AppLogger.error(
        "Failed to save bookmarked phrases",
        error: e,
        tag: 'PhraseService',
      );
    }
  }

  bool isMastered(String phraseId) => _masteredIds.contains(phraseId);

  Future<void> toggleMastered(String phraseId) async {
    if (_masteredIds.contains(phraseId)) {
      _masteredIds.remove(phraseId);
    } else {
      _masteredIds.add(phraseId);
    }
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_masteredKey, _masteredIds.toList());
    } catch (e) {
      AppLogger.error(
        "Failed to save mastered phrases",
        error: e,
        tag: 'PhraseService',
      );
    }
  }

  /// Bridges a GermanPhrase into the user's personal Spaced Repetition (SRS) deck
  Future<bool> savePhraseToVocabulary(
    GermanPhrase phrase,
    BuildContext context,
  ) async {
    try {
      final vocabService =
          Provider.of<VocabularyService>(context, listen: false);

      final dialogueSentence = phrase.dialogue != null
          ? "${phrase.dialogue!.speakerA} -> ${phrase.dialogue!.speakerB}"
          : phrase.german;

      final savedWord = SavedWord(
        id: phrase.id,
        word: phrase.german,
        baseForm: phrase.german,
        pos: 'phrase',
        primaryDefinition: phrase.english,
        definitions: [
          phrase.english,
          if (phrase.literalTranslation.isNotEmpty)
            "Literal: ${phrase.literalTranslation}",
          if (phrase.culturalNote.isNotEmpty)
            "Note: ${phrase.culturalNote}",
        ],
        contextSentence: dialogueSentence,
        sourceTitle: "Everyday Phrases: ${phrase.category}",
      );

      await vocabService.upsertWord(savedWord);
      return true;
    } catch (e, st) {
      AppLogger.error(
        "Failed to save phrase to SRS vocabulary",
        error: e,
        stackTrace: st,
        tag: 'PhraseService',
      );
      return false;
    }
  }

  /// Generates a randomized interactive quiz session
  List<PhraseExercise> generatePracticeSession({
    int count = 10,
    String? category,
    String? level,
  }) {
    final pool = filterPhrases(
      category: category,
      level: level,
    );

    if (pool.isEmpty) return [];

    final random = Random();
    final shuffled = List<GermanPhrase>.from(pool)..shuffle(random);
    final selected = shuffled.take(count).toList();

    final exercises = <PhraseExercise>[];

    for (int i = 0; i < selected.length; i++) {
      final target = selected[i];
      final exerciseType = _determineExerciseType(target, i);

      // Generate 3 plausible distractors from the pool or overall catalog
      final distractors = _getDistractors(target, pool, 3, exerciseType);

      switch (exerciseType) {
        case PhraseExerciseType.situationalChoice:
          final options = [...distractors, target.german]..shuffle(random);
          exercises.add(PhraseExercise(
            id: 'ex_${target.id}_$i',
            type: PhraseExerciseType.situationalChoice,
            targetPhrase: target,
            prompt: target.situation.isNotEmpty
                ? target.situation
                : "You want to say '${target.english}'. What do you say?",
            options: options,
            correctAnswer: target.german,
            explanation:
                "\"${target.german}\" means \"${target.english}\". ${target.culturalNote}",
          ));
          break;

        case PhraseExerciseType.dialogueCompletion:
          if (target.dialogue != null &&
              target.dialogue!.speakerA.isNotEmpty &&
              target.dialogue!.speakerB.isNotEmpty) {
            final options = [...distractors, target.dialogue!.speakerB]
              ..shuffle(random);
            exercises.add(PhraseExercise(
              id: 'ex_${target.id}_$i',
              type: PhraseExerciseType.dialogueCompletion,
              targetPhrase: target,
              prompt: "Complete the dialogue appropriately:",
              speakerContext: "Person A: \"${target.dialogue!.speakerA}\"",
              options: options,
              correctAnswer: target.dialogue!.speakerB,
              explanation:
                  "Reply: \"${target.dialogue!.speakerB}\" (${target.dialogue!.englishB}).",
            ));
          } else {
            final options = [...distractors, target.english]..shuffle(random);
            exercises.add(PhraseExercise(
              id: 'ex_${target.id}_$i',
              type: PhraseExerciseType.situationalChoice,
              targetPhrase: target,
              prompt: "What is the meaning of: \"${target.german}\"?",
              options: options,
              correctAnswer: target.english,
              explanation:
                  "\"${target.german}\" translates to \"${target.english}\".",
            ));
          }
          break;

        case PhraseExerciseType.audioListening:
          final options = [...distractors, target.english]..shuffle(random);
          exercises.add(PhraseExercise(
            id: 'ex_${target.id}_$i',
            type: PhraseExerciseType.audioListening,
            targetPhrase: target,
            prompt: "Listen to the spoken German phrase and choose the meaning:",
            options: options,
            correctAnswer: target.english,
            explanation:
                "Spoken: \"${target.german}\" = \"${target.english}\".",
          ));
          break;
      }
    }

    return exercises;
  }

  PhraseExerciseType _determineExerciseType(GermanPhrase target, int index) {
    if (target.dialogue != null && index % 3 == 1) {
      return PhraseExerciseType.dialogueCompletion;
    } else if (index % 3 == 2) {
      return PhraseExerciseType.audioListening;
    }
    return PhraseExerciseType.situationalChoice;
  }

  List<String> _getDistractors(
    GermanPhrase target,
    List<GermanPhrase> candidatePool,
    int count,
    PhraseExerciseType type,
  ) {
    final list = <String>[];
    final random = Random();
    final shuffledPool = List<GermanPhrase>.from(_phrases)..shuffle(random);

    for (final p in shuffledPool) {
      if (p.id == target.id) continue;

      String option;
      if (type == PhraseExerciseType.situationalChoice) {
        option = p.german;
      } else if (type == PhraseExerciseType.dialogueCompletion &&
          p.dialogue != null &&
          p.dialogue!.speakerB.isNotEmpty) {
        option = p.dialogue!.speakerB;
      } else {
        option = p.english;
      }

      if (option.isNotEmpty && !list.contains(option)) {
        list.add(option);
      }

      if (list.length >= count) break;
    }

    return list;
  }

  String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll('ä', 'ae')
        .replaceAll('ö', 'oe')
        .replaceAll('ü', 'ue')
        .replaceAll('ß', 'ss')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .trim();
  }
}
