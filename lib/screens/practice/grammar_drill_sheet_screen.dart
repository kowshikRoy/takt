import 'package:flutter/material.dart';
import '../../models/grammar_drill.dart';
import '../../services/grammar_drill_service.dart';
import '../../services/haptic_service.dart';
import '../../services/profile_service.dart';
import '../../services/sound_service.dart';
import '../../widgets/capped_width.dart';

class GrammarDrillSheetScreen extends StatefulWidget {
  final GrammarDrillSheet sheet;

  const GrammarDrillSheetScreen({super.key, required this.sheet});

  @override
  State<GrammarDrillSheetScreen> createState() => _GrammarDrillSheetScreenState();
}

class _GrammarDrillSheetScreenState extends State<GrammarDrillSheetScreen> {
  final GrammarDrillService _service = GrammarDrillService();
  final ScrollController _scrollController = ScrollController();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String?> _mcSelections = {};
  Map<String, bool> _blankResults = {};

  bool _isSubmitted = false;
  bool _activityRecorded = false;
  int _correctCount = 0;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    for (final question in widget.sheet.questions) {
      for (var i = 0; i < question.blanks.length; i++) {
        final blank = question.blanks[i];
        if (!blank.isMultipleChoice) {
          _controllers['${question.id}_$i'] = TextEditingController();
        }
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  String _answerFor(String key, GrammarDrillBlank blank) {
    if (blank.isMultipleChoice) return _mcSelections[key] ?? '';
    return _controllers[key]?.text ?? '';
  }

  void _checkAnswers() {
    if (!_activityRecorded) {
      ProfileService().recordActivityToday(review: true);
      _activityRecorded = true;
    }

    final results = <String, bool>{};
    int correct = 0;
    int total = 0;
    for (final question in widget.sheet.questions) {
      for (var i = 0; i < question.blanks.length; i++) {
        final blank = question.blanks[i];
        final key = '${question.id}_$i';
        total++;
        final userAnswer = _answerFor(key, blank).trim().toLowerCase();
        final isCorrect = userAnswer.isNotEmpty && userAnswer == blank.correctAnswer.trim().toLowerCase();
        results[key] = isCorrect;
        if (isCorrect) correct++;
      }
    }

    setState(() {
      _blankResults = results;
      _correctCount = correct;
      _totalCount = total;
      _isSubmitted = true;
    });

    final score = total == 0 ? 0.0 : correct / total;
    _service.saveBestScore(widget.sheet.id, score);

    if (score == 1.0) {
      SoundService().playLevelUp();
      AppHaptics.success();
    } else if (correct > 0) {
      SoundService().playCorrect();
      AppHaptics.selection();
    } else {
      SoundService().playIncorrect();
      AppHaptics.error();
    }

    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  void _tryAgain() {
    setState(() {
      _isSubmitted = false;
      _blankResults = {};
      _mcSelections.clear();
      for (final c in _controllers.values) {
        c.clear();
      }
      _correctCount = 0;
      _totalCount = 0;
    });
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        title: Text(
          widget.sheet.title,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      body: CappedWidth(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_isSubmitted) _buildScoreBanner(context),
                    if (_isSubmitted) const SizedBox(height: 16),
                    for (var i = 0; i < widget.sheet.questions.length; i++)
                      _buildQuestionCard(context, widget.sheet.questions[i], i),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: _isSubmitted
                    ? Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _tryAgain,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Theme.of(context).dividerColor),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              ),
                              child: Text(
                                'Try Again',
                                style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              ),
                              child: const Text(
                                'Done',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      )
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _checkAnswers,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                          child: const Text(
                            'Check Answers',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreBanner(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final percent = _totalCount == 0 ? 0 : ((_correctCount / _totalCount) * 100).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(Icons.checklist_rounded, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'You scored $_correctCount / $_totalCount ($percent%)',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(BuildContext context, GrammarDrillQuestion question, int index) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${index + 1}.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            question.prompt,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < question.blanks.length; i++) ...[
            if (question.blanks.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Blank ${i + 1}:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            _buildBlankInput(context, question, i),
            if (i < question.blanks.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildBlankInput(BuildContext context, GrammarDrillQuestion question, int blankIndex) {
    final blank = question.blanks[blankIndex];
    final key = '${question.id}_$blankIndex';
    final isCorrect = _isSubmitted ? _blankResults[key] : null;

    if (blank.isMultipleChoice) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: blank.options!.map((option) {
          final isSelected = _mcSelections[key] == option;
          return _buildChoiceChip(context, option, isSelected, isCorrect, option == blank.correctAnswer, () {
            if (_isSubmitted) return;
            setState(() => _mcSelections[key] = option);
          });
        }).toList(),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    Color borderColor = Theme.of(context).dividerColor;
    if (_isSubmitted) {
      borderColor = isCorrect == true ? Colors.green : Colors.red;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controllers[key],
          enabled: !_isSubmitted,
          decoration: InputDecoration(
            hintText: 'Type the answer...',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true,
            fillColor: _isSubmitted
                ? (isCorrect == true ? Colors.green.withValues(alpha: 0.08) : Colors.red.withValues(alpha: 0.08))
                : colorScheme.onSurface.withValues(alpha: 0.04),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
            ),
          ),
        ),
        if (blank.hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              '(${blank.hint})',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (_isSubmitted && isCorrect == false)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              'Correct: ${blank.correctAnswer}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red),
            ),
          ),
      ],
    );
  }

  Widget _buildChoiceChip(
    BuildContext context,
    String label,
    bool isSelected,
    bool? isCorrectSubmission,
    bool isTheCorrectAnswer,
    VoidCallback onTap,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    Color background = Theme.of(context).cardColor;
    Color border = Theme.of(context).dividerColor;
    Color textColor = colorScheme.onSurface;
    double borderWidth = 1;

    if (_isSubmitted) {
      if (isTheCorrectAnswer) {
        background = Colors.green.withValues(alpha: 0.1);
        border = Colors.green;
        textColor = Colors.green[800]!;
        borderWidth = isSelected ? 2 : 1;
      } else if (isSelected) {
        background = Colors.red.withValues(alpha: 0.1);
        border = Colors.red;
        textColor = Colors.red[800]!;
        borderWidth = 2;
      }
    } else if (isSelected) {
      background = colorScheme.primary.withValues(alpha: 0.08);
      border = colorScheme.primary;
      borderWidth = 2;
    }

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: border, width: borderWidth),
          ),
          child: Text(
            label,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
          ),
        ),
      ),
    );
  }
}
