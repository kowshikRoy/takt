import 'package:flutter/material.dart';
import '../../models/saved_word.dart';
import '../../l10n/app_localizations.dart';

class ModernistActivityHeatmap extends StatelessWidget {
  final List<SavedWord> words;
  final Set<String> activityDates;

  const ModernistActivityHeatmap({
    super.key,
    required this.words,
    this.activityDates = const {},
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final inkColor = isDark ? const Color(0xFFEDE8E1) : const Color(0xFF1E1B18);
    final cardBg = isDark ? const Color(0xFF221E1A) : const Color(0xFFF2EEE7);

    // Calculate Total Study Activity (Words Saved + Reviews Practiced)
    final Map<String, int> dailyCounts = {};

    for (final w in words) {
      final createdKey = '${w.createdAt.year}-${w.createdAt.month}-${w.createdAt.day}';
      dailyCounts[createdKey] = (dailyCounts[createdKey] ?? 0) + 1;

      if (w.lastReviewed != null) {
        final reviewKey = '${w.lastReviewed!.year}-${w.lastReviewed!.month}-${w.lastReviewed!.day}';
        if (reviewKey != createdKey) {
          dailyCounts[reviewKey] = (dailyCounts[reviewKey] ?? 0) + 1;
        }
      }
    }

    // Ensure all recorded active study days in ProfileService have baseline activity
    for (final dateStr in activityDates) {
      dailyCounts[dateStr] = (dailyCounts[dateStr] ?? 0).clamp(1, 9999);
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
          // Clean Header Row: Title on Left, GitHub Legend on Right
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
                  _buildLegendSquare(0, isDark, inkColor),
                  const SizedBox(width: 3),
                  _buildLegendSquare(1, isDark, inkColor),
                  const SizedBox(width: 3),
                  _buildLegendSquare(2, isDark, inkColor),
                  const SizedBox(width: 3),
                  _buildLegendSquare(3, isDark, inkColor),
                  const SizedBox(width: 3),
                  _buildLegendSquare(4, isDark, inkColor),
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
          const SizedBox(height: 14),

          // Full-width Responsive Grid
          LayoutBuilder(
            builder: (context, constraints) {
              const int totalWeeks = 12;
              const int daysPerWeek = 7;

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

                      final tooltipMsg = count == 0
                          ? 'No activity on ${date.day}.${date.month}.${date.year}'
                          : count == 1
                              ? '1 activity on ${date.day}.${date.month}.${date.year}'
                              : '$count activities on ${date.day}.${date.month}.${date.year}';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Tooltip(
                          message: tooltipMsg,
                          triggerMode: TooltipTriggerMode.tap,
                          waitDuration: Duration.zero,
                          showDuration: const Duration(seconds: 2),
                          preferBelow: false,
                          verticalOffset: 16,
                          textStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1B18).withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Container(
                            width: squareSize,
                            height: squareSize,
                            decoration: BoxDecoration(
                              color: _getGithubSquareColor(count, isDark, inkColor),
                              borderRadius: BorderRadius.circular(2.5),
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

  /// GitHub activity scale:
  /// Level 0: 0 actions
  /// Level 1: 1–2 actions (mint green)
  /// Level 2: 3–5 actions (medium green)
  /// Level 3: 6–11 actions (rich forest green)
  /// Level 4: 12+ actions (deep emerald green)
  static Color _getGithubSquareColor(int count, bool isDark, Color inkColor) {
    if (count <= 0) {
      return isDark
          ? const Color(0xFF161B22)
          : inkColor.withValues(alpha: 0.08);
    }
    if (isDark) {
      if (count <= 2) return const Color(0xFF0E4429);
      if (count <= 5) return const Color(0xFF006D32);
      if (count <= 11) return const Color(0xFF26A641);
      return const Color(0xFF39D353);
    } else {
      if (count <= 2) return const Color(0xFF9BE9A8);
      if (count <= 5) return const Color(0xFF40C463);
      if (count <= 11) return const Color(0xFF30A14E);
      return const Color(0xFF216E39);
    }
  }

  Widget _buildLegendSquare(int level, bool isDark, Color inkColor) {
    final sampleCounts = [0, 1, 4, 8, 15];
    final count = sampleCounts[level.clamp(0, 4)];
    return Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(
        color: _getGithubSquareColor(count, isDark, inkColor),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
