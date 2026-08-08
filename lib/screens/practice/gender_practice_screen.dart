import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../services/dictionary_service.dart';
import '../../services/vocabulary_service.dart';
import '../../services/tts_service.dart';
import '../../services/sound_service.dart';
import '../../models/saved_word.dart';
import '../../widgets/capped_width.dart';
import 'gender_rules_guide_screen.dart';

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

class NounQuestion {
  final String word;
  final String genderCode; // 'm', 'f', 'n'
  final String? ipa;
  final String translation;
  final String? plural;
  final int? freqRank;
  final bool isDueForSrs;
  final int srsInterval;

  NounQuestion({
    required this.word,
    required this.genderCode,
    this.ipa,
    required this.translation,
    this.plural,
    this.freqRank,
    this.isDueForSrs = false,
    this.srsInterval = 0,
  });

  String get article {
    switch (genderCode) {
      case 'm':
        return 'der';
      case 'f':
        return 'die';
      case 'n':
        return 'das';
      default:
        return 'der';
    }
  }

  static String? normalizeGender(String? raw) {
    if (raw == null) return null;
    final g = raw.trim().toLowerCase();
    if (g == 'm' ||
        g == 'der' ||
        g.startsWith('masc') ||
        g.startsWith('mask') ||
        g == 'm.' ||
        g == 'r') {
      return 'm';
    }
    if (g == 'f' ||
        g == 'die' ||
        g.startsWith('fem') ||
        g == 'f.' ||
        g == 'e') {
      return 'f';
    }
    if (g == 'n' ||
        g == 'das' ||
        g.startsWith('neu') ||
        g == 'n.' ||
        g == 's') {
      return 'n';
    }
    return null;
  }
}

class GenderPracticeScreen extends StatefulWidget {
  const GenderPracticeScreen({super.key});

  @override
  State<GenderPracticeScreen> createState() => _GenderPracticeScreenState();
}

class _GenderPracticeScreenState extends State<GenderPracticeScreen> {
  final DictionaryService _dictionaryService = DictionaryService();
  final VocabularyService _vocabularyService = VocabularyService();
  final TtsService _ttsService = TtsService();

  GenderQuizDeckMode _selectedDeckMode = GenderQuizDeckMode.adaptiveSrs;
  List<NounQuestion> _questions = [];
  bool _isLoading = true;
  int _currentIndex = 0;
  int _score = 0;
  int _streak = 0;
  int _bestStreak = 0;
  String? _selectedGender; // 'm', 'f', 'n'
  bool _isAnswered = false;
  bool _isFinished = false;

  int _originalDeckSize = 0;
  final Set<String> _firstAttemptCorrectWords = {};
  final Set<String> _firstAttemptFailedWords = {};

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() {
      _isLoading = true;
      _questions = [];
      _currentIndex = 0;
      _score = 0;
      _streak = 0;
      _bestStreak = 0;
      _selectedGender = null;
      _isAnswered = false;
      _isFinished = false;
      _firstAttemptCorrectWords.clear();
      _firstAttemptFailedWords.clear();
    });

    List<NounQuestion> loaded = [];

    if (_selectedDeckMode == GenderQuizDeckMode.adaptiveSrs) {
      // 1. Due Spaced Repetition Nouns
      try {
        final dueWords = await _vocabularyService.getDueWords();
        if (dueWords.isNotEmpty) {
          final dueStrings = dueWords.map((w) => w.germanWord).toList();
          final genderMap = await _dictionaryService.getGendersForWords(
            dueStrings,
          );
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
          }
        }
      } catch (e) {
        debugPrint("Error fetching due SRS words: $e");
      }

      // 2. Fill remainder with ranked offline dictionary nouns
      if (loaded.length < 10) {
        try {
          int needed = 10 - loaded.length;
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
                !loaded.any(
                  (q) => q.word.toLowerCase() == word.toLowerCase(),
                )) {
              final wordId = row['id'] as int?;
              String? pluralForm;
              if (wordId != null) {
                pluralForm = await _dictionaryService.getPluralForm(
                  wordId,
                  word,
                );
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
              if (loaded.length >= 10) break;
            }
          }
        } catch (e) {
          debugPrint("Error fetching adaptive ranked nouns: $e");
        }
      }
    } else if (_selectedDeckMode == GenderQuizDeckMode.levelA1) {
      loaded = await _loadRankedDeck(minRank: 1, maxRank: 500, limit: 10);
    } else if (_selectedDeckMode == GenderQuizDeckMode.levelA2) {
      loaded = await _loadRankedDeck(minRank: 501, maxRank: 1500, limit: 10);
    } else if (_selectedDeckMode == GenderQuizDeckMode.levelB1) {
      loaded = await _loadRankedDeck(minRank: 1501, maxRank: 5000, limit: 10);
    } else if (_selectedDeckMode == GenderQuizDeckMode.mySavedDeck) {
      loaded = await _loadSavedDeck(limit: 10);
    }

    // Fallback if loaded deck is empty
    if (loaded.isEmpty) {
      loaded = await _loadRankedDeck(minRank: 1, maxRank: 1500, limit: 10);
    }

    _originalDeckSize = loaded.length;

    if (mounted) {
      setState(() {
        _questions = loaded;
        _isLoading = false;
      });
    }
  }

  Future<List<NounQuestion>> _loadRankedDeck({
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

  Future<List<NounQuestion>> _loadSavedDeck({required int limit}) async {
    List<NounQuestion> list = [];
    try {
      final savedWords = await _vocabularyService.getSavedWords();
      if (savedWords.isNotEmpty) {
        final savedStrings = savedWords.map((w) => w.germanWord).toList();
        final genderMap = await _dictionaryService.getGendersForWords(
          savedStrings,
        );
        for (var sw in savedWords) {
          final gRaw = sw.gender ?? genderMap[sw.germanWord];
          if (gRaw == null) continue;
          final code = NounQuestion.normalizeGender(gRaw);
          if (code == null) continue;
          if (!list.any(
            (q) => q.word.toLowerCase() == sw.germanWord.toLowerCase(),
          )) {
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

  void _handleSelectGender(String code) {
    if (_isAnswered || _currentIndex >= _questions.length) return;

    final current = _questions[_currentIndex];
    final bool isCorrect = (code == current.genderCode);
    final rule = GermanGenderRules.getRule(current.word, current.genderCode);

    final bool isFirstAttempt =
        !_firstAttemptCorrectWords.contains(current.word) &&
        !_firstAttemptFailedWords.contains(current.word);

    setState(() {
      _selectedGender = code;
      _isAnswered = true;
      if (isCorrect) {
        if (isFirstAttempt) {
          _score++;
          _firstAttemptCorrectWords.add(current.word);
        }
        _streak++;
        if (_streak > _bestStreak) _bestStreak = _streak;
      } else {
        if (isFirstAttempt) {
          _firstAttemptFailedWords.add(current.word);
        }
        _streak = 0;

        // Active Learning: Re-queue missed question at end of session deck
        _questions.add(
          NounQuestion(
            word: current.word,
            genderCode: current.genderCode,
            ipa: current.ipa,
            translation: current.translation,
            plural: current.plural,
            freqRank: current.freqRank,
            isDueForSrs: current.isDueForSrs,
            srsInterval: current.srsInterval,
          ),
        );
      }
    });

    // Record SM-2 Spaced Repetition Review
    _recordSrsReview(current, isCorrect);

    if (isCorrect) {
      SoundService().playCorrect();
    } else {
      SoundService().playIncorrect();
    }

    // Speak German article + noun + plural (e.g. "das Haus, die Häuser"),
    // then (if correct) auto-advance once that finishes speaking rather
    // than guessing a fixed delay — a plain delay had no relation to the
    // actual audio length, so plurals/longer words often got cut off
    // mid-pronunciation by the auto-advance.
    final String spokenText = _getSpokenText(current);
    if (isCorrect) {
      final int bufferMs = rule != null ? 1200 : 600;
      _speakThenAutoAdvance(spokenText, bufferMs);
    } else {
      _ttsService.speak(spokenText, lang: 'de-DE');
    }
  }

  /// Speaks [text] and waits for TtsService to report completion before
  /// advancing, plus [bufferMs] of extra reaction/reading time on top —
  /// so the next question never appears before the pronunciation (or, when
  /// a grammar-rule hint is shown, the hint) has actually been heard/read.
  /// Falls back to a timeout in case the completion event never fires
  /// (e.g. TTS unavailable) so auto-advance can't hang indefinitely.
  Future<void> _speakThenAutoAdvance(String text, int bufferMs) async {
    final completionSignal = _ttsService.progressStream
        .firstWhere((event) => event == null)
        .timeout(const Duration(seconds: 6), onTimeout: () => null);
    await _ttsService.speak(text, lang: 'de-DE');
    await completionSignal;
    await Future.delayed(Duration(milliseconds: bufferMs));
    if (mounted && _isAnswered) _nextQuestion();
  }

  String _getSpokenText(NounQuestion question) {
    final article = question.article.trim();
    final word = question.word.trim();
    final plural = question.plural?.trim();

    if (plural == null || plural.isEmpty) {
      return '$article $word';
    }

    String cleanPlural = plural;
    if (!cleanPlural.toLowerCase().startsWith('die ')) {
      cleanPlural = 'die $cleanPlural';
    }

    return '$article $word, $cleanPlural';
  }

  Future<void> _recordSrsReview(NounQuestion question, bool isCorrect) async {
    try {
      final wordId = question.word.toLowerCase().trim();
      final existing = await _vocabularyService.getSavedWordByWord(
        question.word,
      );

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
          ? (_streak >= 3 ? ReviewRating.easy : ReviewRating.good)
          : ReviewRating.again;

      await _vocabularyService.recordReview(wordId, rating);
    } catch (e) {
      debugPrint("Error recording SRS review: $e");
    }
  }

  void _nextQuestion() {
    if (_currentIndex + 1 < _questions.length) {
      setState(() {
        _currentIndex++;
        _selectedGender = null;
        _isAnswered = false;
      });
    } else {
      setState(() {
        _isFinished = true;
      });
    }
  }

  void _showModeSelectionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).dividerColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Select Vocabulary Deck',
                style: Theme.of(
                  ctx,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose noun level or deck for practice',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              _buildModeOption(
                ctx,
                mode: GenderQuizDeckMode.adaptiveSrs,
                title: 'Adaptive Deck',
                subtitle: 'Due words + frequency-ranked dictionary nouns',
                icon: Icons.auto_awesome_rounded,
              ),
              _buildModeOption(
                ctx,
                mode: GenderQuizDeckMode.levelA1,
                title: 'Beginner (A1) - Top 500',
                subtitle: 'Essential everyday German nouns (Haus, Tag, Frau)',
                icon: Icons.filter_1_rounded,
              ),
              _buildModeOption(
                ctx,
                mode: GenderQuizDeckMode.levelA2,
                title: 'Core (A2) - Top 1500',
                subtitle: 'Core practical vocabulary (Wohnung, Schlüssel)',
                icon: Icons.filter_2_rounded,
              ),
              _buildModeOption(
                ctx,
                mode: GenderQuizDeckMode.levelB1,
                title: 'Intermediate (B1/B2) - Top 5000',
                subtitle: 'Advanced topics & abstract concepts',
                icon: Icons.filter_3_rounded,
              ),
              _buildModeOption(
                ctx,
                mode: GenderQuizDeckMode.mySavedDeck,
                title: 'My Study Deck',
                subtitle: 'Practice words you added while reading & listening',
                icon: Icons.style_rounded,
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModeOption(
    BuildContext ctx, {
    required GenderQuizDeckMode mode,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final bool isSelected = _selectedDeckMode == mode;
    final colorScheme = Theme.of(ctx).colorScheme;
    final activeColor = colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? activeColor.withValues(alpha: 0.08)
            : Theme.of(ctx).cardColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isSelected
              ? activeColor
              : colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: ListTile(
        onTap: () {
          Navigator.pop(ctx);
          if (_selectedDeckMode != mode) {
            setState(() {
              _selectedDeckMode = mode;
            });
            _loadQuestions();
          }
        },
        leading: CircleAvatar(
          backgroundColor: isSelected
              ? activeColor.withValues(alpha: 0.15)
              : colorScheme.surfaceContainerHighest,
          child: Icon(
            icon,
            color: isSelected ? activeColor : colorScheme.onSurfaceVariant,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
        trailing: isSelected
            ? Icon(Icons.check_circle_rounded, color: activeColor)
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: CappedWidth(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _questions.isEmpty
              ? _buildEmptyState()
              : _isFinished
              ? _buildCompletionSummary()
              : _buildQuizBody(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.help_outline_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No Nouns Available',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Could not find nouns for the selected deck mode.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showModeSelectionSheet,
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('Change Deck Mode'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizBody() {
    final current = _questions[_currentIndex];
    final progress = (_currentIndex + 1) / _questions.length;
    final rule = _isAnswered
        ? GermanGenderRules.getRule(current.word, current.genderCode)
        : null;

    String modeLabel = 'Adaptive Deck';
    if (_selectedDeckMode == GenderQuizDeckMode.levelA1)
      modeLabel = 'A1 (Top 500)';
    if (_selectedDeckMode == GenderQuizDeckMode.levelA2)
      modeLabel = 'A2 (Top 1500)';
    if (_selectedDeckMode == GenderQuizDeckMode.levelB1)
      modeLabel = 'B1 (Top 5000)';
    if (_selectedDeckMode == GenderQuizDeckMode.mySavedDeck)
      modeLabel = 'Saved Deck';

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              ),
              InkWell(
                onTap: _showModeSelectionSheet,
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        modeLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.menu_book_rounded),
                tooltip: 'Suffix & Rule Guide',
                color: Theme.of(context).colorScheme.primary,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const GenderRulesGuideScreen(),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Theme.of(
                        context,
                      ).dividerColor.withValues(alpha: 0.3),
                      color: Theme.of(context).colorScheme.primary,
                      minHeight: 8,
                    ),
                  ),
                ),
              ),
              Text(
                '${_currentIndex + 1}/${_questions.length}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.local_fire_department,
                      color: Theme.of(context).colorScheme.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '$_streak',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Main Noun Card + Article Buttons — kept in a single top-aligned
        // scroll flow (rather than the card centered separately from a
        // bottom-pinned button row) so the buttons sit directly below the
        // card instead of pinned to the screen's bottom edge with a large
        // gap in between.
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Animate(
                    key: ValueKey(_currentIndex),
                    effects: const [
                      FadeEffect(duration: Duration(milliseconds: 300)),
                      ScaleEffect(begin: Offset(0.95, 0.95)),
                    ],
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 24,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: _isAnswered
                              ? _getGenderColor(current.genderCode)
                              : Theme.of(
                                  context,
                                ).dividerColor.withValues(alpha: 0.8),
                          width: _isAnswered ? 2.5 : 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Card Header Badge Row (Rank / SRS Badge & TTS Button)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (current.isDueForSrs)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.hourglass_bottom_rounded,
                                        size: 13,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Due Review',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else if (current.freqRank != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Rank #${current.freqRank}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                )
                              else
                                const SizedBox.shrink(),

                              IconButton(
                                iconSize: 24,
                                icon: Icon(
                                  Icons.volume_up_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                tooltip: 'Play pronunciation',
                                onPressed: () => _ttsService.speak(
                                  _getSpokenText(current),
                                  lang: 'de-DE',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Word and Article Title
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _isAnswered
                                      ? _getGenderColor(
                                          current.genderCode,
                                        ).withValues(alpha: 0.15)
                                      : Theme.of(context).colorScheme.primary
                                            .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _isAnswered ? current.article : '?',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    color: _isAnswered
                                        ? _getGenderColor(current.genderCode)
                                        : Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    current.word,
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.3,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Divider(
                            color: Theme.of(
                              context,
                            ).dividerColor.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 12),

                          // Primary Definition
                          Text(
                            current.translation,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 14),

                          // Categorized Metadata Badges (IPA & Plural)
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (current.ipa != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: Theme.of(
                                        context,
                                      ).dividerColor.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    current.ipa!,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              if (_isAnswered && current.plural != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getGenderColor(
                                      current.genderCode,
                                    ).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: _getGenderColor(
                                        current.genderCode,
                                      ).withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    'Plural: ${current.plural}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Rule & Exception Pill Slot (Constant height before and after answer)
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 250),
                    crossFadeState: (rule != null && _isAnswered)
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild: Padding(
                      padding: const EdgeInsets.only(top: 14.0),
                      child: InkWell(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => GenderRulesGuideScreen(
                              targetWord: current.word,
                            ),
                          ),
                        ),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.25),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.lightbulb_outline_rounded,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Suffix & Gender Rule Hint',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Tap to explore German gender rules & suffixes →',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 20,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    secondChild: rule != null
                        ? Padding(
                            padding: const EdgeInsets.only(top: 14.0),
                            child: InkWell(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => GenderRulesGuideScreen(
                                    targetRuleTitle: rule.title,
                                    targetWord: current.word,
                                  ),
                                ),
                              ),
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: _getGenderColor(
                                    current.genderCode,
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: _getGenderColor(
                                      current.genderCode,
                                    ).withValues(alpha: 0.4),
                                    width: 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      rule.isException
                                          ? Icons.warning_amber_rounded
                                          : Icons.lightbulb_rounded,
                                      color: _getGenderColor(
                                        current.genderCode,
                                      ),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            rule.conciseHint,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            rule.isException
                                                ? 'Tap to view exception details & rule →'
                                                : 'Tap to view full rule & examples →',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: _getGenderColor(
                                                current.genderCode,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      size: 20,
                                      color: _getGenderColor(
                                        current.genderCode,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    height: 60,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _isAnswered
                          ? SizedBox(
                              key: const ValueKey('next_button'),
                              width: double.infinity,
                              height: 60,
                              child: FilledButton.icon(
                                onPressed: _nextQuestion,
                                style: FilledButton.styleFrom(
                                  backgroundColor:
                                      _selectedGender == current.genderCode
                                      ? Colors.green
                                      : Theme.of(context).colorScheme.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 22,
                                ),
                                label: const Text(
                                  'Next Word',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            )
                          : Row(
                              key: const ValueKey('article_buttons'),
                              children: [
                                _buildGenderButton(
                                  context,
                                  'Der',
                                  'm',
                                  AppTheme.genderMasc,
                                  current.genderCode,
                                ),
                                const SizedBox(width: 12),
                                _buildGenderButton(
                                  context,
                                  'Die',
                                  'f',
                                  AppTheme.genderFem,
                                  current.genderCode,
                                ),
                                const SizedBox(width: 12),
                                _buildGenderButton(
                                  context,
                                  'Das',
                                  'n',
                                  AppTheme.genderNeu,
                                  current.genderCode,
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getGenderColor(String code) {
    switch (code) {
      case 'm':
        return AppTheme.genderMasc;
      case 'f':
        return AppTheme.genderFem;
      case 'n':
        return AppTheme.genderNeu;
      default:
        return AppTheme.genderMasc;
    }
  }

  // Same visual language as VocabStatusPills (neutral outline pill at rest,
  // solid color fill with white text once active) — except each button's
  // "active" color is its own gender color instead of a fixed per-option
  // color, so Der/Die/Das still carry their usual color identity once
  // answered, without three saturated hues competing before that.
  Widget _buildGenderButton(
    BuildContext context,
    String label,
    String code,
    Color genderColor,
    String correctCode,
  ) {
    final bool isSelected = _selectedGender == code;
    final bool isCorrectCode = code == correctCode;
    final bool isActive = _isAnswered && (isCorrectCode || isSelected);
    final colorScheme = Theme.of(context).colorScheme;

    Color buttonBg = colorScheme.surfaceContainerHigh;
    Color borderColor = colorScheme.outlineVariant.withValues(alpha: 0.5);
    Color textColor = colorScheme.onSurfaceVariant;
    Widget? iconSuffix;

    if (isActive) {
      buttonBg = genderColor;
      borderColor = genderColor;
      textColor = Colors.white;
      iconSuffix = Icon(
        isCorrectCode ? Icons.check_circle_rounded : Icons.cancel_rounded,
        color: Colors.white,
        size: 20,
      );
    } else if (_isAnswered) {
      buttonBg = Theme.of(context).disabledColor.withValues(alpha: 0.05);
      borderColor = Theme.of(context).dividerColor.withValues(alpha: 0.3);
      textColor = Theme.of(context).disabledColor;
    }

    return Expanded(
      child: GestureDetector(
        onTap: _isAnswered ? null : () => _handleSelectGender(code),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: buttonBg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: borderColor, width: isActive ? 1.5 : 1.0),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                  color: textColor,
                ),
              ),
              if (iconSuffix != null) ...[const SizedBox(width: 4), iconSuffix],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletionSummary() {
    final int totalCount = _originalDeckSize > 0
        ? _originalDeckSize
        : _questions.length;
    final double percentage = totalCount > 0 ? (_score / totalCount) * 100 : 0;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.emoji_events_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 54,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Practice Complete!',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'First Attempt Accuracy: $_score / $totalCount (${percentage.toStringAsFixed(0)}%)',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),

            // Stat Chips
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatChip(
                  Icons.check_circle_outline,
                  '$_score Correct',
                  Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                _buildStatChip(
                  Icons.local_fire_department,
                  'Best Streak: $_bestStreak',
                  Theme.of(context).colorScheme.secondary,
                ),
              ],
            ),
            const SizedBox(height: 36),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _loadQuestions,
                icon: const Icon(Icons.replay_rounded),
                label: const Text(
                  'Practice Again',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _showModeSelectionSheet,
                icon: const Icon(Icons.tune_rounded),
                label: const Text('Change Deck Level'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back to Home'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
