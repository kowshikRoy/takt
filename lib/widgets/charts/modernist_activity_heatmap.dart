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
  Offset? _selectedPosition;

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
              if (_selectedDate != null)
                Text(
                  '+$_selectedCount words · ${DateFormat('d. MMM').format(_selectedDate!)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: rustAccent,
                  ),
                )
              else
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
          const SizedBox(height: 14),

          // Full-width Grid with Touch & Pan Detection
          LayoutBuilder(
            builder: (context, constraints) {
              const int totalWeeks = 12;
              const int daysPerWeek = 7;

              final double availableWidth = constraints.maxWidth;
              final double colWidth = (availableWidth / totalWeeks).floorToDouble();
              final double squareSize = (colWidth - 4).clamp(12.0, 26.0);
              final double totalGridHeight = daysPerWeek * (squareSize + 4.0);

              void handleTouch(Offset localPos) {
                final double colStep = availableWidth / totalWeeks;
                final double rowStep = totalGridHeight / daysPerWeek;

                final int colIndex = (localPos.dx / colStep).floor().clamp(0, totalWeeks - 1);
                final int rowIndex = (localPos.dy / rowStep).floor().clamp(0, daysPerWeek - 1);

                final int daysAgo = (totalWeeks - 1 - colIndex) * 7 + (daysPerWeek - 1 - rowIndex);
                final date = today.subtract(Duration(days: daysAgo));
                final key = '${date.year}-${date.month}-${date.day}';
                final count = dailyCounts[key] ?? 0;

                setState(() {
                  _selectedDate = date;
                  _selectedCount = count;
                  _selectedPosition = Offset(
                    (colIndex * colStep) + (colStep / 2),
                    (rowIndex * rowStep) + (rowStep / 2),
                  );
                });
              }

              return GestureDetector(
                onPanDown: (details) => handleTouch(details.localPosition),
                onPanUpdate: (details) => handleTouch(details.localPosition),
                onTapUp: (_) {
                  // Keep the selection visible until tapped again or outside
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    SizedBox(
                      width: availableWidth,
                      height: totalGridHeight,
                      child: Row(
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
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 120),
                                  width: squareSize,
                                  height: squareSize,
                                  decoration: BoxDecoration(
                                    color: _getSquareColor(count, rustAccent, inkColor),
                                    borderRadius: BorderRadius.circular(2.5),
                                    border: Border.all(
                                      color: isSelected ? inkColor : Colors.transparent,
                                      width: isSelected ? 1.5 : 0,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: rustAccent.withValues(alpha: 0.35),
                                              blurRadius: 4,
                                              spreadRadius: 1,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                              );
                            }),
                          );
                        }),
                      ),
                    ),

                    // Floating Tooltip Bubble when active
                    if (_selectedDate != null && _selectedPosition != null) ...[
                      Positioned(
                        left: (_selectedPosition!.dx - 55).clamp(0.0, availableWidth - 110.0),
                        top: (_selectedPosition!.dy - 46) < 0
                            ? _selectedPosition!.dy + 18
                            : _selectedPosition!.dy - 46,
                        child: IgnorePointer(
                          child: Container(
                            width: 110,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1B18).withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  DateFormat('d. MMM yyyy').format(_selectedDate!),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  _selectedCount! == 1
                                      ? '+1 word'
                                      : '+${_selectedCount!} words',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: rustAccent.withValues(alpha: 0.95),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
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
