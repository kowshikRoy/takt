import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/saved_word.dart';
import '../../l10n/app_localizations.dart';

class ModernistActivityHeatmap extends StatefulWidget {
  final List<SavedWord> words;
  final Color? accentColor;

  const ModernistActivityHeatmap({
    super.key,
    required this.words,
    this.accentColor,
  });

  @override
  State<ModernistActivityHeatmap> createState() => _ModernistActivityHeatmapState();
}

class _ModernistActivityHeatmapState extends State<ModernistActivityHeatmap> {
  DateTime? _selectedDate;
  int? _selectedCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final inkColor = isDark ? const Color(0xFFEDE8E1) : const Color(0xFF1E1B18);
    final cardBg = isDark ? const Color(0xFF221E1A) : const Color(0xFFF2EEE7);
    final rustAccent = widget.accentColor ?? (isDark ? const Color(0xFFE05338) : const Color(0xFF8C2D19));

    final Map<String, int> dailyCounts = {};
    for (final w in widget.words) {
      final key = '${w.createdAt.year}-${w.createdAt.month}-${w.createdAt.day}';
      dailyCounts[key] = (dailyCounts[key] ?? 0) + 1;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: inkColor.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n?.title12WeekActivity ?? '12-WEEK ACTIVITY',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                  color: inkColor,
                ),
              ),
              Row(
                children: [
                  Text(
                    'Less ',
                    style: TextStyle(
                      fontSize: 10,
                      color: inkColor.withValues(alpha: 0.5),
                    ),
                  ),
                  _buildLegendSquare(0, rustAccent, inkColor),
                  const SizedBox(width: 3),
                  _buildLegendSquare(1, rustAccent, inkColor),
                  const SizedBox(width: 3),
                  _buildLegendSquare(2, rustAccent, inkColor),
                  const SizedBox(width: 3),
                  _buildLegendSquare(3, rustAccent, inkColor),
                  Text(
                    ' More',
                    style: TextStyle(
                      fontSize: 10,
                      color: inkColor.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Selected Day Feedback Pill (when a square is clicked)
          if (_selectedDate != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: rustAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: rustAccent.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 13, color: rustAccent),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('EEEE, d. MMMM yyyy').format(_selectedDate!),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: rustAccent,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _selectedCount! == 1
                        ? '1 word saved'
                        : '$_selectedCount words saved',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: rustAccent,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Full-width Responsive Grid
          LayoutBuilder(
            builder: (context, constraints) {
              const int totalWeeks = 12;
              const int daysPerWeek = 7;
              
              // Calculate width per column to fill 100% of available card width
              final double availableWidth = constraints.maxWidth;
              final double colWidth = (availableWidth / totalWeeks).floorToDouble();
              final double squareSize = (colWidth - 4).clamp(12.0, 26.0);

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(totalWeeks, (colIndex) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(daysPerWeek, (rowIndex) {
                      final int daysAgo = (totalWeeks - 1 - colIndex) * 7 + (daysPerWeek - 1 - rowIndex);
                      final date = today.subtract(Duration(days: daysAgo));
                      final key = '${date.year}-${date.month}-${date.day}';
                      final count = dailyCounts[key] ?? 0;

                      final bool isSelected = _selectedDate != null &&
                          _selectedDate!.year == date.year &&
                          _selectedDate!.month == date.month &&
                          _selectedDate!.day == date.day;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedDate = null;
                                _selectedCount = null;
                              } else {
                                _selectedDate = date;
                                _selectedCount = count;
                              }
                            });
                          },
                          child: Tooltip(
                            message: '$count words on ${date.day}.${date.month}.${date.year}',
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: squareSize,
                              height: squareSize,
                              decoration: BoxDecoration(
                                color: _getSquareColor(count, rustAccent, inkColor),
                                borderRadius: BorderRadius.circular(2.5),
                                border: Border.all(
                                  color: isSelected
                                      ? inkColor
                                      : Colors.transparent,
                                  width: isSelected ? 1.5 : 0,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }

  Color _getSquareColor(int count, Color rustAccent, Color inkColor) {
    if (count == 0) {
      return inkColor.withValues(alpha: 0.08);
    } else if (count == 1) {
      return rustAccent.withValues(alpha: 0.35);
    } else if (count == 2) {
      return rustAccent.withValues(alpha: 0.65);
    } else {
      return rustAccent;
    }
  }

  Widget _buildLegendSquare(int count, Color rustAccent, Color inkColor) {
    return Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(
        color: _getSquareColor(count, rustAccent, inkColor),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
