import 'package:flutter/foundation.dart';
import '../models/noun_question.dart';
import '../models/saved_word.dart';
import 'dictionary_service.dart';
import 'vocabulary_service.dart';

class GenderRuleMatch {
  final String title;
  final String conciseHint;
  final String explanation;
  final String example;
  final bool isException;
  final String? exceptionNote;
  final List<String> commonExceptions;

  GenderRuleMatch({
    required this.title,
    required this.conciseHint,
    required this.explanation,
    required this.example,
    this.isException = false,
    this.exceptionNote,
    this.commonExceptions = const [],
  });
}

class GermanGenderRules {
  static GenderRuleMatch? getRule(String word, String genderCode) {
    final cleanWord = word.trim();
    final lower = cleanWord.toLowerCase();

    // ==================== EXCEPTION DETECTION (The Odd 10%) ====================
    if (genderCode == 'm' && lower.endsWith('e') && !lower.startsWith('ge')) {
      return GenderRuleMatch(
        title: 'Exception: Noun in -e is Masculine (Der)',
        conciseHint:
            '⚠️ Exception: -$cleanWord is Masculine (Der), not Feminine',
        explanation:
            'While ~90% of nouns ending in "-e" are Feminine, "$cleanWord" is a rare Masculine exception!',
        example: 'der Käse, der Name, der Gedanke, der Junge, der Kunde',
        isException: true,
        exceptionNote:
            '90% of two-syllable nouns ending in "-e" are Feminine (Die). Masculine nouns ending in "-e" are weak N-declension nouns.',
        commonExceptions: [
          'der Käse',
          'der Name',
          'der Gedanke',
          'der Junge',
          'der Kunde',
        ],
      );
    }

    if (genderCode == 'n' && lower.endsWith('e') && !lower.startsWith('ge')) {
      return GenderRuleMatch(
        title: 'Exception: Noun in -e is Neuter (Das)',
        conciseHint: '⚠️ Exception: -$cleanWord is Neuter (Das), not Feminine',
        explanation:
            'While ~90% of nouns ending in "-e" are Feminine, "$cleanWord" is a Neuter exception!',
        example: 'das Auge, das Ende, das Erbe',
        isException: true,
        exceptionNote:
            '90% of "-e" nouns are Feminine (Die), but a few body/abstract nouns are Neuter.',
        commonExceptions: ['das Auge', 'das Ende', 'das Erbe'],
      );
    }

    if (genderCode == 'n' && lower.endsWith('er') && cleanWord.length > 3) {
      return GenderRuleMatch(
        title: 'Exception: Noun in -er is Neuter (Das)',
        conciseHint: '⚠️ Exception: -$cleanWord is Neuter (Das), not Masculine',
        explanation:
            'While ~70% of nouns ending in "-er" are Masculine, "$cleanWord" is a Neuter tool/object exception!',
        example: 'das Fenster, das Wasser, das Zimmer, das Messer, das Papier',
        isException: true,
        exceptionNote:
            'Most "-er" nouns are active Masculine agents (der Fahrer), but many inanimate household objects are Neuter.',
        commonExceptions: [
          'das Fenster',
          'das Wasser',
          'das Zimmer',
          'das Messer',
          'das Papier',
        ],
      );
    }

    if (genderCode == 'f' && lower.endsWith('er') && cleanWord.length > 3) {
      return GenderRuleMatch(
        title: 'Exception: Noun in -er is Feminine (Die)',
        conciseHint:
            '⚠️ Exception: -$cleanWord is Feminine (Die), not Masculine',
        explanation:
            'While ~70% of nouns ending in "-er" are Masculine, "$cleanWord" is a Feminine family/nature exception!',
        example: 'die Mutter, die Butter, die Tochter, die Schulter',
        isException: true,
        exceptionNote:
            'Most "-er" nouns are Masculine (Der), but female family roles and a few basic words are Feminine.',
        commonExceptions: [
          'die Mutter',
          'die Butter',
          'die Tochter',
          'die Schulter',
        ],
      );
    }

    if (genderCode == 'n' && (lower.endsWith('ent') || lower.endsWith('ant'))) {
      return GenderRuleMatch(
        title: 'Exception: Noun in -ent is Neuter (Das)',
        conciseHint: '⚠️ Exception: -$cleanWord is Neuter (Das), not Masculine',
        explanation:
            'While ~90% of "-ent" nouns are Masculine people/agents, "$cleanWord" is a Neuter exception!',
        example: 'das Talent, das Patent, das Element',
        isException: true,
        exceptionNote:
            'Masculine "-ent" nouns usually describe active male persons (der Student), whereas inanimate concepts are Neuter.',
        commonExceptions: ['das Talent', 'das Patent', 'das Element'],
      );
    }

    // ==================== DIE (Feminine) STANDARD RULES ====================
    if (genderCode == 'f') {
      if (lower.endsWith('ung')) {
        return GenderRuleMatch(
          title: 'Suffix -ung is 100% Feminine (Die)',
          conciseHint: '💡 Suffix -ung is always Feminine (Die)',
          explanation:
              'Nouns ending in "-ung" are 100% feminine with zero exceptions in German.',
          example: 'die Zeitung, die Wohnung, die Übung, die Meinung',
        );
      }
      if (lower.endsWith('heit')) {
        return GenderRuleMatch(
          title: 'Suffix -heit is 100% Feminine (Die)',
          conciseHint: '💡 Suffix -heit is always Feminine (Die)',
          explanation: 'Abstract nouns ending in "-heit" are 100% feminine.',
          example: 'die Freiheit, die Gesundheit, die Krankheit, die Wahrheit',
        );
      }
      if (lower.endsWith('keit')) {
        return GenderRuleMatch(
          title: 'Suffix -keit is 100% Feminine (Die)',
          conciseHint: '💡 Suffix -keit is always Feminine (Die)',
          explanation: 'Nouns ending in "-keit" are 100% feminine.',
          example: 'die Möglichkeit, die Eitelkeit, die Höflichkeit',
        );
      }
      if (lower.endsWith('schaft')) {
        return GenderRuleMatch(
          title: 'Suffix -schaft is 100% Feminine (Die)',
          conciseHint: '💡 Suffix -schaft is always Feminine (Die)',
          explanation:
              'Nouns ending in "-schaft" (groups & states) are 100% feminine.',
          example: 'die Freundschaft, die Mannschaft, die Landschaft',
        );
      }
      if (lower.endsWith('ei')) {
        return GenderRuleMatch(
          title: 'Suffix -ei is 100% Feminine (Die)',
          conciseHint: '💡 Suffix -ei is always Feminine (Die)',
          explanation:
              'Nouns ending in "-ei" (businesses & locations) are 100% feminine.',
          example: 'die Bäckerei, die Bücherei, die Datei',
        );
      }
      if (lower.endsWith('ion')) {
        return GenderRuleMatch(
          title: 'Suffix -ion is 100% Feminine (Die)',
          conciseHint: '💡 Suffix -ion is always Feminine (Die)',
          explanation:
              'Nouns ending in "-ion" of Latin origin are 100% feminine.',
          example: 'die Station, die Region, die Situation, die Information',
        );
      }
      if (lower.endsWith('tät') || lower.endsWith('tat')) {
        return GenderRuleMatch(
          title: 'Suffix -tät is 100% Feminine (Die)',
          conciseHint: '💡 Suffix -tät is always Feminine (Die)',
          explanation: 'Nouns ending in "-tät" are 100% feminine.',
          example: 'die Universität, die Qualität, die Realität',
        );
      }
      if (lower.endsWith('ik')) {
        return GenderRuleMatch(
          title: 'Suffix -ik is Feminine (Die)',
          conciseHint: '💡 Suffix -ik is Feminine (Die)',
          explanation:
              'Academic, artistic, and scientific subjects ending in "-ik" are feminine.',
          example: 'die Musik, die Grammatik, die Politik, die Technik',
        );
      }
      if (lower.endsWith('in') && lower.length > 3) {
        return GenderRuleMatch(
          title: 'Female Role -in is 100% Feminine (Die)',
          conciseHint: '💡 Female Role -in is Feminine (Die)',
          explanation:
              'Female professions and roles ending in "-in" are 100% feminine.',
          example: 'die Lehrerin, die Studentin, die Ärztin, die Freundin',
        );
      }
      if (lower.endsWith('anz') || lower.endsWith('enz')) {
        return GenderRuleMatch(
          title: 'Suffix -anz / -enz is Feminine (Die)',
          conciseHint: '💡 Suffix -anz / -enz is Feminine (Die)',
          explanation: 'Nouns ending in "-anz" or "-enz" are feminine.',
          example: 'die Toleranz, die Existenz, die Differenz',
        );
      }
      if (lower.endsWith('ur')) {
        return GenderRuleMatch(
          title: 'Suffix -ur is Feminine (Die)',
          conciseHint: '💡 Suffix -ur is Feminine (Die)',
          explanation: 'Nouns ending in "-ur" are feminine.',
          example: 'die Natur, die Kultur, die Struktur',
        );
      }
      if (lower.endsWith('ie')) {
        return GenderRuleMatch(
          title: 'Suffix -ie is Feminine (Die)',
          conciseHint: '💡 Suffix -ie is Feminine (Die)',
          explanation: 'Nouns ending in "-ie" are feminine.',
          example: 'die Energie, die Biologie, die Serie',
        );
      }
      if (lower.endsWith('ade') || lower.endsWith('age')) {
        return GenderRuleMatch(
          title: 'Suffix -ade / -age is Feminine (Die)',
          conciseHint: '💡 Suffix -ade / -age is Feminine (Die)',
          explanation: 'Nouns ending in "-ade" or "-age" are feminine.',
          example: 'die Schokolade, die Garage, die Passage',
        );
      }
      if (lower.endsWith('e') && !lower.startsWith('ge')) {
        return GenderRuleMatch(
          title: 'Suffix -e is ~90% Feminine (Die)',
          conciseHint: '💡 Suffix -e is ~90% Feminine (Die)',
          explanation:
              'Most two-syllable German nouns ending in "-e" are feminine.',
          example: 'die Katze, die Blume, die Sonne, die Lampe, die Tasche',
          commonExceptions: [
            'der Käse',
            'der Name',
            'der Junge',
            'das Auge',
            'das Ende',
          ],
        );
      }
    }

    // ==================== DAS (Neuter) STANDARD RULES ====================
    if (genderCode == 'n') {
      if (lower.endsWith('chen')) {
        return GenderRuleMatch(
          title: 'Diminutive -chen is 100% Neuter (Das)',
          conciseHint: '💡 Diminutive -chen is Neuter (Das)',
          explanation: 'Diminutive nouns ending in "-chen" are 100% neuter.',
          example: 'das Mädchen, das Brötchen, das Hähnchen, das Häuschen',
        );
      }
      if (lower.endsWith('lein')) {
        return GenderRuleMatch(
          title: 'Diminutive -lein is 100% Neuter (Das)',
          conciseHint: '💡 Diminutive -lein is Neuter (Das)',
          explanation: 'Diminutive nouns ending in "-lein" are 100% neuter.',
          example: 'das Fräulein, das Büchlein, das Tischlein',
        );
      }
      if (lower.endsWith('ment')) {
        return GenderRuleMatch(
          title: 'Suffix -ment is Neuter (Das)',
          conciseHint: '💡 Suffix -ment is Neuter (Das)',
          explanation: 'Nouns ending in "-ment" are neuter.',
          example: 'das Instrument, das Dokument, das Experiment, das Element',
        );
      }
      if (lower.endsWith('um')) {
        return GenderRuleMatch(
          title: 'Suffix -um is 100% Neuter (Das)',
          conciseHint: '💡 Suffix -um is Neuter (Das)',
          explanation: 'Nouns of Latin origin ending in "-um" are 100% neuter.',
          example: 'das Zentrum, das Museum, das Datum, das Studium',
        );
      }
      if (lower.endsWith('ma')) {
        return GenderRuleMatch(
          title: 'Suffix -ma is Neuter (Das)',
          conciseHint: '💡 Suffix -ma is Neuter (Das)',
          explanation: 'Nouns of Greek origin ending in "-ma" are neuter.',
          example: 'das Thema, das Drama, das Klima, das Schema',
        );
      }
      if (lower.startsWith('ge') && lower.endsWith('e')) {
        return GenderRuleMatch(
          title: 'Prefix Ge-...-e is Neuter (Das)',
          conciseHint: '💡 Prefix Ge-...-e is Neuter (Das)',
          explanation:
              'Collective nouns starting with "Ge-" and ending with "-e" are neuter.',
          example: 'das Gebäude, das Gemüse, das Gespräch, das Gebirge',
        );
      }
      if (cleanWord.length > 3 &&
          cleanWord[0] == cleanWord[0].toUpperCase() &&
          lower.endsWith('en')) {
        return GenderRuleMatch(
          title: 'Nominalized Verb (-en) is Neuter (Das)',
          conciseHint: '💡 Nominalized Verb (-en) is Neuter (Das)',
          explanation:
              'Verbs used as nouns (infinitives ending in "-en") are neuter.',
          example: 'das Essen, das Lesen, das Schwimmen, das Laufen',
        );
      }
    }

    // ==================== DER (Masculine) STANDARD RULES ====================
    if (genderCode == 'm') {
      if (lower.endsWith('ling')) {
        return GenderRuleMatch(
          title: 'Suffix -ling is 100% Masculine (Der)',
          conciseHint: '💡 Suffix -ling is Masculine (Der)',
          explanation: 'Nouns ending in "-ling" are 100% masculine.',
          example:
              'der Schmetterling, der Lehrling, der Neuling, der Schützling',
        );
      }
      if (lower.endsWith('ismus')) {
        return GenderRuleMatch(
          title: 'Suffix -ismus is 100% Masculine (Der)',
          conciseHint: '💡 Suffix -ismus is Masculine (Der)',
          explanation: 'Nouns ending in "-ismus" are 100% masculine.',
          example: 'der Optimismus, der Tourismus, der Egoismus, der Realismus',
        );
      }
      if (lower.endsWith('or')) {
        return GenderRuleMatch(
          title: 'Suffix -or is Masculine (Der)',
          conciseHint: '💡 Suffix -or is Masculine (Der)',
          explanation:
              'Nouns describing agents or machines ending in "-or" are masculine.',
          example: 'der Motor, der Faktor, der Reaktor, der Sensor',
        );
      }
      if (lower.endsWith('ist')) {
        return GenderRuleMatch(
          title: 'Suffix -ist is Masculine (Der)',
          conciseHint: '💡 Suffix -ist is Masculine (Der)',
          explanation:
              'Nouns describing active people ending in "-ist" are masculine.',
          example: 'der Polizist, der Optimist, der Journalist, der Pianist',
        );
      }
      if (lower.endsWith('ant') || lower.endsWith('ent')) {
        return GenderRuleMatch(
          title: 'Suffix -ant / -ent is Masculine (Der)',
          conciseHint: '💡 Suffix -ant / -ent is Masculine (Der)',
          explanation:
              'Nouns ending in "-ant" or "-ent" describing people are masculine.',
          example: 'der Elefant, der Student, der Lieferant, der President',
          commonExceptions: ['das Talent', 'das Patent', 'das Element'],
        );
      }
      if (lower.endsWith('er') && lower.length > 3) {
        return GenderRuleMatch(
          title: 'Agent Suffix -er is ~70% Masculine (Der)',
          conciseHint: '💡 Suffix -er is ~70% Masculine (Der)',
          explanation:
              'Nouns describing active agents or tools ending in "-er" are masculine.',
          example:
              'der Fahrer, der Computer, der Wecker, der Drucker, der Lehrer',
          commonExceptions: [
            'das Fenster',
            'das Wasser',
            'das Zimmer',
            'die Mutter',
            'die Butter',
          ],
        );
      }
    }

    return null;
  }
}

enum GenderQuizDeckMode {
  adaptiveSrs, // Priority on Due Words + offline ranked nouns matching user level
  levelA1, // Rank 1..500
  levelA2, // Rank 501..1500
  levelB1, // Rank 1501..5000
  mySavedDeck, // Saved user vocabulary
}

/// Loads gender-quiz decks (adaptive SRS + ranked-frequency + saved-vocabulary) and
/// records SM-2 spaced-repetition reviews for quizzed nouns. Extracted out of
/// [GenderPracticeScreen] so both that screen and the Daily Challenge quiz can share
/// one deck-loading/review-recording code path instead of duplicating it.
class GenderPracticeDataSource {
  final DictionaryService _dictionaryService;
  final VocabularyService _vocabularyService;

  GenderPracticeDataSource({
    DictionaryService? dictionaryService,
    VocabularyService? vocabularyService,
  })  : _dictionaryService = dictionaryService ?? DictionaryService(),
        _vocabularyService = vocabularyService ?? VocabularyService();

  Future<List<NounQuestion>> loadDeckForMode(
    GenderQuizDeckMode mode, {
    int limit = 10,
  }) async {
    List<NounQuestion> loaded;
    switch (mode) {
      case GenderQuizDeckMode.adaptiveSrs:
        loaded = await loadAdaptiveDeck(limit: limit);
        break;
      case GenderQuizDeckMode.levelA1:
        loaded = await loadRankedDeck(minRank: 1, maxRank: 500, limit: limit);
        break;
      case GenderQuizDeckMode.levelA2:
        loaded = await loadRankedDeck(minRank: 501, maxRank: 1500, limit: limit);
        break;
      case GenderQuizDeckMode.levelB1:
        loaded = await loadRankedDeck(minRank: 1501, maxRank: 5000, limit: limit);
        break;
      case GenderQuizDeckMode.mySavedDeck:
        loaded = await loadSavedDeck(limit: limit);
        break;
    }

    // Fallback if the requested deck came back empty.
    if (loaded.isEmpty) {
      loaded = await loadRankedDeck(minRank: 1, maxRank: 1500, limit: limit);
    }
    return loaded;
  }

  Future<List<NounQuestion>> loadAdaptiveDeck({int limit = 10}) async {
    List<NounQuestion> loaded = [];

    // 1. Due Spaced Repetition Nouns
    try {
      final dueWords = await _vocabularyService.getDueWords();
      if (dueWords.isNotEmpty) {
        final dueStrings = dueWords.map((w) => w.germanWord).toList();
        final genderMap = await _dictionaryService.getGendersForWords(dueStrings);
        for (var dw in dueWords) {
          final gRaw = dw.gender ?? genderMap[dw.germanWord];
          if (gRaw == null) continue;
          final code = NounQuestion.normalizeGender(gRaw);
          if (code == null) continue;
          loaded.add(
            NounQuestion(
              word: dw.germanWord,
              genderCode: code,
              translation: dw.primaryDefinition,
              isDueForSrs: true,
              srsInterval: dw.interval,
            ),
          );
          if (loaded.length >= limit) break;
        }
      }
    } catch (e) {
      debugPrint("Error fetching due SRS words: $e");
    }

    // 2. Fill remainder with ranked offline dictionary nouns
    if (loaded.length < limit) {
      try {
        int needed = limit - loaded.length;
        final rankedNouns = await _dictionaryService.getRankedNouns(
          minRank: 1,
          maxRank: 1500,
          limit: needed * 2,
          randomize: true,
        );
        for (var row in rankedNouns) {
          final word = row['word'] as String?;
          final gRaw = row['gender'] as String?;
          final def = row['definition'] as String? ?? 'German noun';
          final ipa = row['ipa'] as String?;
          final rank = row['freq_rank'] as int?;

          final code = NounQuestion.normalizeGender(gRaw);
          if (word != null &&
              gRaw != null &&
              code != null &&
              !_dictionaryService.isGrammaticalJargon(def) &&
              !loaded.any((q) => q.word.toLowerCase() == word.toLowerCase())) {
            final wordId = row['id'] as int?;
            String? pluralForm;
            if (wordId != null) {
              pluralForm = await _dictionaryService.getPluralForm(wordId, word);
            }
            loaded.add(
              NounQuestion(
                word: word,
                genderCode: code,
                ipa: ipa,
                translation: def,
                plural: pluralForm,
                freqRank: rank,
              ),
            );
            if (loaded.length >= limit) break;
          }
        }
      } catch (e) {
        debugPrint("Error fetching adaptive ranked nouns: $e");
      }
    }

    return loaded;
  }

  Future<List<NounQuestion>> loadRankedDeck({
    required int minRank,
    required int maxRank,
    required int limit,
  }) async {
    List<NounQuestion> list = [];
    try {
      final rows = await _dictionaryService.getRankedNouns(
        minRank: minRank,
        maxRank: maxRank,
        limit: limit * 2,
        randomize: true,
      );
      for (var row in rows) {
        final word = row['word'] as String?;
        final gRaw = row['gender'] as String?;
        final def = row['definition'] as String? ?? 'German noun';
        final ipa = row['ipa'] as String?;
        final rank = row['freq_rank'] as int?;

        final code = NounQuestion.normalizeGender(gRaw);
        if (word != null &&
            gRaw != null &&
            code != null &&
            !_dictionaryService.isGrammaticalJargon(def) &&
            !list.any((q) => q.word.toLowerCase() == word.toLowerCase())) {
          final wordId = row['id'] as int?;
          String? pluralForm;
          if (wordId != null) {
            pluralForm = await _dictionaryService.getPluralForm(wordId, word);
          }
          list.add(
            NounQuestion(
              word: word,
              genderCode: code,
              ipa: ipa,
              translation: def,
              plural: pluralForm,
              freqRank: rank,
            ),
          );
          if (list.length >= limit) break;
        }
      }
    } catch (e) {
      debugPrint("Error loading ranked deck [$minRank-$maxRank]: $e");
    }
    return list;
  }

  Future<List<NounQuestion>> loadSavedDeck({required int limit}) async {
    List<NounQuestion> list = [];
    try {
      final savedWords = await _vocabularyService.getSavedWords();
      if (savedWords.isNotEmpty) {
        final savedStrings = savedWords.map((w) => w.germanWord).toList();
        final genderMap = await _dictionaryService.getGendersForWords(savedStrings);
        for (var sw in savedWords) {
          final gRaw = sw.gender ?? genderMap[sw.germanWord];
          if (gRaw == null) continue;
          final code = NounQuestion.normalizeGender(gRaw);
          if (code == null) continue;
          if (!list.any((q) => q.word.toLowerCase() == sw.germanWord.toLowerCase())) {
            list.add(
              NounQuestion(
                word: sw.germanWord,
                genderCode: code,
                translation: sw.primaryDefinition,
                isDueForSrs: sw.isDue,
                srsInterval: sw.interval,
              ),
            );
            if (list.length >= limit) break;
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading saved deck: $e");
    }
    return list;
  }

  /// Records an SM-2 review for [question], creating a [SavedWord] first if the
  /// noun isn't already tracked. [streakForEasyRating] lets the caller decide when
  /// a correct answer counts as "easy" vs. "good" (the standalone gender screen
  /// uses its own answer-streak; a mixed quiz session may pass a different signal).
  Future<void> recordSrsReview(
    NounQuestion question,
    bool isCorrect, {
    required bool countsAsEasy,
  }) async {
    try {
      final wordId = question.word.toLowerCase().trim();
      final existing = await _vocabularyService.getSavedWordByWord(question.word);

      if (existing == null) {
        final newWord = SavedWord(
          id: wordId,
          word: question.word,
          gender: question.genderCode,
          primaryDefinition: question.translation,
          category: VocabCategory.learning,
        );
        await _vocabularyService.upsertWord(newWord, notify: false);
      }

      final ReviewRating rating = isCorrect
          ? (countsAsEasy ? ReviewRating.easy : ReviewRating.good)
          : ReviewRating.again;

      await _vocabularyService.recordReview(wordId, rating);
    } catch (e) {
      debugPrint("Error recording SRS review: $e");
    }
  }
}
