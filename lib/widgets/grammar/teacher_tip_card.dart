import 'package:flutter/material.dart';
import 'package:takt/l10n/app_localizations.dart';
import '../../models/grammar_lesson.dart';
import '../../theme/books_modernist_style.dart';

/// Card widget for teacher tips, warnings, and common student pitfalls ("Stolperfalle").
class TeacherTipCard extends StatelessWidget {
  final TipPayload payload;
  final String? title;

  const TeacherTipCard({
    super.key,
    required this.payload,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWarning = payload.isWarning;

    final cardBg = isWarning
        ? (isDark ? const Color(0xFF332312) : const Color(0xFFFFFBEB))
        : (isDark ? const Color(0xFF162B28) : const Color(0xFFF0FDF4));

    final borderColor = isWarning
        ? (isDark ? const Color(0xFF784F17) : const Color(0xFFFDE68A))
        : (isDark ? const Color(0xFF1E5246) : const Color(0xFFBBF7D0));

    final accentColor = isWarning
        ? (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706))
        : (isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A));

    final inkColor = isDark ? const Color(0xFFEDE8E1) : const Color(0xFF1E1B18);

    final defaultFallbackTitle = isWarning
        ? (l10n?.titleStolperfalle ?? 'Stolperfalle')
        : (l10n?.titleTeacherTip ?? 'Lehrer-Tipp');

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Icon(
                  isWarning
                      ? Icons.report_problem_outlined
                      : Icons.school_outlined,
                  color: accentColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  payload.title.isNotEmpty
                      ? payload.title
                      : (title ?? defaultFallbackTitle),
                  style: BooksModernist.heading(
                    size: 16,
                    color: accentColor,
                    context: context,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            payload.content,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: inkColor.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}
