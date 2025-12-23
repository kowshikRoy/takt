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
                        Text('5', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Main Content
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      // Main Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Theme.of(context).dividerColor),
                          boxShadow: const [
                            BoxShadow(
                              color: Color.fromRGBO(0, 0, 0, 0.1),
                              blurRadius: 15,
                              offset: Offset(0, 10),
                            )
                          ],
                        ),
                        child: Column(
                          children: [
                            // Images are hardcoded for now as they are not in the model.
                            // In a real app, images would be part of the exercise data.
                             if (_currentIndex == 0)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset('assets/images/cat.png', height: 80, errorBuilder: (c,e,s) => const SizedBox()),
                                  Image.asset('assets/images/sofa.png', height: 80, errorBuilder: (c,e,s) => const SizedBox()),
                                ],
                              )
                             else
                                const SizedBox(height: 80, child: Center(child: Icon(Icons.translate, size: 48, color: Colors.grey))),

                            const SizedBox(height: 16),
                            Text(
                              'Translate this sentence',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              exercise.translation,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                            ),
                          ],
                        ),
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
                          border: _isChecked && _isCorrect ? Border.all(color: _getCaseColor(exercise.targetCase)) : null,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.lightbulb_outline, color: _isChecked && _isCorrect ? _getCaseColor(exercise.targetCase) : Theme.of(context).colorScheme.primary),
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
                      // Sentence construction
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: List.generate(exercise.sentenceParts.length, (index) {
                          if (index == exercise.missingIndex) {
                            if (_isChecked && _isCorrect) {
                               return _buildWordChip(context, exercise.correctAnswer,
                                isTarget: true, targetColor: _getCaseColor(exercise.targetCase));
                            } else if (_selectedOption != null) {
                                return _buildWordChip(context, _selectedOption!, isTarget: true, targetColor: Colors.grey);
                            } else {
                                return _buildEmptySlot(context);
                            }
                          } else {
                            return _buildWordChip(context, exercise.sentenceParts[index]);
                          }
                        }),
                      ),
                      const SizedBox(height: 40), // Spacer
                      // Choices
                      if (!_isChecked) ...[
                        Text(
                          'Choose the missing part:',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 16),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 2.5,
                          children: exercise.options.map((option) {
                            return _buildChoiceButton(context, option, isSelected: _selectedOption == option);
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_isChecked)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () {},
                    icon: Icon(Icons.flag_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    label: Text('Report', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ),
                  TextButton.icon(
                    onPressed: _nextExercise,
                    label: Text('Skip', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    icon: Icon(Icons.skip_next, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            if (!_isChecked) const SizedBox(height: 12),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  _isChecked
                    ? (_isCorrect ? 'Great! Next' : 'Got it')
                    : 'Check Answer',
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
            if (_isChecked && !_isCorrect)
             Padding(
               padding: const EdgeInsets.only(top: 8.0),
               child: Text(
                 'Correct answer: ${exercise.correctAnswer}',
                 style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
               ),
             )
          ],
        ),
      ),
    );
  }

  Widget _buildWordChip(BuildContext context, String word, {bool isTarget = false, Color? targetColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isTarget ? (targetColor ?? Colors.transparent).withOpacity(0.1) : Theme.of(context).cardColor,
        border: Border.all(color: isTarget ? (targetColor ?? Theme.of(context).dividerColor) : Theme.of(context).dividerColor, width: isTarget ? 2 : 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        word,
        style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isTarget ? (targetColor ?? Theme.of(context).colorScheme.onSurface) : Theme.of(context).colorScheme.onSurface
        ),
      ),
    );
  }

  Widget _buildEmptySlot(BuildContext context) {
    return Container(
      width: 80,
      height: 50,
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.5), width: 2, style: BorderStyle.solid),
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
        backgroundColor: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.05) : Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor, width: 2),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}
