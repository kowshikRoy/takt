import 'package:flutter/material.dart';
import '../../models/grammar_lesson.dart';
import '../../theme/books_modernist_style.dart';

/// Card widget for conjugation & declension matrices.
class GrammarTableCard extends StatelessWidget {
  final TablePayload payload;
  final String? title;

  const GrammarTableCard({
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
                    Icons.table_chart_outlined,
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

          // Scrollable Matrix Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: borderColor, width: 1),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    isDark
                        ? const Color(0xFF2E2722)
                        : const Color(0xFFEDE5D8),
                  ),
                  dataRowColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return rustAccent.withValues(alpha: 0.1);
                    }
                    return isDark
                        ? const Color(0xFF221E1A)
                        : const Color(0xFFFAF6F0);
                  }),
                  dataRowMinHeight: 38,
                  dataRowMaxHeight: 46,
                  columnSpacing: 18,
                  horizontalMargin: 14,
                  border: TableBorder(
                    horizontalInside: BorderSide(
                      color: borderColor.withValues(alpha: 0.7),
                      width: 1,
                    ),
                    verticalInside: BorderSide(
                      color: borderColor.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  columns: payload.headers
                      .map((h) => DataColumn(
                            label: Text(
                              h,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: inkColor,
                              ),
                            ),
                          ))
                      .toList(),
                  rows: payload.rows.map((row) {
                    return DataRow(
                      cells: row.asMap().entries.map((cellEntry) {
                        final cellIdx = cellEntry.key;
                        final cell = cellEntry.value;
                        final isFirstCol = cellIdx == 0;
                        return DataCell(
                          Text(
                            cell,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: isFirstCol
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: isFirstCol
                                  ? rustAccent
                                  : inkColor.withValues(alpha: 0.9),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          if (payload.footnote != null && payload.footnote!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: rustAccent.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: rustAccent.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: rustAccent,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      payload.footnote!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: inkColor.withValues(alpha: 0.8),
                        height: 1.35,
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
