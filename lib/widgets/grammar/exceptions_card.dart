import 'package:flutter/material.dart';
import 'package:takt/l10n/app_localizations.dart';
import '../../models/grammar_lesson.dart';
import '../../theme/books_modernist_style.dart';

/// Card widget for grammar exceptions and special edge cases ("Achtung: Ausnahmen!").
class ExceptionsCard extends StatelessWidget {
  final List<ExceptionPayload> exceptions;
  final String? title;

  const ExceptionsCard({
    super.key,
    required this.exceptions,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF2A1D1A) : const Color(0xFFFFF2EF);
    final borderColor = isDark ? const Color(0xFF6B2D21) : const Color(0xFFF7C2B8);
    final inkColor = isDark ? const Color(0xFFEDE8E1) : const Color(0xFF1E1B18);
    const alertColor = Color(0xFFEC3013);

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
                  color: alertColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: alertColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title ?? l10n?.titleExceptions ?? 'Achtung: Ausnahmen!',
                  style: BooksModernist.heading(
                    size: 16,
                    color: isDark ? const Color(0xFFFF8A7A) : alertColor,
                    context: context,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          ...exceptions.map((ex) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ex.ruleName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: inkColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ex.description,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: inkColor.withValues(alpha: 0.85),
                  ),
                ),
                if (ex.exampleSentences.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1B1412)
                          : Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: borderColor.withValues(alpha: 0.8),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: ex.exampleSentences.map((s) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3.0),
                          child: Text(
                            s,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: inkColor,
                              height: 1.35,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }
}
