import 'package:flutter/material.dart';
import 'package:takt/l10n/app_localizations.dart';
import '../../models/grammar_lesson.dart';
import '../../services/grammar_service.dart';
import '../../theme/books_modernist_style.dart';
import '../../widgets/capped_width.dart';
import '../../widgets/grammar/explanation_card.dart';
import '../../widgets/grammar/sentence_formula_card.dart';
import '../../widgets/grammar/grammar_table_card.dart';
import '../../widgets/grammar/example_sentences_card.dart';
import '../../widgets/grammar/exceptions_card.dart';
import '../../widgets/grammar/teacher_tip_card.dart';

class GrammarLessonScreen extends StatefulWidget {
  final GrammarLesson lesson;

  const GrammarLessonScreen({
    super.key,
    required this.lesson,
  });

  @override
  State<GrammarLessonScreen> createState() => _GrammarLessonScreenState();
}

class _GrammarLessonScreenState extends State<GrammarLessonScreen> {
  final GrammarService _grammarService = GrammarService();
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _isCompleted = _grammarService.isLessonCompleted(widget.lesson.id);
  }

  Future<void> _handleComplete() async {
    final success = await _grammarService.markLessonCompleted(widget.lesson.id);
    if (!mounted) return;

    setState(() {
      _isCompleted = true;
    });

    if (success) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.stars_rounded, color: Colors.amber, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n?.msgLessonCompletedXp ??
                      '🎉 Lektion abgeschlossen! +25 XP gutgeschrieben.',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1E1B18),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildSectionWidget(GrammarSection section) {
    return switch (section) {
      ExplanationSection(:final payload, :final title) =>
        ExplanationCard(payload: payload, title: title),
      FormulaSection(:final payload, :final title) =>
        SentenceFormulaCard(payload: payload, title: title),
      TableSection(:final payload, :final title) =>
        GrammarTableCard(payload: payload, title: title),
      ExamplesSection(:final examples, :final title) =>
        ExampleSentencesCard(examples: examples, title: title),
      ExceptionsSection(:final exceptions, :final title) =>
        ExceptionsCard(exceptions: exceptions, title: title),
      TipSection(:final payload, :final title) =>
        TeacherTipCard(payload: payload, title: title),
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF181614) : const Color(0xFFFAF6F0);
    final cardBg = isDark ? const Color(0xFF221E1A) : const Color(0xFFF2EEE7);
    final inkColor = isDark ? const Color(0xFFEDE8E1) : const Color(0xFF1E1B18);
    const rustAccent = Color(0xFF8C2D19);

    final lesson = widget.lesson;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: inkColor, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          lesson.title,
          style: BooksModernist.heading(
            size: 17,
            color: inkColor,
            context: context,
          ).copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_isCompleted)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF16A34A),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        AppLocalizations.of(context)?.labelLessonCompletedStatus ??
                            'Abgeschlossen',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: inkColor.withValues(alpha: 0.2),
            height: 1,
          ),
        ),
      ),
      body: CappedWidth(
        maxWidth: 720,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
          physics: const BouncingScrollPhysics(),
          children: [
            // Lesson Header Banner
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: inkColor.withValues(alpha: 0.2),
                  width: 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: rustAccent,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          lesson.level,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        lesson.category,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: inkColor.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    lesson.title,
                    style: BooksModernist.heading(
                      size: 22,
                      color: inkColor,
                      context: context,
                    ).copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (lesson.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      lesson.subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: rustAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (lesson.summary.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      lesson.summary,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                        color: inkColor.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Section Cards
            ...lesson.sections.map((section) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: _buildSectionWidget(section),
              );
            }),

            const SizedBox(height: 10),

            // Action / Complete Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isCompleted
                      ? (isDark ? const Color(0xFF263228) : const Color(0xFFE8F5E9))
                      : rustAccent,
                  foregroundColor: _isCompleted
                      ? const Color(0xFF16A34A)
                      : Colors.white,
                  elevation: 0,
                  side: BorderSide(
                    color: _isCompleted
                        ? const Color(0xFF16A34A)
                        : rustAccent,
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                onPressed: _handleComplete,
                icon: Icon(
                  _isCompleted
                      ? Icons.check_circle_rounded
                      : Icons.task_alt_rounded,
                  size: 22,
                ),
                label: Text(
                  _isCompleted
                      ? '${AppLocalizations.of(context)?.labelLessonCompletedStatus ?? 'Abgeschlossen'} (+25 XP)'
                      : (AppLocalizations.of(context)?.actionCompleteLesson ??
                          'Lektion verstanden & abschließen'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
