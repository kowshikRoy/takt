import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/sentence_exercise.dart';
import '../../services/sentence_practice_service.dart';

class SentencePracticeScreen extends StatefulWidget {
  const SentencePracticeScreen({super.key});

  @override
  State<SentencePracticeScreen> createState() => _SentencePracticeScreenState();
}

class _SentencePracticeScreenState extends State<SentencePracticeScreen> {
  late List<SentenceExercise> _exercises;
  int _currentIndex = 0;
  String? _selectedOption;
  bool _isChecked = false;
  bool _isCorrect = false;

  final SentencePracticeService _service = SentencePracticeService();

  @override
  void initState() {
    super.initState();
    _exercises = _service.getExercises();
  }

  void _checkAnswer() {
    if (_selectedOption == null) return;

    setState(() {
      _isChecked = true;
      _isCorrect = _selectedOption == _exercises[_currentIndex].correctAnswer;
    });
  }

  void _nextExercise() {
    if (_currentIndex < _exercises.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedOption = null;
        _isChecked = false;
        _isCorrect = false;
      });
    } else {
      // Finished
      Navigator.of(context).pop();
    }
  }

  Color _getCaseColor(GrammaticalCase gCase) {
    switch (gCase) {
      case GrammaticalCase.nominative:
        return Colors.blue;
      case GrammaticalCase.accusative:
        return const Color(0xFFF87171); // Red
      case GrammaticalCase.dative:
        return const Color(0xFFFACC15); // Yellow
      case GrammaticalCase.genitive:
        return Colors.green;
    }
  }

  Color _getCaseColorLight(GrammaticalCase gCase) {
    return _getCaseColor(gCase).withOpacity(0.2);
  }

  @override
  Widget build(BuildContext context) {
    final exercise = _exercises[_currentIndex];
    final progress = (_currentIndex + 1) / _exercises.length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          backgroundColor: Theme.of(context).dividerColor.withOpacity(0.3),
                          color: Theme.of(context).colorScheme.primary,
                          minHeight: 12,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: Row(
                      children: [
                        Icon(Icons.favorite, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 4),
                        Text('5',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Main Content Area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    // Image / Context
                    SizedBox(
                      height: 100,
                      child: Center(
                         child: _currentIndex == 0
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.asset('assets/images/cat.png', height: 80, errorBuilder: (c, e, s) => const SizedBox()),
                                    Image.asset('assets/images/sofa.png', height: 80, errorBuilder: (c, e, s) => const SizedBox()),
                                  ],
                                )
                              : const Icon(Icons.translate, size: 48, color: Colors.grey),
                      ),
                    ),

                    const Spacer(flex: 1),

                    // Question & Translation
                    Column(
                      children: [
                        Text(
                          'Translate this sentence',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          exercise.translation,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Tip
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isChecked && _isCorrect
                            ? _getCaseColorLight(exercise.targetCase)
                            : Theme.of(context).colorScheme.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: _isChecked && _isCorrect
                            ? Border.all(color: _getCaseColor(exercise.targetCase))
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lightbulb_outline,
                              color: _isChecked && _isCorrect
                                  ? _getCaseColor(exercise.targetCase)
                                  : Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              exercise.tip,
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Sentence Construction (The Fill-in-the-blank part)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: List.generate(exercise.sentenceParts.length, (index) {
                        if (index == exercise.missingIndex) {
                          if (_isChecked) {
                            // Show result state
                             return _buildWordChip(
                                context,
                                _isCorrect ? exercise.correctAnswer : (_selectedOption ?? ''),
                                isTarget: true,
                                targetColor: _isCorrect ? _getCaseColor(exercise.targetCase) : Colors.red,
                                isWrong: !_isCorrect
                             );
                          } else if (_selectedOption != null) {
                            return _buildWordChip(context, _selectedOption!,
                                isTarget: true, targetColor: Colors.grey);
                          } else {
                            return _buildEmptySlot(context);
                          }
                        } else {
                          return _buildWordChip(context, exercise.sentenceParts[index]);
                        }
                      }),
                    ),

                    const Spacer(flex: 2),

                    // Options Grid (Hidden if checked, or maybe keep it but disabled?)
                    // Hiding it to make space for feedback is good, or keep it to see what was clicked.
                    // User request: "fits into a single screen". Hiding makes it cleaner.
                    if (!_isChecked) ...[
                      Text(
                        'Choose the missing part:',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        // Important: Physics NeverScrollable ensures it doesn't try to scroll itself
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 3.0, // Flatter buttons to save space
                        children: exercise.options.map((option) {
                          return _buildChoiceButton(context, option,
                              isSelected: _selectedOption == option);
                        }).toList(),
                      ),
                       const Spacer(flex: 1),
                    ] else ...[
                       // Result Feedback Area when checked
                       Expanded(
                         child: Center(
                           child: Column(
                             mainAxisSize: MainAxisSize.min,
                             children: [
                               Icon(
                                 _isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                 size: 64,
                                 color: _isCorrect ? Colors.green : Colors.red,
                               ),
                               const SizedBox(height: 16),
                               Text(
                                 _isCorrect ? 'Correct!' : 'Incorrect',
                                 style: TextStyle(
                                   fontSize: 24,
                                   fontWeight: FontWeight.bold,
                                   color: _isCorrect ? Colors.green : Colors.red,
                                 ),
                               ),
                               if (!_isCorrect) ...[
                                 const SizedBox(height: 8),
                                 Text(
                                   'Correct answer:',
                                   style: TextStyle(
                                     color: Theme.of(context).colorScheme.onSurfaceVariant,
                                   ),
                                 ),
                                 Text(
                                   exercise.correctAnswer,
                                   style: TextStyle(
                                     fontSize: 20,
                                     fontWeight: FontWeight.bold,
                                     color: Theme.of(context).colorScheme.onSurface,
                                   ),
                                 ),
                               ]
                             ],
                           ),
                         ),
                       )
                    ]
                  ],
                ),
              ),
            ),

            // Bottom Bar
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_isChecked)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            onPressed: () {},
                            icon: Icon(Icons.flag_outlined,
                                color: Theme.of(context).colorScheme.onSurfaceVariant),
                            label: Text('Report',
                                style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          ),
                          TextButton.icon(
                            onPressed: _nextExercise,
                            label: Text('Skip',
                                style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
                            icon: Icon(Icons.skip_next,
                                color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isChecked
                          ? _nextExercise
                          : (_selectedOption != null ? _checkAnswer : null),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isChecked
                            ? (_isCorrect ? Colors.green : Colors.red)
                            : Theme.of(context).colorScheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        _isChecked
                            ? (_isCorrect ? 'Great! Next' : 'Got it')
                            : 'Check Answer',
                        style: const TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWordChip(BuildContext context, String word, {bool isTarget = false, Color? targetColor, bool isWrong = false}) {
    Color borderColor = Theme.of(context).dividerColor;
    Color bgColor = Theme.of(context).cardColor;
    Color textColor = Theme.of(context).colorScheme.onSurface;

    if (isTarget) {
      borderColor = targetColor ?? Theme.of(context).dividerColor;
      bgColor = (targetColor ?? Colors.transparent).withOpacity(0.1);
      textColor = targetColor ?? Theme.of(context).colorScheme.onSurface;
      if (isWrong) {
        // Strikethrough or shake effect visualization (static here)
        // We can use a red background/border as defined above.
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(
            color: borderColor,
            width: isTarget ? 2 : 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        word,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: textColor,
          decoration: isWrong ? TextDecoration.lineThrough : null,
          decorationColor: textColor,
        ),
      ),
    );
  }

  Widget _buildEmptySlot(BuildContext context) {
    return Container(
      width: 80,
      height: 48, // Slightly reduced height
      decoration: BoxDecoration(
        border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            width: 2,
            style: BorderStyle.solid),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildChoiceButton(BuildContext context, String text, {bool isSelected = false}) {
    return OutlinedButton(
      onPressed: () {
        setState(() {
          _selectedOption = text;
        });
      },
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected
            ? Theme.of(context).colorScheme.primary.withOpacity(0.05)
            : Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
            width: 2),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}
