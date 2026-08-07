import 'package:flutter/material.dart';
import '../../models/grammar_lesson.dart';
import '../../theme/books_modernist_style.dart';

/// Card widget for concept explanations and bullet point rules.
class ExplanationCard extends StatelessWidget {
  final ExplanationPayload payload;
  final String? title;

  const ExplanationCard({
    super.key,
    required this.payload,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF221E1A) : const Color(0xFFFAF6F0);
    final borderColor = isDark ? const Color(0xFF3D3730) : const Color(0xFFE5DDD0);
    final inkColor = isDark ? const Color(0xFFEDE8E1) : const Color(0xFF1E1B18);
    const rustAccent = Color(0xFF8C2D19);

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
          if (title != null && title!.trim().isNotEmpty) ...[
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: rustAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Icon(
                    Icons.lightbulb_outline_rounded,
                    color: rustAccent,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title!,
                    style: BooksModernist.heading(
                      size: 16,
                      color: inkColor,
                      context: context,
                    ).copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (payload.text.isNotEmpty)
            Text(
              payload.text,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.55,
                color: inkColor.withValues(alpha: 0.9),
              ),
            ),
          if (payload.bulletPoints != null && payload.bulletPoints!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1B1815)
                    : const Color(0xFFF2ECE1).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: borderColor.withValues(alpha: 0.6),
                  width: 1,
                ),
              ),
              child: Column(
                children: payload.bulletPoints!.map((point) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '• ',
                          style: TextStyle(
                            color: rustAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            height: 1.2,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            point,
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.45,
                              color: inkColor.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
