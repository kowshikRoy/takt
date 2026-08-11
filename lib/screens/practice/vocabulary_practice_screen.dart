import 'package:flutter/material.dart';
import '../../models/saved_word.dart';
import '../../services/vocabulary_service.dart';
import '../../services/dictionary_service.dart';
import '../../services/tts_service.dart';
import '../../services/sound_service.dart';
import '../../services/haptic_service.dart';
import '../../services/profile_service.dart';
import '../../services/gamification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/capped_width.dart';
import '../../widgets/word_header_card.dart';
import '../../widgets/noun_headword_title.dart';
import '../word_detail_screen.dart';

class VocabularyPracticeScreen extends StatefulWidget {
  const VocabularyPracticeScreen({super.key});

  @override
  State<VocabularyPracticeScreen> createState() =>
      _VocabularyPracticeScreenState();
}

class _VocabularyPracticeScreenState extends State<VocabularyPracticeScreen> {
  final VocabularyService _vocabService = VocabularyService();
  final DictionaryService _dictionaryService = DictionaryService();
  final TtsService _ttsService = TtsService();

  List<SavedWord> _dueWords = [];
  int _currentIndex = 0;
  bool _showAnswer = false;
  bool _isLoading = true;
  bool _isPracticingAll = false;
  int _reviewedThisSession = 0;
  final Map<String, Map<String, String?>> _exampleCache = {};
  final Map<String, Map<String, dynamic>> _wordDetailsCache = {};
  final Map<String, Future<String?>> _imageFutureCache = {};

  @override
  void initState() {
    super.initState();
    _loadDeck();
  }

  Future<void> _loadDeck({bool forceAll = false}) async {
    setState(() => _isLoading = true);
    _isPracticingAll = forceAll;
    _vocabService.repairStaleDefinitions().catchError((_) => 0);

    List<SavedWord> words;
    if (forceAll) {
      words = await _vocabService.getSavedWords();
    } else {
      words = await _vocabService.getDueWords();
      // If no words are due, check if user has saved words so they can practice anyway
      if (words.isEmpty) {
        final allSaved = await _vocabService.getSavedWords();
        if (allSaved.isNotEmpty) {
          _isPracticingAll = true;
          words = allSaved;
        }
      }
    }

    if (mounted) {
      setState(() {
        _dueWords = words;
        _currentIndex = 0;
        _showAnswer = false;
        _isLoading = false;
      });
      _preloadExamples();
    }
  }

  Future<void> _preloadExamples() async {
    for (final word in _dueWords) {
      final lower = word.word.toLowerCase().trim();
      if (!_wordDetailsCache.containsKey(lower)) {
        final hydrated = await _dictionaryService.hydrateSavedWord(word);
        if (mounted) {
          setState(() {
            _wordDetailsCache[lower] = hydrated;
          });
        }
      }
      if (word.contextSentence == null || word.contextSentence!.isEmpty) {
        if (!_exampleCache.containsKey(lower)) {
          final examples = await _dictionaryService.getExamplesForWord(
            word.word,
          );
          if (examples.isNotEmpty && mounted) {
            setState(() {
              _exampleCache[lower] = examples.first;
            });
          }
        }
      }
    }
  }

  Future<void> _rateCard(ReviewRating rating) async {
    if (_dueWords.isEmpty || _currentIndex >= _dueWords.length) return;
    final currentWord = _dueWords[_currentIndex];

    // 1. Auditory & Haptic feedback
    if (rating == ReviewRating.again) {
      SoundService().playIncorrect();
      AppHaptics.error();
    } else if (rating == ReviewRating.good || rating == ReviewRating.easy) {
      SoundService().playCorrect();
      AppHaptics.success();
    } else {
      AppHaptics.light();
    }

    // 2. Persist SRS Review in VocabularyService & ProfileService
    await _vocabService.recordReview(currentWord.id, rating);
    _reviewedThisSession++;

    // 3. Move to next card
    if (mounted) {
      final isLastCard = _currentIndex + 1 >= _dueWords.length;
      if (isLastCard) {
        AppHaptics.heavy();
      }
      setState(() {
        _showAnswer = false;
        _currentIndex++;
      });
    }
  }

  Color _getGenderColor(String? gender) {
    if (gender == 'masculine' || gender == 'm') return AppTheme.genderMasc;
    if (gender == 'feminine' || gender == 'f') return AppTheme.genderFem;
    if (gender == 'neuter' || gender == 'n') return AppTheme.genderNeu;
    return Colors.indigo;
  }

  Future<void> _confirmRemoveCurrentWord(
    BuildContext context,
    SavedWord word,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from Study Deck?'),
        content: Text(
          'Remove "${word.word}" from your saved vocabulary and review queue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF8C2D19),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _vocabService.removeWord(word.id);
      setState(() {
        _dueWords.removeAt(_currentIndex);
        _showAnswer = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed "${word.word}" from Study Deck'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inkColor = isDark ? const Color(0xFFEDE8E1) : const Color(0xFF1E1B18);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _isPracticingAll
              ? 'Vocabulary Practice (All Words)'
              : 'Daily Review & SRS Practice',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: inkColor,
          ),
        ),
        elevation: 0,
        actions: [
          if (_dueWords.isNotEmpty && _currentIndex < _dueWords.length)
            IconButton(
              icon: Icon(
                Icons.bookmark_remove_outlined,
                color: inkColor.withValues(alpha: 0.7),
                size: 20,
              ),
              tooltip: 'Remove from Study Deck',
              onPressed: () => _confirmRemoveCurrentWord(context, _dueWords[_currentIndex]),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: CappedWidth(
                child: Column(
                  children: [
                    Expanded(
                      child:
                          _dueWords.isEmpty || _currentIndex >= _dueWords.length
                          ? _buildCompletionCard()
                          : _buildFlashcard(_dueWords[_currentIndex]),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Map<String, dynamic> _wordDataFor(SavedWord word) {
    final lower = word.word.toLowerCase().trim();
    final cached = _wordDetailsCache[lower];
    if (cached != null) return cached;

    final effectiveSource = word.source.isNotEmpty ? word.source : 'dictionary_saved';
    final effectiveLabel = effectiveSource == 'wiktionary_fetched'
        ? 'Wiktionary'
        : (effectiveSource == 'user_edited'
            ? 'Custom Note'
            : (effectiveSource == 'nmt_translation' ? 'Google Translate' : 'Dictionary'));

    final userDefs = word.definitions.isNotEmpty
        ? List<String>.from(word.definitions)
        : (word.primaryDefinition.isNotEmpty ? [word.primaryDefinition] : <String>[]);

    return {
      'word': word.word,
      'base_form': word.baseForm ?? word.word,
      'pos': word.pos ?? '',
      'gender': word.gender ?? '',
      'ipa': word.ipa ?? '',
      'definitions': userDefs,
      'definition': userDefs.isNotEmpty ? userDefs.first : word.primaryDefinition,
      'source': effectiveSource,
      'sourceLabel': effectiveLabel,
      'isFromUserDatabase': true,
      'category': word.category.name,
      'contextSentence': word.contextSentence,
      'contextExamples': word.contextExamples,
    };
  }

  ({String? german, String? english}) _exampleFor(SavedWord word) {
    if (word.contextSentence != null && word.contextSentence!.isNotEmpty) {
      return (german: word.contextSentence, english: null);
    }
    final cached = _exampleCache[word.word.toLowerCase().trim()];
    return (german: cached?['de'], english: cached?['en']);
  }

  Future<String?> _imageFutureFor(SavedWord word) {
    final key = word.word.toLowerCase().trim();
    return _imageFutureCache.putIfAbsent(
      key,
      () => _dictionaryService.getWordImageUrl(word.word, pos: word.pos),
    );
  }

  Widget _buildFlashcard(SavedWord word) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inkColor = isDark ? const Color(0xFFEDE8E1) : const Color(0xFF1E1B18);
    final cardBg = isDark ? const Color(0xFF221E1A) : const Color(0xFFF2EEE7);
    final genderColor = _getGenderColor(word.gender);
    final example = _exampleFor(word);
    final wordData = _wordDataFor(word);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        children: [
          // Header info: Mode & SRS Mastery badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: inkColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: inkColor.withValues(alpha: 0.18)),
                ),
                child: Text(
                  _isPracticingAll ? 'FREE PRACTICE' : 'SRS DUE REVIEW',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: inkColor,
                  ),
                ),
              ),
              Text(
                '${_currentIndex + 1} / ${_dueWords.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: inkColor.withValues(alpha: 0.7),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: genderColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: genderColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  word.masteryLevelLabel.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: genderColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Progress indicator
          LinearProgressIndicator(
            value: (_currentIndex + 1) / _dueWords.length,
            backgroundColor: theme.dividerColor.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(genderColor),
            borderRadius: BorderRadius.circular(3),
            minHeight: 4,
          ),
          const SizedBox(height: 14),

          // Main Flashcard Box — fills the available vertical space between
          // the progress header and the rating buttons, with clean inner scrolling
          Expanded(
            child: InkWell(
              onTap: () {
                AppHaptics.medium();
                setState(() {
                  _showAnswer = !_showAnswer;
                });
                if (_showAnswer) {
                  // Auto-play the header (article + word + plural, when
                  // known) the moment the card flips to reveal the answer.
                  _ttsService.speak(
                    WordHeaderCard.buildSpeakText(_wordDataFor(word)),
                    lang: 'de-DE',
                  );
                }
                if (_showAnswer &&
                    (word.contextSentence == null ||
                        word.contextSentence!.isEmpty)) {
                  final lower = word.word.toLowerCase().trim();
                  if (!_exampleCache.containsKey(lower)) {
                    _dictionaryService.getExamplesForWord(word.word).then((
                      examples,
                    ) {
                      if (examples.isNotEmpty && mounted) {
                        setState(() {
                          _exampleCache[lower] = examples.first;
                        });
                      }
                    });
                  }
                }
              },
              borderRadius: BorderRadius.circular(4),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: genderColor.withValues(alpha: 0.45),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            word.word,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: inkColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          onPressed: () =>
                              _ttsService.speak(word.word, lang: 'de-DE'),
                          icon: Icon(
                            Icons.volume_up_rounded,
                            color: genderColor,
                            size: 24,
                          ),
                          tooltip: 'Play pronunciation',
                        ),
                      ],
                    ),

                    if (wordData['pos'] != null && wordData['pos'].toString().trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: inkColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                            color: inkColor.withValues(alpha: 0.18),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          wordData['pos'].toString().trim().toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: inkColor.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],

                    if (word.ipa != null && word.ipa!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        word.ipa!,
                        style: TextStyle(
                          fontSize: 13,
                          color: inkColor.withValues(alpha: 0.6),
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: !_showAnswer
                            ? Center(
                                key: const ValueKey('hint'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: inkColor.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(
                                      color: inkColor.withValues(alpha: 0.15),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.touch_app_rounded,
                                        size: 15,
                                        color: inkColor.withValues(alpha: 0.7),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        "Tap card to flip answer",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: inkColor.withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : SingleChildScrollView(
                                key: const ValueKey('answer'),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const SizedBox(height: 4),
                                    WordHeaderCard(
                                      wordData: _wordDataFor(word),
                                      contextSentence: example.german,
                                      wordImageFuture: _imageFutureFor(word),
                                      ipa: word.ipa,
                                      showStatusPills: false,
                                      showSpeakerButton: false,
                                      savedWordIds: const {},
                                      savedWordCategories: const {},
                                      onCategorySelected: (_) {},
                                    ),
                                    if (example.english != null &&
                                        example.english!.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        example.english!,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: inkColor.withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => WordDetailScreen(
                                                word: word.word,
                                                wordData: _wordDataFor(word),
                                              ),
                                            ),
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.menu_book_rounded,
                                          size: 16,
                                        ),
                                        label: const Text(
                                          'Explore in Dictionary →',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Rating buttons: always present so layout never resizes when card flips
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _showAnswer ? 1.0 : 0.0,
            child: IgnorePointer(
              ignoring: !_showAnswer,
              child: Row(
                children: [
                  Expanded(
                    child: _buildRatingButton(
                      label: "Again",
                      sublabel: "Reset",
                      rating: ReviewRating.again,
                      color: const Color(0xFFC0392B),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildRatingButton(
                      label: "Hard",
                      sublabel: "+1d",
                      rating: ReviewRating.hard,
                      color: const Color(0xFFD35400),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildRatingButton(
                      label: "Good",
                      sublabel: "SM-2",
                      rating: ReviewRating.good,
                      color: const Color(0xFF2980B9),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildRatingButton(
                      label: "Easy",
                      sublabel: "+Bonus",
                      rating: ReviewRating.easy,
                      color: const Color(0xFF27AE60),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingButton({
    required String label,
    required String sublabel,
    required ReviewRating rating,
    required Color color,
  }) {
    return ElevatedButton(
      onPressed: () => _rateCard(rating),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        elevation: 0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          Text(
            sublabel,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inkColor = isDark ? const Color(0xFFEDE8E1) : const Color(0xFF1E1B18);
    final cardBg = isDark ? const Color(0xFF221E1A) : const Color(0xFFF2EEE7);
    final rustAccent = isDark ? const Color(0xFFE05338) : const Color(0xFF8C2D19);

    final profileService = ProfileService();
    final gamification = GamificationService();
    final totalSaved = _vocabService.cachedSavedCount;

    final bool hasReviewedInSession = _reviewedThisSession > 0;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: inkColor.withValues(alpha: 0.18),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.task_alt_rounded,
                  size: 36,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                hasReviewedInSession
                    ? 'Review Session Complete! 🎉'
                    : (totalSaved > 0
                        ? 'All Caught Up! 🎉'
                        : 'No Study Deck Words Yet'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: inkColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                hasReviewedInSession
                    ? 'Great job keeping your memory fresh and advancing your Spaced Repetition mastery!'
                    : (totalSaved > 0
                        ? 'You have 0 words due for review right now. Keep your streak going or practice your entire deck anytime!'
                        : 'Save words from stories, videos, or lookups to build your personalized Study Deck!'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: inkColor.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 20),

              // Summary Stats Box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: inkColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: inkColor.withValues(alpha: 0.12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCol(
                      label: 'REVIEWED',
                      value: '$_reviewedThisSession',
                      inkColor: inkColor,
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      color: inkColor.withValues(alpha: 0.12),
                    ),
                    _buildStatCol(
                      label: 'MASTERY PTS',
                      value: '${_vocabService.vocabMasteryScore}',
                      inkColor: inkColor,
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      color: inkColor.withValues(alpha: 0.12),
                    ),
                    _buildStatCol(
                      label: 'LEVEL',
                      value: 'Lvl ${gamification.level}',
                      inkColor: rustAccent,
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      color: inkColor.withValues(alpha: 0.12),
                    ),
                    _buildStatCol(
                      label: 'STREAK',
                      value: '${profileService.currentStreak}d 🔥',
                      inkColor: rustAccent,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Action Buttons
              if (totalSaved > 0) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _loadDeck(forceAll: true),
                    icon: const Icon(Icons.style_rounded, size: 16),
                    label: Text(
                      'Practice Entire Study Deck ($totalSaved)',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: rustAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: const Text(
                    'Back to Home',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCol({
    required String label,
    required String value,
    required Color inkColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: inkColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: inkColor.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

