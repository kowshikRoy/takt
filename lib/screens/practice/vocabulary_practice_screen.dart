import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/saved_word.dart';
import '../../models/xp_event.dart';
import '../../services/vocabulary_service.dart';
import '../../services/dictionary_service.dart';
import '../../services/tts_service.dart';
import '../../services/gamification_service.dart';
import '../../services/sound_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glance_word_sheet.dart';
import '../../widgets/capped_width.dart';

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
  Map<String, int> _counts = {
    'learning': 0,
    'mastered': 0,
    'reviewLater': 0,
    'dueToday': 0,
  };
  int _currentIndex = 0;
  bool _showAnswer = false;
  bool _isLoading = true;
  final Map<String, Map<String, String?>> _exampleCache = {};

  @override
  void initState() {
    super.initState();
    _loadDeck();
  }

  Future<void> _loadDeck() async {
    setState(() => _isLoading = true);
    final due = await _vocabService.getDueWords();
    final counts = await _vocabService.getCategoryCounts();
    if (mounted) {
      setState(() {
        _dueWords = due;
        _counts = counts;
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
          final examples = await _dictionaryService.getExamplesForWord(word.word);
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
        title: const Text('Spaced Repetition & Practice'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: CappedWidth(
                child: Column(
                  children: [
                    _buildHeaderStats(),
                    const SizedBox(height: 12),
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

  Widget _buildHeaderStats() {
    final totalWords =
        (_counts['learning'] ?? 0) +
        (_counts['mastered'] ?? 0) +
        (_counts['reviewLater'] ?? 0);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                "Due Today",
                "${_counts['dueToday'] ?? 0}",
                Colors.orange.shade800,
              ),
              _buildStatItem(
                "Learning",
                "${_counts['learning'] ?? 0}",
                Colors.amber.shade800,
              ),
              _buildStatItem(
                "Mastered",
                "${_counts['mastered'] ?? 0}",
                Colors.green.shade700,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showSavedWordsDialog(context),
              icon: const Icon(Icons.menu_book_rounded, size: 18),
              label: Text("📖 Browse My Vocabulary List ($totalWords Words)"),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSavedWordsDialog(BuildContext context) async {
    final allWords = await _vocabService.getSavedWords();
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.8,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'All Saved Words (${allWords.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: allWords.isEmpty
                    ? const Center(child: Text('No saved vocabulary yet!'))
                    : ListView.builder(
                        itemCount: allWords.length,
                        itemBuilder: (ctx, index) {
                          final w = allWords[index];
                          final color = _getGenderColor(w.gender);
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: color.withValues(alpha: 0.2),
                              child: Text(
                                w.word.isNotEmpty
                                    ? w.word[0].toUpperCase()
                                    : 'W',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              w.word,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${w.category.name.toUpperCase()} • Interval: ${w.interval}d • Ease: ${w.easeFactor.toStringAsFixed(1)}x',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () {
                              Navigator.pop(ctx);
                              GlanceWordSheet.show(context, word: w.word);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildExampleSentence(SavedWord word) {
    String? german = word.contextSentence;
    String? english;

    final lower = word.word.toLowerCase().trim();
    if ((german == null || german.isEmpty) && _exampleCache.containsKey(lower)) {
      german = _exampleCache[lower]!['de'];
      english = _exampleCache[lower]!['en'];
    }

    if (german == null || german.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.format_quote_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                'EXAMPLE SENTENCE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => _ttsService.speak(german!, lang: 'de-DE'),
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.volume_up_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '"$german"',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          if (english != null && english.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              english,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFlashcard(SavedWord word) {
    final genderColor = _getGenderColor(word.gender);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Progress indicator
          LinearProgressIndicator(
            value: (_currentIndex + 1) / _dueWords.length,
            backgroundColor: Theme.of(context).dividerColor.withValues(alpha: 0.2),
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
                if (_showAnswer && (word.contextSentence == null || word.contextSentence!.isEmpty)) {
                  final lower = word.word.toLowerCase().trim();
                  if (!_exampleCache.containsKey(lower)) {
                    _dictionaryService.getExamplesForWord(word.word).then((examples) {
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
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: genderColor.withValues(alpha: 0.4),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: genderColor.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
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

                    const SizedBox(height: 24),

                    if (!_showAnswer) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(12),
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
                    ] else ...[
                      const Divider(),
                      const SizedBox(height: 12),
                      Text(
                        word.primaryDefinition,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      _buildExampleSentence(word),
                    ],
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Rating buttons (Shown when card is flipped)
          if (_showAnswer)
            Row(
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
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
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.task_alt_rounded,
                size: 64,
                color: Colors.green,
              ),
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
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to Home'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
