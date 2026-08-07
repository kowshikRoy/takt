import 'package:flutter/material.dart';
import '../../models/saved_word.dart';
import '../../models/xp_event.dart';
import '../../services/vocabulary_service.dart';
import '../../services/dictionary_service.dart';
import '../../services/tts_service.dart';
import '../../services/gamification_service.dart';
import '../../services/sound_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/capped_width.dart';
import '../../widgets/word_header_card.dart';
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
  final Map<String, Map<String, String?>> _exampleCache = {};
  final Map<String, Future<String?>> _imageFutureCache = {};

  @override
  void initState() {
    super.initState();
    _loadDeck();
  }

  Future<void> _loadDeck() async {
    setState(() => _isLoading = true);
    await _vocabService.repairStaleDefinitions();
    final due = await _vocabService.getDueWords();
    if (mounted) {
      setState(() {
        _dueWords = due;
        _currentIndex = 0;
        _showAnswer = false;
        _isLoading = false;
      });
      _preloadExamples();
    }
  }

  Future<void> _preloadExamples() async {
    for (final word in _dueWords) {
      if (word.contextSentence == null || word.contextSentence!.isEmpty) {
        final lower = word.word.toLowerCase().trim();
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
    await _vocabService.recordReview(currentWord.id, rating);
    GamificationService().awardXp(XpSource.reviewCompleted).then((_) {
      if (GamificationService().justLeveledUp) {
        SoundService().playLevelUp();
      } else if (rating == ReviewRating.again) {
        SoundService().playIncorrect();
      } else {
        SoundService().playCorrect();
      }
    });

    setState(() {
      _showAnswer = false;
      _currentIndex++;
    });
  }

  Color _getGenderColor(String? gender) {
    if (gender == 'masculine' || gender == 'm') return AppTheme.genderMasc;
    if (gender == 'feminine' || gender == 'f') return AppTheme.genderFem;
    if (gender == 'neuter' || gender == 'n') return AppTheme.genderNeu;
    return Colors.indigo;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Vocabulary Review & Practice'),
        elevation: 0,
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
    return {
      'word': word.word,
      'pos': word.pos,
      'gender': word.gender,
      'definitions': word.definitions.isNotEmpty
          ? word.definitions
          : [word.primaryDefinition],
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
    final genderColor = _getGenderColor(word.gender);
    final example = _exampleFor(word);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      child: Column(
        children: [
          // Progress indicator
          LinearProgressIndicator(
            value: (_currentIndex + 1) / _dueWords.length,
            backgroundColor: Theme.of(
              context,
            ).dividerColor.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(genderColor),
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 16),

          // Main Flashcard Box
          Expanded(
            child: InkWell(
              onTap: () {
                setState(() {
                  _showAnswer = !_showAnswer;
                });
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
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: genderColor.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                // Front content (word + IPA) is pinned at the top and never
                // moves; only the region below it swaps between the hint and
                // the answer, so flipping the card can't shift the word.
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          word.word,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              _ttsService.speak(word.word, lang: 'de-DE'),
                          icon: Icon(
                            Icons.volume_up_rounded,
                            color: genderColor,
                          ),
                          tooltip: 'Play pronunciation',
                        ),
                      ],
                    ),

                    if (word.ipa != null && word.ipa!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        word.ipa!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainer,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    "Tap card to flip answer",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
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
                                    const Divider(height: 16),
                                    WordHeaderCard(
                                      wordData: _wordDataFor(word),
                                      contextSentence: example.german,
                                      wordImageFuture: _imageFutureFor(word),
                                      ipa: word.ipa,
                                      showStatusPills: false,
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
                                          fontStyle: FontStyle.italic,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            PageRouteBuilder(
                                              pageBuilder:
                                                  (
                                                    context,
                                                    animation,
                                                    secondaryAnimation,
                                                  ) => WordDetailScreen(
                                                    word: word.word,
                                                    wordData: _wordDataFor(
                                                      word,
                                                    ),
                                                  ),
                                              transitionsBuilder:
                                                  (
                                                    context,
                                                    animation,
                                                    secondaryAnimation,
                                                    child,
                                                  ) => FadeTransition(
                                                    opacity: animation,
                                                    child: child,
                                                  ),
                                              transitionDuration:
                                                  const Duration(
                                                    milliseconds: 200,
                                                  ),
                                            ),
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.menu_book_rounded,
                                          size: 18,
                                        ),
                                        label: const Text(
                                          'Explore in Dictionary →',
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 10,
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

          const SizedBox(height: 16),

          // Rating buttons: always present so the layout never resizes when
          // the card flips — only their opacity/interactivity changes.
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
                      rating: ReviewRating.again,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildRatingButton(
                      label: "Hard",
                      rating: ReviewRating.hard,
                      color: Colors.orange.shade800,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildRatingButton(
                      label: "Good",
                      rating: ReviewRating.good,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildRatingButton(
                      label: "Easy",
                      rating: ReviewRating.easy,
                      color: Colors.green.shade700,
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
    required ReviewRating rating,
    required Color color,
  }) {
    return ElevatedButton(
      onPressed: () => _rateCard(rating),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  Widget _buildCompletionCard() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.task_alt_rounded, size: 64, color: Colors.green),
              const SizedBox(height: 16),
              Text(
                'All Reviews Completed!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You are all caught up for today. Great job keeping your memory fresh!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Back to Home'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
