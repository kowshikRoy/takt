import 'package:flutter/material.dart';
import '../../models/grammar_lesson.dart';
import '../../theme/books_modernist_style.dart';

/// Card widget for German word order & Satzklammer (Sentence Brackets).
class SentenceFormulaCard extends StatelessWidget {
  final FormulaPayload payload;
  final String? title;

  const SentenceFormulaCard({
    super.key,
    required this.payload,
    this.title,
  });

  Color _getBlockBgColor(BuildContext context, String? tag, bool isDark) {
    switch (tag) {
      case 'primary':
        return isDark
            ? const Color(0xFF3B1E1A)
            : const Color(0xFFFDE8E4); // Red/Rust accent
      case 'warning':
        return isDark
            ? const Color(0xFF3E2805)
            : const Color(0xFFFEF3C7); // Amber/Yellow
      case 'accent':
        return isDark
            ? const Color(0xFF142E3D)
            : const Color(0xFFE0F2FE); // Blue/Sky accent
      default:
        return isDark
            ? const Color(0xFF26221E)
            : const Color(0xFFF4EEE5); // Neutral
    }
  }

  Color _getBlockBorderColor(BuildContext context, String? tag, bool isDark) {
    switch (tag) {
      case 'primary':
        return const Color(0xFF8C2D19);
      case 'warning':
        return const Color(0xFFD97706);
      case 'accent':
        return const Color(0xFF0284C7);
      default:
        return isDark ? const Color(0xFF453E36) : const Color(0xFFD8CEBF);
    }
  }

  Color _getBlockTextColor(BuildContext context, String? tag, bool isDark) {
    switch (tag) {
      case 'primary':
        return isDark ? const Color(0xFFFFB4A4) : const Color(0xFF8C2D19);
      case 'warning':
        return isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E);
      case 'accent':
        return isDark ? const Color(0xFFBAE6FD) : const Color(0xFF0369A1);
      default:
        return isDark ? const Color(0xFFEDE8E1) : const Color(0xFF2E2A25);
    }
  }

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
                    Icons.view_column_outlined,
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
            const SizedBox(height: 14),
          ],

          // Spatial sentence map (Blocks)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: payload.blocks.asMap().entries.map((entry) {
                final idx = entry.key;
                final block = entry.value;
                final bg = _getBlockBgColor(context, block.colorTag, isDark);
                final border = _getBlockBorderColor(context, block.colorTag, isDark);
                final text = _getBlockTextColor(context, block.colorTag, isDark);

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      constraints: const BoxConstraints(minWidth: 100),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: border, width: 1.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: border.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Text(
                              block.position.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: text,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            block.exampleWord,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: text,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            block.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: text.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (idx < payload.blocks.length - 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: inkColor.withValues(alpha: 0.4),
                        ),
                      ),
                  ],
                );
              }).toList(),
            ),
          ),

          if (payload.formulaStructure.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1B1815)
                    : const Color(0xFFF2ECE1).withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: borderColor.withValues(alpha: 0.7),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.account_tree_outlined,
                    size: 16,
                    color: rustAccent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      payload.formulaStructure,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                        color: inkColor.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
