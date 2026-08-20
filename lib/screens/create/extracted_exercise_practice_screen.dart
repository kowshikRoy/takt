import 'package:flutter/material.dart';
import '../../models/image_extraction_result.dart';
import '../../services/haptic_service.dart';
import '../../services/profile_service.dart';
import '../../services/sound_service.dart';
import '../../theme/books_modernist_style.dart';
import '../../widgets/capped_width.dart';
import '../../widgets/interactive_german_text.dart';

/// Interactive practice screen for exercises extracted from images or textbook pages.
/// Follows the Books/Textbook Modernist design system with step-by-step answering,
/// instant feedback, case/reason explanation on completion, and progress tracking.
class ExtractedExercisePracticeScreen extends StatefulWidget {
  final ExtractedExercise exercise;

  const ExtractedExercisePracticeScreen({super.key, required this.exercise});

  @override
  State<ExtractedExercisePracticeScreen> createState() =>
      _ExtractedExercisePracticeScreenState();
}

class _ExtractedExercisePracticeScreenState
    extends State<ExtractedExercisePracticeScreen> {
  int _currentIndex = 0;
  String? _selectedOption;
  bool _isChecked = false;
  bool _isCorrect = false;
  int _score = 0;
  bool _isFinished = false;

  final Map<int, String> _userAnswers = {};

  List<ExtractedExerciseStatement> get _statements => widget.exercise.statements;

  ExtractedExerciseStatement get _currentStatement => _statements[_currentIndex];

  void _onSelectOption(String option) {
    if (_isChecked) return;
    AppHaptics.selection();
    setState(() {
      _selectedOption = option;
    });
  }

  void _checkAnswer() {
    if (_selectedOption == null || _isChecked) return;

    final correctAns = _currentStatement.answer.trim().toLowerCase();
    final userAns = _selectedOption!.trim().toLowerCase();
    final isCorrect = userAns == correctAns;

    setState(() {
      _isChecked = true;
      _isCorrect = isCorrect;
      _userAnswers[_currentIndex] = _selectedOption!;
      if (isCorrect) {
        _score++;
      }
    });

    ProfileService().recordActivityToday(review: true);

    if (isCorrect) {
      SoundService().playCorrect();
      AppHaptics.success();
    } else {
      SoundService().playIncorrect();
      AppHaptics.error();
    }
  }

  void _nextStatement() {
    if (_currentIndex < _statements.length - 1) {
      AppHaptics.light();
      setState(() {
        _currentIndex++;
        _selectedOption = null;
        _isChecked = false;
        _isCorrect = false;
      });
    } else {
      AppHaptics.heavy();
      setState(() {
        _isFinished = true;
      });
    }
  }

  void _restart() {
    setState(() {
      _currentIndex = 0;
      _selectedOption = null;
      _isChecked = false;
      _isCorrect = false;
      _score = 0;
      _isFinished = false;
      _userAnswers.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = BooksModernist.readingTheme(context);

    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: BooksModernist.bg,
        appBar: AppBar(
          backgroundColor: BooksModernist.bg,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: BooksModernist.text),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.exercise.title,
            style: BooksModernist.heading(size: 16, color: BooksModernist.text),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: CappedWidth(
            maxWidth: 600,
            child: _isFinished ? _buildSummaryView() : _buildQuestionView(),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionView() {
    final statement = _currentStatement;
    final total = _statements.length;
    final progress = (_currentIndex + 1) / total;

    final text = statement.text;
    final rawBlank = _isChecked
        ? _selectedOption!
        : (_selectedOption ?? '________');

    final formattedSentence = text.contains('...')
        ? text.replaceFirst('...', rawBlank)
        : (text.contains('___')
            ? text.replaceFirst(RegExp(r'_{2,}'), rawBlank)
            : (text.contains('_____')
                ? text.replaceFirst('_____', rawBlank)
                : (_selectedOption != null ? '$_selectedOption $text' : '________ $text')));

    final options = widget.exercise.options;

    return Column(
      children: [
        // Progress bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Frage ${_currentIndex + 1} von $total',
                    style: BooksModernist.body(
                      size: 12,
                      weight: FontWeight.w700,
                      color: BooksModernist.text.withValues(alpha: 0.6),
                    ),
                  ),
                  Text(
                    'Punkte: $_score',
                    style: BooksModernist.body(
                      size: 12,
                      weight: FontWeight.w700,
                      color: BooksModernist.accentDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: BooksModernist.surface,
                  valueColor: const AlwaysStoppedAnimation<Color>(BooksModernist.accent),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Instruction banner
                if (widget.exercise.instruction.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: BooksModernist.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: BooksModernist.dividerThin),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.help_outline_rounded,
                            size: 16, color: BooksModernist.accentDark),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.exercise.instruction,
                            style: BooksModernist.body(
                              size: 12.5,
                              weight: FontWeight.w600,
                              color: BooksModernist.accentDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Sentence Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: BooksModernist.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isChecked
                          ? (_isCorrect ? BooksModernist.accent : Colors.red.shade700)
                          : BooksModernist.divider,
                      width: _isChecked ? 1.8 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${statement.id}. ',
                            style: BooksModernist.heading(
                              size: 17,
                              color: BooksModernist.accentDark,
                            ),
                          ),
                          Expanded(
                            child: InteractiveGermanText(
                              formattedSentence,
                              sourceTitle: widget.exercise.title,
                              style: BooksModernist.body(
                                size: 17,
                                weight: _selectedOption != null
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          if (_isChecked) ...[
                            const SizedBox(width: 8),
                            Icon(
                              _isCorrect
                                  ? Icons.check_circle_rounded
                                  : Icons.cancel_rounded,
                              color: _isCorrect
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                              size: 24,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Option Pool Title
                Text(
                  'Wähle die passende Antwort:',
                  style: BooksModernist.body(
                    size: 13,
                    weight: FontWeight.w700,
                    color: BooksModernist.text.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 12),

                // Options Wrap / Grid
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: options.map((opt) {
                    final isSelected = _selectedOption == opt;
                    Color btnBg = BooksModernist.surface;
                    Color btnBorder = BooksModernist.divider;
                    Color textColor = BooksModernist.text;

                    if (_isChecked) {
                      final isCorrectOption =
                          opt.trim().toLowerCase() == statement.answer.trim().toLowerCase();
                      if (isCorrectOption) {
                        btnBg = Colors.green.shade50;
                        btnBorder = Colors.green.shade700;
                        textColor = Colors.green.shade900;
                      } else if (isSelected && !_isCorrect) {
                        btnBg = Colors.red.shade50;
                        btnBorder = Colors.red.shade700;
                        textColor = Colors.red.shade900;
                      }
                    } else if (isSelected) {
                      btnBg = BooksModernist.accent;
                      btnBorder = BooksModernist.accent;
                      textColor = Colors.white;
                    }

                    return InkWell(
                      onTap: _isChecked ? null : () => _onSelectOption(opt),
                      borderRadius: BorderRadius.circular(6),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: btnBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: btnBorder, width: isSelected ? 2 : 1),
                        ),
                        child: Text(
                          opt,
                          style: BooksModernist.title(
                            size: 16,
                            weight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                // Explanation Banner (Shown after answering)
                if (_isChecked) ...[
                  const SizedBox(height: 20),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _isCorrect
                          ? Colors.green.shade50
                          : Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isCorrect
                            ? Colors.green.shade300
                            : Colors.amber.shade400,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isCorrect
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.info_outline_rounded,
                              size: 18,
                              color: _isCorrect
                                  ? Colors.green.shade800
                                  : Colors.amber.shade900,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isCorrect ? 'Richtig!' : 'Richtige Antwort: ${statement.answer}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: _isCorrect
                                    ? Colors.green.shade900
                                    : Colors.amber.shade900,
                              ),
                            ),
                          ],
                        ),
                        if (statement.explanation != null &&
                            statement.explanation!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            statement.explanation!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Bottom Action Button
        Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _selectedOption == null
                  ? null
                  : (_isChecked ? _nextStatement : _checkAnswer),
              style: ElevatedButton.styleFrom(
                backgroundColor: BooksModernist.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Text(
                !_isChecked
                    ? 'Antwort prüfen'
                    : (_currentIndex < _statements.length - 1
                        ? 'Nächste Frage'
                        : 'Übung abschließen'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryView() {
    final total = _statements.length;
    final pct = total > 0 ? (_score / total * 100).round() : 0;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: BooksModernist.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              pct >= 70 ? Icons.emoji_events_rounded : Icons.replay_rounded,
              size: 64,
              color: BooksModernist.accent,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            pct >= 70 ? 'Ausgezeichnet!' : 'Gute Übung!',
            style: BooksModernist.heading(size: 24, color: BooksModernist.text),
          ),
          const SizedBox(height: 8),
          Text(
            'Du hast $_score von $total Fragen richtig beantwortet ($pct%).',
            textAlign: TextAlign.center,
            style: BooksModernist.body(
              size: 15,
              color: BooksModernist.text.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 36),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _restart,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: BooksModernist.accent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: Text(
                    'Nochmal üben',
                    style: BooksModernist.heading(
                      size: 15,
                      color: BooksModernist.accentDark,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: BooksModernist.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    'Fertig',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
