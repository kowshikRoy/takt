import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../services/dictionary_service.dart';
import '../../services/vocabulary_service.dart';
import '../../services/tts_service.dart';
import '../../models/saved_word.dart';

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
        conciseHint: '⚠️ Exception: -$word is Masculine (Der), not Feminine',
        explanation: 'While ~90% of nouns ending in "-e" are Feminine, "$cleanWord" is a rare Masculine exception!',
        example: 'der Käse, der Name, der Gedanke, der Junge, der Kunde',
        isException: true,
        exceptionNote: '90% of two-syllable nouns ending in "-e" are Feminine (Die). Masculine nouns ending in "-e" are weak N-declension nouns.',
        commonExceptions: ['der Käse', 'der Name', 'der Gedanke', 'der Junge', 'der Kunde'],
      );
    }

    if (genderCode == 'n' && lower.endsWith('e') && !lower.startsWith('ge')) {
      return GenderRuleMatch(
        title: 'Exception: Noun in -e is Neuter (Das)',
        conciseHint: '⚠️ Exception: -$word is Neuter (Das), not Feminine',
        explanation: 'While ~90% of nouns ending in "-e" are Feminine, "$cleanWord" is a Neuter exception!',
        example: 'das Auge, das Ende, das Erbe',
        isException: true,
        exceptionNote: '90% of "-e" nouns are Feminine (Die), but a few body/abstract nouns are Neuter.',
        commonExceptions: ['das Auge', 'das Ende', 'das Erbe'],
      );
    }

    if (genderCode == 'n' && lower.endsWith('er') && cleanWord.length > 3) {
      return GenderRuleMatch(
        title: 'Exception: Noun in -er is Neuter (Das)',
        conciseHint: '⚠️ Exception: -$word is Neuter (Das), not Masculine',
        explanation: 'While ~70% of nouns ending in "-er" are Masculine, "$cleanWord" is a Neuter tool/object exception!',
        example: 'das Fenster, das Wasser, das Zimmer, das Messer, das Papier',
        isException: true,
        exceptionNote: 'Most "-er" nouns are active Masculine agents (der Fahrer), but many inanimate household objects are Neuter.',
        commonExceptions: ['das Fenster', 'das Wasser', 'das Zimmer', 'das Messer', 'das Papier'],
      );
    }

    if (genderCode == 'f' && lower.endsWith('er') && cleanWord.length > 3) {
      return GenderRuleMatch(
        title: 'Exception: Noun in -er is Feminine (Die)',
        conciseHint: '⚠️ Exception: -$word is Feminine (Die), not Masculine',
        explanation: 'While ~70% of nouns ending in "-er" are Masculine, "$cleanWord" is a Feminine family/nature exception!',
        example: 'die Mutter, die Butter, die Tochter, die Schulter',
        isException: true,
        exceptionNote: 'Most "-er" nouns are Masculine (Der), but female family roles and a few basic words are Feminine.',
        commonExceptions: ['die Mutter', 'die Butter', 'die Tochter', 'die Schulter'],
      );
    }

    if (genderCode == 'n' && (lower.endsWith('ent') || lower.endsWith('ant'))) {
      return GenderRuleMatch(
        title: 'Exception: Noun in -ent is Neuter (Das)',
        conciseHint: '⚠️ Exception: -$word is Neuter (Das), not Masculine',
        explanation: 'While ~90% of "-ent" nouns are Masculine people/agents, "$cleanWord" is a Neuter exception!',
        example: 'das Talent, das Patent, das Element',
        isException: true,
        exceptionNote: 'Masculine "-ent" nouns usually describe active male persons (der Student), whereas inanimate concepts are Neuter.',
        commonExceptions: ['das Talent', 'das Patent', 'das Element'],
      );
    }

    // ==================== DIE (Feminine) STANDARD RULES ====================
    if (genderCode == 'f') {
      if (lower.endsWith('ung')) {
        return GenderRuleMatch(
          title: 'Suffix -ung is 100% Feminine (Die)',
          conciseHint: '💡 Suffix -ung is always Feminine (Die)',
          explanation: 'Nouns ending in "-ung" are 100% feminine with zero exceptions in German.',
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
          explanation: 'Nouns ending in "-schaft" (groups & states) are 100% feminine.',
          example: 'die Freundschaft, die Mannschaft, die Landschaft',
        );
      }
      if (lower.endsWith('ei')) {
        return GenderRuleMatch(
          title: 'Suffix -ei is 100% Feminine (Die)',
          conciseHint: '💡 Suffix -ei is always Feminine (Die)',
          explanation: 'Nouns ending in "-ei" (businesses & locations) are 100% feminine.',
          example: 'die Bäckerei, die Bücherei, die Datei',
        );
      }
      if (lower.endsWith('ion')) {
        return GenderRuleMatch(
          title: 'Suffix -ion is 100% Feminine (Die)',
          conciseHint: '💡 Suffix -ion is always Feminine (Die)',
          explanation: 'Nouns ending in "-ion" of Latin origin are 100% feminine.',
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
          explanation: 'Academic, artistic, and scientific subjects ending in "-ik" are feminine.',
          example: 'die Musik, die Grammatik, die Politik, die Technik',
        );
      }
      if (lower.endsWith('in') && lower.length > 3) {
        return GenderRuleMatch(
          title: 'Female Role -in is 100% Feminine (Die)',
          conciseHint: '💡 Female Role -in is Feminine (Die)',
          explanation: 'Female professions and roles ending in "-in" are 100% feminine.',
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
          example: 'die Natur, die Kultur, die Struktur, die Kultur',
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
          explanation: 'Most two-syllable German nouns ending in "-e" are feminine.',
          example: 'die Katze, die Blume, die Sonne, die Lampe, die Tasche',
          commonExceptions: ['der Käse', 'der Name', 'der Junge', 'das Auge', 'das Ende'],
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
          explanation: 'Collective nouns starting with "Ge-" and ending with "-e" are neuter.',
          example: 'das Gebäude, das Gemüse, das Gespräch, das Gebirge',
        );
      }
      if (cleanWord.length > 3 && cleanWord[0] == cleanWord[0].toUpperCase() && lower.endsWith('en')) {
        return GenderRuleMatch(
          title: 'Nominalized Verb (-en) is Neuter (Das)',
          conciseHint: '💡 Nominalized Verb (-en) is Neuter (Das)',
          explanation: 'Verbs used as nouns (infinitives ending in "-en") are neuter.',
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
          example: 'der Schmetterling, der Lehrling, der Neuling, der Schützling',
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
          explanation: 'Nouns describing agents or machines ending in "-or" are masculine.',
          example: 'der Motor, der Faktor, der Reaktor, der Sensor',
        );
      }
      if (lower.endsWith('ist')) {
        return GenderRuleMatch(
          title: 'Suffix -ist is Masculine (Der)',
          conciseHint: '💡 Suffix -ist is Masculine (Der)',
          explanation: 'Nouns describing active people ending in "-ist" are masculine.',
          example: 'der Polizist, der Optimist, der Journalist, der Pianist',
        );
      }
      if (lower.endsWith('ant') || lower.endsWith('ent')) {
        return GenderRuleMatch(
          title: 'Suffix -ant / -ent is Masculine (Der)',
          conciseHint: '💡 Suffix -ant / -ent is Masculine (Der)',
          explanation: 'Nouns ending in "-ant" or "-ent" describing people are masculine.',
          example: 'der Elefant, der Student, der Lieferant, der President',
          commonExceptions: ['das Talent', 'das Patent', 'das Element'],
        );
      }
      if (lower.endsWith('er') && lower.length > 3) {
        return GenderRuleMatch(
          title: 'Agent Suffix -er is ~70% Masculine (Der)',
          conciseHint: '💡 Suffix -er is ~70% Masculine (Der)',
          explanation: 'Nouns describing active agents or tools ending in "-er" are masculine.',
          example: 'der Fahrer, der Computer, der Wecker, der Drucker, der Lehrer',
          commonExceptions: ['das Fenster', 'das Wasser', 'das Zimmer', 'die Mutter', 'die Butter'],
        );
      }
    }

    return null;
  }
}

class NounQuestion {
  final String word;
  final String genderCode; // 'm', 'f', 'n'
  final String? ipa;
  final String translation;
  final String? plural;

  NounQuestion({
    required this.word,
    required this.genderCode,
    this.ipa,
    required this.translation,
    this.plural,
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

  List<NounQuestion> _questions = [];
  bool _isLoading = true;
  int _currentIndex = 0;
  int _score = 0;
  int _streak = 0;
  int _bestStreak = 0;
  String? _selectedGender; // 'm', 'f', 'n'
  bool _isAnswered = false;
  bool _isFinished = false;

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
    });

    List<NounQuestion> loaded = [];

    // 1. Due Spaced Repetition Nouns
    try {
      final dueWords = await _vocabularyService.getDueWords();
      if (dueWords.isNotEmpty) {
        final dueStrings = dueWords.map((w) => w.germanWord).toList();
        final genderMap = await _dictionaryService.getGendersForWords(dueStrings);
        for (var dw in dueWords) {
          final gRaw = genderMap[dw.germanWord]?.toLowerCase();
          if (gRaw != null) {
            String code = 'm';
            if (gRaw.startsWith('f') || gRaw == 'die') code = 'f';
            if (gRaw.startsWith('n') || gRaw == 'das') code = 'n';
            loaded.add(NounQuestion(
              word: dw.germanWord,
              genderCode: code,
              translation: dw.primaryDefinition,
            ));
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching due SRS words: $e");
    }

    // 2. High-Frequency Essential German Nouns (A1/A2/B1 Common Nouns)
    if (loaded.length < 10) {
      try {
        final highFreqNouns = await _dictionaryService.getHighFrequencyNouns(limit: 15);
        for (var row in highFreqNouns) {
          final word = row['word'] as String?;
          final gRaw = (row['gender'] as String?)?.toLowerCase();
          final def = row['definition'] as String? ?? 'German noun';
          final ipa = row['ipa'] as String?;

          if (word != null &&
              gRaw != null &&
              !_dictionaryService.isGrammaticalJargon(def) &&
              !loaded.any((q) => q.word.toLowerCase() == word.toLowerCase())) {
            String code = 'm';
            if (gRaw.startsWith('f') || gRaw == 'die') code = 'f';
            if (gRaw.startsWith('n') || gRaw == 'das') code = 'n';
            final wordId = row['id'] as int?;
            String? pluralForm;
            if (wordId != null) {
              pluralForm = await _dictionaryService.getPluralForm(wordId, word);
            }
            loaded.add(NounQuestion(
              word: word,
              genderCode: code,
              ipa: ipa,
              translation: def,
              plural: pluralForm,
            ));
          }
        }
      } catch (e) {
        debugPrint("Error fetching high-frequency nouns: $e");
      }
    }

    // 3. Saved User Words
    if (loaded.length < 10) {
      try {
        final savedWords = await _vocabularyService.getSavedWords();
        final savedWordStrings = savedWords.map((w) => w.germanWord).toList();
        if (savedWordStrings.isNotEmpty) {
          final genderMap = await _dictionaryService.getGendersForWords(savedWordStrings);
          for (var sw in savedWords) {
            if (!loaded.any((q) => q.word.toLowerCase() == sw.germanWord.toLowerCase())) {
              final gRaw = genderMap[sw.germanWord]?.toLowerCase();
              if (gRaw != null) {
                String code = 'm';
                if (gRaw.startsWith('f') || gRaw == 'die') code = 'f';
                if (gRaw.startsWith('n') || gRaw == 'das') code = 'n';
                loaded.add(NounQuestion(
                  word: sw.germanWord,
                  genderCode: code,
                  translation: sw.translation,
                ));
              }
            }
          }
        }
      } catch (e) {
        debugPrint("Error fetching saved words for gender quiz: $e");
      }
    }

    // 4. Random Clean Dictionary Nouns if still under 10
    if (loaded.length < 10) {
      try {
        final randomNouns = await _dictionaryService.getRandomNouns(limit: 20);
        for (var row in randomNouns) {
          final word = row['word'] as String?;
          final gRaw = (row['gender'] as String?)?.toLowerCase();
          final def = row['definition'] as String? ?? 'German noun';
          final ipa = row['ipa'] as String?;

          if (word != null &&
              word.isNotEmpty &&
              word[0] == word[0].toUpperCase() &&
              gRaw != null &&
              !_dictionaryService.isGrammaticalJargon(def) &&
              !loaded.any((q) => q.word.toLowerCase() == word.toLowerCase())) {
            String code = 'm';
            if (gRaw.startsWith('f') || gRaw == 'die') code = 'f';
            if (gRaw.startsWith('n') || gRaw == 'das') code = 'n';
            final wordId = row['id'] as int?;
            String? pluralForm;
            if (wordId != null) {
              pluralForm = await _dictionaryService.getPluralForm(wordId, word);
            }
            loaded.add(NounQuestion(
              word: word,
              genderCode: code,
              ipa: ipa,
              translation: def,
              plural: pluralForm,
            ));
          }
        }
      } catch (e) {
        debugPrint("Error fetching random nouns: $e");
      }
    }

    if (loaded.length > 10) {
      loaded = loaded.sublist(0, 10);
    }

    if (mounted) {
      setState(() {
        _questions = loaded;
        _isLoading = false;
      });
    }
  }

  void _handleSelectGender(String code) {
    if (_isAnswered || _currentIndex >= _questions.length) return;

    final current = _questions[_currentIndex];
    final bool isCorrect = (code == current.genderCode);
    final rule = GermanGenderRules.getRule(current.word, current.genderCode);

    setState(() {
      _selectedGender = code;
      _isAnswered = true;
      if (isCorrect) {
        _score++;
        _streak++;
        if (_streak > _bestStreak) _bestStreak = _streak;
      } else {
        _streak = 0;
      }
    });

    // Record SM-2 Spaced Repetition Review
    _recordSrsReview(current, isCorrect);

    // Speak German article + noun
    _ttsService.speak('${current.article} ${current.word}', lang: 'de-DE');

    // Auto-advance if correct and no rule tip to read, or longer delay if rule is present
    if (isCorrect) {
      final int delayMs = rule != null ? 2200 : 1000;
      Future.delayed(Duration(milliseconds: delayMs), () {
        if (mounted && _isAnswered) _nextQuestion();
      });
    }
  }

  Future<void> _recordSrsReview(NounQuestion question, bool isCorrect) async {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _questions.isEmpty
                ? _buildEmptyState()
                : _isFinished
                    ? _buildCompletionSummary()
                    : _buildQuizBody(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.help_outline_rounded, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'No Nouns Available',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text('Could not load German nouns for practice.'),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadQuestions,
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizBody() {
    final current = _questions[_currentIndex];
    final progress = (_currentIndex + 1) / _questions.length;
    final rule = _isAnswered ? GermanGenderRules.getRule(current.word, current.genderCode) : null;

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                      color: Theme.of(context).colorScheme.primary,
                      minHeight: 10,
                    ),
                  ),
                ),
              ),
              Text(
                '${_currentIndex + 1} / ${_questions.length}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department, color: Colors.orange, size: 16),
                    const SizedBox(width: 2),
                    Text(
                      '$_streak',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Main Noun Card
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Animate(
                      key: ValueKey(_currentIndex),
                      effects: const [FadeEffect(duration: Duration(milliseconds: 300)), ScaleEffect(begin: Offset(0.95, 0.95))],
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: _isAnswered
                                ? _getGenderColor(current.genderCode)
                                : Theme.of(context).dividerColor.withValues(alpha: 0.8),
                            width: _isAnswered ? 2.5 : 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _isAnswered
                                  ? _getGenderColor(current.genderCode).withValues(alpha: 0.25)
                                  : (_streak > 0
                                      ? Colors.orange.withValues(alpha: 0.12)
                                      : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)),
                              blurRadius: 28,
                              spreadRadius: 2,
                              offset: const Offset(0, 8),
                            )
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // TTS Audio Playback Pill
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                iconSize: 28,
                                icon: Icon(Icons.volume_up_rounded, color: Theme.of(context).colorScheme.primary),
                                onPressed: () => _ttsService.speak(
                                  _isAnswered ? '${current.article} ${current.word}' : current.word,
                                  lang: 'de-DE',
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Word and Article Title
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _isAnswered
                                        ? _getGenderColor(current.genderCode).withValues(alpha: 0.15)
                                        : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _isAnswered ? current.article : '?',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      color: _isAnswered
                                          ? _getGenderColor(current.genderCode)
                                          : Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      current.word,
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.3,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Divider(color: Theme.of(context).dividerColor.withValues(alpha: 0.4)),
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
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      current.ipa!,
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                if (_isAnswered && current.plural != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: _getGenderColor(current.genderCode).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _getGenderColor(current.genderCode).withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Text(
                                      'Plural: ${current.plural}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Concise Tappable Rule & Exception Pill (Positioned OUTSIDE main box)
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 250),
                      crossFadeState: (rule != null && _isAnswered)
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      firstChild: const SizedBox.shrink(),
                      secondChild: rule != null
                          ? Padding(
                              padding: const EdgeInsets.only(top: 14.0),
                              child: InkWell(
                                onTap: () => _showGenderRuleModalSheet(context, rule, current),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: rule.isException
                                        ? Colors.orange.withValues(alpha: 0.15)
                                        : _getGenderColor(current.genderCode).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: rule.isException
                                          ? Colors.orange
                                          : _getGenderColor(current.genderCode).withValues(alpha: 0.5),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        rule.isException
                                            ? Icons.warning_amber_rounded
                                            : Icons.lightbulb_rounded,
                                        color: rule.isException
                                            ? Colors.orange
                                            : _getGenderColor(current.genderCode),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              rule.conciseHint,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: Theme.of(context).colorScheme.onSurface,
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
                                                color: rule.isException
                                                    ? Colors.orange
                                                    : _getGenderColor(current.genderCode),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        size: 20,
                                        color: rule.isException
                                            ? Colors.orange
                                            : _getGenderColor(current.genderCode),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Footer / Fixed-Height Action Zone
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    color: _isAnswered
                        ? (_selectedGender == current.genderCode ? Colors.green : Colors.red)
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 1.1,
                  ),
                  child: Text(
                    _isAnswered
                        ? (_selectedGender == current.genderCode
                            ? 'CORRECT! 🥳'
                            : 'INCORRECT 😞')
                        : 'SELECT THE ARTICLE',
                  ),
                ),
                const SizedBox(height: 12),
                
                // Fixed-height container: switches seamlessly between Der/Die/Das buttons and Next Word button
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
                                backgroundColor: _selectedGender == current.genderCode
                                    ? Colors.green
                                    : Theme.of(context).colorScheme.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: const Icon(Icons.arrow_forward_rounded, size: 22),
                              label: const Text(
                                'Next Word',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                              ),
                            ),
                          )
                        : Row(
                            key: const ValueKey('article_buttons'),
                            children: [
                              _buildGenderButton(context, 'Der', 'MASC', 'm', AppTheme.genderMasc, current.genderCode),
                              const SizedBox(width: 12),
                              _buildGenderButton(context, 'Die', 'FEM', 'f', AppTheme.genderFem, current.genderCode),
                              const SizedBox(width: 12),
                              _buildGenderButton(context, 'Das', 'NEU', 'n', AppTheme.genderNeu, current.genderCode),
                            ],
                          ),
                  ),
                ),
              ],
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

  Widget _buildGenderButton(
    BuildContext context,
    String label,
    String subLabel,
    String code,
    Color color,
    String correctCode,
  ) {
    final bool isSelected = _selectedGender == code;
    final bool isCorrectCode = code == correctCode;

    Color buttonBg = color.withValues(alpha: 0.08);
    Color borderColor = color;
    Widget? iconSuffix;

    if (_isAnswered) {
      if (isCorrectCode) {
        buttonBg = Colors.green.withValues(alpha: 0.2);
        borderColor = Colors.green;
        iconSuffix = const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20);
      } else if (isSelected) {
        buttonBg = Colors.red.withValues(alpha: 0.2);
        borderColor = Colors.red;
        iconSuffix = const Icon(Icons.cancel_rounded, color: Colors.red, size: 20);
      } else {
        buttonBg = Theme.of(context).disabledColor.withValues(alpha: 0.05);
        borderColor = Theme.of(context).dividerColor.withValues(alpha: 0.3);
      }
    }

    return Expanded(
      child: OutlinedButton(
        onPressed: _isAnswered ? null : () => _handleSelectGender(code),
        style: OutlinedButton.styleFrom(
          backgroundColor: buttonBg,
          side: BorderSide(color: borderColor, width: isSelected || (isCorrectCode && _isAnswered) ? 2.5 : 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _isAnswered && !isCorrectCode && !isSelected
                        ? Theme.of(context).disabledColor
                        : color,
                  ),
                ),
                if (iconSuffix != null) ...[
                  const SizedBox(width: 4),
                  iconSuffix,
                ]
              ],
            ),
            const SizedBox(height: 2),
            Text(
              subLabel,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: _isAnswered && !isCorrectCode && !isSelected
                    ? Theme.of(context).disabledColor
                    : color.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionSummary() {
    final double percentage = _questions.isEmpty ? 0 : (_score / _questions.length) * 100;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 54),
            ),
            const SizedBox(height: 24),
            Text(
              'Practice Complete!',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'You scored $_score out of ${_questions.length} (${percentage.toStringAsFixed(0)}%)',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),

            // Stat Cards Row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatChip(Icons.check_circle_outline, '$_score Correct', Colors.green),
                const SizedBox(width: 12),
                _buildStatChip(Icons.local_fire_department, 'Best Streak: $_bestStreak', Colors.orange),
              ],
            ),
            const SizedBox(height: 36),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _loadQuestions,
                icon: const Icon(Icons.replay_rounded),
                label: const Text('Practice Again', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _showGenderRuleModalSheet(BuildContext context, GenderRuleMatch rule, NounQuestion question) {
    final genderColor = _getGenderColor(question.genderCode);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.82,
          ),
          decoration: BoxDecoration(
            color: Theme.of(ctx).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          padding: EdgeInsets.only(
            top: 16,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(ctx).padding.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top drag handle
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).dividerColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Header Badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (rule.isException ? Colors.orange : genderColor).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        rule.isException ? Icons.warning_amber_rounded : Icons.lightbulb_rounded,
                        color: rule.isException ? Colors.orange : genderColor,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rule.title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Target Word: ${question.article} ${question.word}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: genderColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),

                // Rule Explanation Section
                Text(
                  'Grammar Rule Breakdown',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(ctx).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(ctx).dividerColor),
                  ),
                  child: Text(
                    rule.explanation,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Standard Examples Section
                Text(
                  'Common Nouns Following This Rule',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(ctx).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: genderColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: genderColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    rule.example,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(ctx).colorScheme.onSurface,
                    ),
                  ),
                ),

                // Exception Section (The Odd 10%)
                if (rule.isException || rule.commonExceptions.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Row(
                    children: const [
                      Icon(Icons.report_problem_outlined, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Exceptions to Watch Out For (The Odd ~10%)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (rule.exceptionNote != null) ...[
                          Text(
                            rule.exceptionNote!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(ctx).colorScheme.onSurface,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        Text(
                          'Famous Exceptions: ${rule.commonExceptions.join(', ')}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
