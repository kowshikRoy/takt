import 'dart:math';
import '../models/daily_challenge_question.dart';
import '../models/saved_word.dart';
import 'compound_service.dart';
import 'gender_practice_data_source.dart';
import 'sentence_practice_service.dart';
import 'vocabulary_service.dart';

/// Builds a single "Daily Challenge" session by pulling questions from the app's
/// existing practice modules (vocabulary SRS, gender quiz, compound words, sentence-
/// case grammar) instead of requiring the user to visit four separate screens. Reuses
/// each module's own question-generation logic rather than reimplementing it.
class DailyChallengeService {
  final VocabularyService _vocabularyService;
  final GenderPracticeDataSource _genderDataSource;
  final CompoundService _compoundService;
  final SentencePracticeService _sentenceService;
  final Random _random;

  /// Below this many saved words there usually aren't enough distinct definitions to
  /// build real multiple-choice distractors, so the vocab slice is omitted entirely
  /// rather than degrading to a 1-2 option "quiz" — matches the existing "Daily
  /// Review unlocks at 5 words" gate used elsewhere in the app.
  static const int minSavedWordsForVocabSlice = 5;

  DailyChallengeService({
    VocabularyService? vocabularyService,
    GenderPracticeDataSource? genderDataSource,
    CompoundService? compoundService,
    SentencePracticeService? sentenceService,
    Random? random,
  })  : _vocabularyService = vocabularyService ?? VocabularyService(),
        _genderDataSource = genderDataSource ?? GenderPracticeDataSource(),
        _compoundService = compoundService ?? CompoundService(),
        _sentenceService = sentenceService ?? SentencePracticeService(),
        _random = random ?? Random();

  /// Composes one mixed-type session. Default quota is 4 vocab / 2 gender / 2
  /// compound / 2 sentence (targetSize 10); when the vocab or gender slice has
  /// nothing to offer (new user, nothing due), those slots are redistributed to the
  /// non-personalized compound/sentence slices instead of shipping a short session.
  Future<List<DailyChallengeQuestion>> buildSession({int targetSize = 10}) async {
    final vocabQuota = (targetSize * 0.4).round();
    final genderQuota = (targetSize * 0.2).round();
    final compoundQuota = (targetSize * 0.2).round();
    final sentenceQuota = targetSize - vocabQuota - genderQuota - compoundQuota;

    final vocabQuestions = await _buildVocabSlice(vocabQuota);
    final genderQuestions = await _buildGenderSlice(genderQuota);

    // Redistribute any unmet vocab/gender quota to compound+sentence, which don't
    // depend on the user having saved words or due reviews.
    final shortfall = (vocabQuota - vocabQuestions.length) + (genderQuota - genderQuestions.length);
    final extraForCompound = (shortfall / 2).ceil();
    final extraForSentence = shortfall - extraForCompound;

    final compoundQuestions = await _buildCompoundSlice(compoundQuota + extraForCompound);
    final sentenceQuestions = _buildSentenceSlice(sentenceQuota + extraForSentence);

    final all = [
      ...vocabQuestions,
      ...genderQuestions,
      ...compoundQuestions,
      ...sentenceQuestions,
    ]..shuffle(_random);

    return all;
  }

  Future<List<VocabDefinitionQuestion>> _buildVocabSlice(int quota) async {
    if (quota <= 0) return [];

    // Query fresh from the DB rather than VocabularyService's in-memory cache — that
    // cache is only populated after a `notify: true` write elsewhere, so relying on it
    // here could silently see zero saved words even when plenty exist, inconsistent
    // with getDueWords() below (which is always DB-backed and fresh).
    final allSavedWords = await _vocabularyService.getSavedWords();
    if (allSavedWords.length < minSavedWordsForVocabSlice) return [];

    final dueWords = await _vocabularyService.getDueWords();
    if (dueWords.isEmpty) return [];

    // Favor struggling (low-mastery) words first; getDueWords() already returns
    // most-overdue-first with same-day shuffling, so a stable sort here keeps that
    // ordering as the tiebreak within each mastery level.
    final sorted = List<SavedWord>.from(dueWords)
      ..sort((a, b) => a.masteryLevel.compareTo(b.masteryLevel));
    final selected = sorted.take(quota).toList();

    final questions = <VocabDefinitionQuestion>[];
    for (final word in selected) {
      final correct = word.primaryDefinition;
      final distractorPool = allSavedWords
          .where((w) => w.id != word.id && w.primaryDefinition.trim().isNotEmpty && w.primaryDefinition != correct)
          .map((w) => w.primaryDefinition)
          .toSet()
          .toList()
        ..shuffle(_random);

      if (distractorPool.length < 3) continue; // not enough distinct distractors for this word

      final options = [correct, ...distractorPool.take(3)]..shuffle(_random);
      questions.add(VocabDefinitionQuestion(
        id: 'vocab_${word.id}',
        word: word,
        options: options,
        correctOption: correct,
      ));
    }
    return questions;
  }

  Future<List<GenderQuestion>> _buildGenderSlice(int quota) async {
    if (quota <= 0) return [];
    final nouns = await _genderDataSource.loadAdaptiveDeck(limit: quota);
    return nouns
        .take(quota)
        .map((n) => GenderQuestion(id: 'gender_${n.word}', noun: n))
        .toList();
  }

  Future<List<CompoundQuestion>> _buildCompoundSlice(int quota) async {
    if (quota <= 0) return [];
    await _compoundService.loadAssetCompounds();

    final questions = <CompoundQuestion>[];
    final usedWords = <String>{};
    // Bounded attempts since getRandomWord() can repeat by chance on a small pool.
    final maxAttempts = quota * 5;
    var attempts = 0;
    while (questions.length < quota && attempts < maxAttempts) {
      attempts++;
      final compound = _compoundService.getRandomWord();
      if (usedWords.contains(compound.fullWord)) continue;
      usedWords.add(compound.fullWord);

      final distractors = _compoundService.getDistractors(compound.fullMeaning, 3);
      if (distractors.length < 3) continue;

      final options = [compound.fullMeaning, ...distractors]..shuffle(_random);
      questions.add(CompoundQuestion(
        id: 'compound_${compound.fullWord}',
        compound: compound,
        options: options,
      ));
    }
    return questions;
  }

  List<SentenceCaseQuestion> _buildSentenceSlice(int quota) {
    if (quota <= 0) return [];
    final exercises = _sentenceService.getExercises()..shuffle(_random);
    return exercises
        .take(quota)
        .map((e) => SentenceCaseQuestion(id: 'sentence_${e.id}', exercise: e))
        .toList();
  }
}
