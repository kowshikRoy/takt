import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../models/daily_challenge_question.dart';
import '../../services/daily_challenge_service.dart';
import '../../services/gender_practice_data_source.dart';
import '../../services/vocabulary_service.dart';
import '../../services/sound_service.dart';
import '../../services/haptic_service.dart';
import '../../services/profile_service.dart';
import '../../models/saved_word.dart';
import '../../widgets/capped_width.dart';

/// A single combined practice session pulling questions from the vocabulary SRS,
/// gender quiz, compound-word, and sentence-case modules — one daily action instead
/// of four separate screens. Each question type keeps its own answer side effect
/// (real SRS updates for vocab/gender, local scoring for compound/sentence), and every
/// answered question counts toward the app's existing daily-goal/streak system via
/// [ProfileService.recordActivityToday].
class DailyChallengeScreen extends StatefulWidget {
  const DailyChallengeScreen({super.key});

  @override
  State<DailyChallengeScreen> createState() => _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends State<DailyChallengeScreen> {
  final DailyChallengeService _challengeService = DailyChallengeService();
  final GenderPracticeDataSource _genderDataSource = GenderPracticeDataSource();
  final VocabularyService _vocabularyService = VocabularyService();

  List<DailyChallengeQuestion> _questions = [];
  bool _isLoading = true;
  int _currentIndex = 0;
  int _score = 0;
  bool _isAnswered = false;
  bool _isFinished = false;
  String? _selectedOption;
  int _streak = 0;

  // Per-type breakdown for the completion screen.
  final Map<Type, int> _correctByType = {};
  final Map<Type, int> _totalByType = {};

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    setState(() => _isLoading = true);
    final questions = await _challengeService.buildSession();
    if (!mounted) return;
    setState(() {
      _questions = questions;
      _currentIndex = 0;
      _score = 0;
      _isAnswered = false;
      _isFinished = false;
      _selectedOption = null;
      _streak = 0;
      _correctByType.clear();
      _totalByType.clear();
      _isLoading = false;
    });
  }

  DailyChallengeQuestion get _current => _questions[_currentIndex];

  Future<void> _handleAnswer(String selected, bool isCorrect) async {
    if (_isAnswered) return;

    setState(() {
      _selectedOption = selected;
      _isAnswered = true;
      if (isCorrect) {
        _score++;
        _streak++;
      } else {
        _streak = 0;
      }
      final type = _current.runtimeType;
      _totalByType[type] = (_totalByType[type] ?? 0) + 1;
      if (isCorrect) {
        _correctByType[type] = (_correctByType[type] ?? 0) + 1;
      }
    });

    if (isCorrect) {
      SoundService().playCorrect();
      AppHaptics.success();
    } else {
      SoundService().playIncorrect();
      AppHaptics.error();
    }

    // Real SRS/scoring side effects per question type.
    switch (_current) {
      case VocabDefinitionQuestion q:
        await _vocabularyService.recordReview(
          q.word.id,
          isCorrect ? (_streak >= 3 ? ReviewRating.easy : ReviewRating.good) : ReviewRating.again,
        );
      case GenderQuestion q:
        await _genderDataSource.recordSrsReview(q.noun, isCorrect, countsAsEasy: _streak >= 3);
      case CompoundQuestion _:
      case SentenceCaseQuestion _:
        break; // local scoring only, matching the standalone screens for these types
    }

    // Every answered question counts toward today's activity, same call every
    // existing practice screen already makes — plugs into streaks/heatmap/daily
    // goal with no new state.
    ProfileService().recordActivityToday(review: true);
  }

  void _next() {
    if (_currentIndex + 1 < _questions.length) {
      setState(() {
        _currentIndex++;
        _isAnswered = false;
        _selectedOption = null;
      });
    } else {
      setState(() => _isFinished = true);
      SoundService().playLevelUp();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CappedWidth(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _questions.isEmpty
                  ? _buildEmptyState(context)
                  : _isFinished
                      ? _buildCompletionScreen(context)
                      : Stack(
                          children: [
                            Column(
                              children: [
                                _buildHeader(context),
                                Expanded(
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 128),
                                    child: _buildQuestionBody(context),
                                  ),
                                ),
                              ],
                            ),
                            _buildBottomBar(context),
                          ],
                        ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt_rounded, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              "Nothing to challenge you with yet — save a few words or come back once you have reviews due.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final progress = (_currentIndex + (_isAnswered ? 1 : 0)) / _questions.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.close_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
            tooltip: 'Close',
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                color: Theme.of(context).colorScheme.primary,
                minHeight: 12,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Text(
              '${_currentIndex + 1}/${_questions.length}',
              style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionBody(BuildContext context) {
    return switch (_current) {
      VocabDefinitionQuestion q => _buildVocabQuestion(context, q),
      GenderQuestion q => _buildGenderQuestion(context, q),
      CompoundQuestion q => _buildCompoundQuestion(context, q),
      SentenceCaseQuestion q => _buildSentenceQuestion(context, q),
    };
  }

  Widget _questionLabel(BuildContext context, String label) {
    return Text(
      label,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildVocabQuestion(BuildContext context, VocabDefinitionQuestion q) {
    return Column(
      children: [
        _questionLabel(context, 'VOCABULARY'),
        const SizedBox(height: 12),
        Text(
          q.word.word,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
        ),
        const SizedBox(height: 8),
        Text(
          'Which meaning is correct?',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 32),
        ...q.options.map((opt) => _buildOptionTile(context, opt, opt == q.correctOption)),
      ],
    );
  }

  Widget _buildCompoundQuestion(BuildContext context, CompoundQuestion q) {
    return Column(
      children: [
        _questionLabel(context, 'COMPOUND WORD'),
        const SizedBox(height: 12),
        Text(
          q.compound.fullWord,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
        ),
        Text(
          '${q.compound.part1Subtitle} + ${q.compound.part2Subtitle}',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Text('What does it mean?', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 32),
        ...q.options.map((opt) => _buildOptionTile(context, opt, opt == q.compound.fullMeaning)),
      ],
    );
  }

  Widget _buildOptionTile(BuildContext context, String text, bool isCorrectOption) {
    Color background = Theme.of(context).cardColor;
    Color border = Theme.of(context).dividerColor;
    Color textColor = Theme.of(context).colorScheme.onSurface;

    if (_isAnswered) {
      if (isCorrectOption) {
        background = Colors.green.withValues(alpha: 0.08);
        border = Colors.green;
        textColor = Colors.green[800]!;
      } else if (text == _selectedOption) {
        background = Colors.red.withValues(alpha: 0.08);
        border = Colors.red;
        textColor = Colors.red[800]!;
      } else {
        textColor = textColor.withValues(alpha: 0.5);
      }
    }

    return Padding(
      key: ValueKey('option_$text'),
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: _isAnswered ? null : () => _handleAnswer(text, isCorrectOption),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: border, width: _isAnswered && (isCorrectOption || text == _selectedOption) ? 2 : 1),
            ),
            child: Text(text, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor)),
          ),
        ),
      ),
    );
  }

  Color _genderColor(String code) {
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

  Widget _buildGenderQuestion(BuildContext context, GenderQuestion q) {
    final noun = q.noun;
    return Column(
      children: [
        _questionLabel(context, 'GENDER'),
        const SizedBox(height: 12),
        Text(
          noun.word,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
        ),
        const SizedBox(height: 8),
        Text(noun.translation, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 32),
        Row(
          children: [
            _buildGenderButton(context, 'Der', 'm', noun.genderCode),
            const SizedBox(width: 12),
            _buildGenderButton(context, 'Die', 'f', noun.genderCode),
            const SizedBox(width: 12),
            _buildGenderButton(context, 'Das', 'n', noun.genderCode),
          ],
        ),
      ],
    );
  }

  Widget _buildGenderButton(BuildContext context, String label, String code, String correctCode) {
    final color = _genderColor(code);
    final isCorrectAnswer = code == correctCode;
    final isSelected = code == _selectedOption;

    Color background = Theme.of(context).cardColor;
    Color border = color.withValues(alpha: 0.4);
    Color textColor = color;

    if (_isAnswered) {
      if (isCorrectAnswer) {
        background = color;
        textColor = Colors.white;
        border = color;
      } else if (isSelected) {
        background = Colors.red.withValues(alpha: 0.08);
        border = Colors.red;
        textColor = Colors.red[800]!;
      } else {
        textColor = textColor.withValues(alpha: 0.4);
      }
    }

    return Expanded(
      key: ValueKey('gender_$code'),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: _isAnswered ? null : () => _handleAnswer(code, isCorrectAnswer),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), border: Border.all(color: border, width: 2)),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSentenceQuestion(BuildContext context, SentenceCaseQuestion q) {
    final exercise = q.exercise;
    return Column(
      children: [
        _questionLabel(context, 'SENTENCE CASE'),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < exercise.sentenceParts.length; i++)
              if (i == exercise.missingIndex)
                Container(
                  width: 70,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6), width: 2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _selectedOption ?? '___',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(exercise.sentenceParts[i], style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
          ],
        ),
        const SizedBox(height: 8),
        Text(exercise.translation, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic)),
        const SizedBox(height: 28),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: exercise.options
              .map((opt) => SizedBox(
                    width: 90,
                    child: _buildOptionTile(context, opt, opt == exercise.correctAnswer),
                  ))
              .toList(),
        ),
        if (_isAnswered) ...[
          const SizedBox(height: 12),
          Text(exercise.tip, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 13)),
        ],
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isAnswered ? _next : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isAnswered ? Theme.of(context).colorScheme.primary : Theme.of(context).disabledColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: Text(
              _isAnswered ? (_currentIndex + 1 >= _questions.length ? 'Finish' : 'Continue') : 'Select an answer',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _isAnswered ? Colors.white : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _typeLabel(Type t) {
    switch (t) {
      case const (VocabDefinitionQuestion):
        return 'Vocabulary';
      case const (GenderQuestion):
        return 'Gender';
      case const (CompoundQuestion):
        return 'Compound words';
      case const (SentenceCaseQuestion):
        return 'Sentence case';
      default:
        return t.toString();
    }
  }

  Widget _buildCompletionScreen(BuildContext context) {
    final accuracy = _questions.isEmpty ? 0 : ((_score / _questions.length) * 100).round();
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, shape: BoxShape.circle),
              child: Icon(Icons.emoji_events_rounded, size: 44, color: Theme.of(context).colorScheme.primary),
            ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
            const SizedBox(height: 24),
            Text('Challenge Complete!', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(children: [
                    Text('$_score / ${_questions.length}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                    const SizedBox(height: 4),
                    Text('Correct', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ]),
                  Container(width: 1, height: 40, color: Theme.of(context).dividerColor),
                  Column(children: [
                    Text('$accuracy%', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary)),
                    const SizedBox(height: 4),
                    Text('Accuracy', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ..._totalByType.entries.map((e) {
              final correct = _correctByType[e.key] ?? 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_typeLabel(e.key), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
                    Text('$correct/${e.value}', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Theme.of(context).colorScheme.onSurface)),
                  ],
                ),
              );
            }),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loadSession,
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
                child: const Text('Practice Again', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
                child: Text('Done', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
