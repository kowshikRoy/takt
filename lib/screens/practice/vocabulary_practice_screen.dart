import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/saved_word.dart';
import '../../services/vocabulary_service.dart';
import '../../services/tts_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glance_word_sheet.dart';

class VocabularyPracticeScreen extends StatefulWidget {
  const VocabularyPracticeScreen({super.key});

  @override
  State<VocabularyPracticeScreen> createState() => _VocabularyPracticeScreenState();
}

class _VocabularyPracticeScreenState extends State<VocabularyPracticeScreen> {
  final VocabularyService _vocabService = VocabularyService();
  final TtsService _ttsService = TtsService();

  List<SavedWord> _dueWords = [];
  Map<String, int> _counts = {'learning': 0, 'mastered': 0, 'reviewLater': 0, 'dueToday': 0};
  int _currentIndex = 0;
  bool _showAnswer = false;
  bool _isLoading = true;

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
    }
  }

  Future<void> _rateCard(ReviewRating rating) async {
    if (_dueWords.isEmpty || _currentIndex >= _dueWords.length) return;
    final currentWord = _dueWords[_currentIndex];
    await _vocabService.recordReview(currentWord.id, rating);

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
              child: Column(
                children: [
                  _buildHeaderStats(),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _dueWords.isEmpty || _currentIndex >= _dueWords.length
                        ? _buildCompletionCard()
                        : _buildFlashcard(_dueWords[_currentIndex]),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderStats() {
    final totalWords = (_counts['learning'] ?? 0) + (_counts['mastered'] ?? 0) + (_counts['reviewLater'] ?? 0);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem("Due Today", "${_counts['dueToday'] ?? 0}", Colors.orange.shade800),
              _buildStatItem("Learning", "${_counts['learning'] ?? 0}", Colors.amber.shade800),
              _buildStatItem("Mastered", "${_counts['mastered'] ?? 0}", Colors.green.shade700),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            color: Theme.of(ctx).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'My Vocabulary (${allWords.length} Words)',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
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
                                w.word.isNotEmpty ? w.word[0].toUpperCase() : 'W',
                                style: TextStyle(color: color, fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(w.word, style: const TextStyle(fontWeight: FontWeight.bold)),
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
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
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
            backgroundColor: Theme.of(context).dividerColor.withOpacity(0.2),
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
              },
              borderRadius: BorderRadius.circular(24),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: genderColor.withOpacity(0.4), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: genderColor.withOpacity(0.08),
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
                          onPressed: () => _ttsService.speak(word.word, lang: 'de-DE'),
                          icon: Icon(Icons.volume_up_rounded, color: genderColor),
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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "Tap card to flip answer",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                      if (word.contextSentence != null && word.contextSentence!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          "\"${word.contextSentence}\"",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
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
            ).animate().fade(duration: 200.ms).slideY(begin: 0.2, end: 0)
          else
            const SizedBox(height: 48), // Spacer when not flipped
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_rounded, size: 48, color: Colors.green.shade700),
            ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
            const SizedBox(height: 20),
            Text(
              "All Caught Up!",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "You've completed all your scheduled reviews for today. Save new words from stories or videos to expand your queue!",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _loadDeck,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text("Refresh Queue"),
            ),
          ],
        ),
      ),
    );
  }
}
