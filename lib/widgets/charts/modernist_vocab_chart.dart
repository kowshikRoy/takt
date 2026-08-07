import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/saved_word.dart';
import '../../l10n/app_localizations.dart';

enum VocabTimeframe {
  sevenDays,
  thirtyDays,
  twelveWeeks,
  allTime,
}

class VocabChartPoint {
  final DateTime date;
  final String label;
  final int newWords;
  final int cumulativeWords;

  VocabChartPoint({
    required this.date,
    required this.label,
    required this.newWords,
    required this.cumulativeWords,
  });
}

class ModernistVocabChart extends StatefulWidget {
  final List<SavedWord> savedWords;
  final Color? accentColor;

  const ModernistVocabChart({
    super.key,
    required this.savedWords,
    this.accentColor,
  });

  @override
  State<ModernistVocabChart> createState() => _ModernistVocabChartState();
}

class _ModernistVocabChartState extends State<ModernistVocabChart> {
  VocabTimeframe _timeframe = VocabTimeframe.sevenDays;
  int? _selectedIndex;

  List<VocabChartPoint> _buildChartData(VocabTimeframe timeframe) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sortedWords = List<SavedWord>.from(widget.savedWords)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    switch (timeframe) {
      case VocabTimeframe.sevenDays: {
        final List<VocabChartPoint> points = [];
        for (int i = 6; i >= 0; i--) {
          final day = today.subtract(Duration(days: i));
          final nextDay = day.add(const Duration(days: 1));
          
          final newCount = sortedWords.where((w) =>
              !w.createdAt.isBefore(day) && w.createdAt.isBefore(nextDay)).length;
          final cumulative = sortedWords.where((w) =>
              w.createdAt.isBefore(nextDay)).length;
          
          final label = DateFormat('E').format(day);
          points.add(VocabChartPoint(
            date: day,
            label: label,
            newWords: newCount,
            cumulativeWords: cumulative,
          ));
        }
        return points;
      }
      case VocabTimeframe.thirtyDays: {
        final List<VocabChartPoint> points = [];
        for (int i = 29; i >= 0; i--) {
          final day = today.subtract(Duration(days: i));
          final nextDay = day.add(const Duration(days: 1));
          
          final newCount = sortedWords.where((w) =>
              !w.createdAt.isBefore(day) && w.createdAt.isBefore(nextDay)).length;
          final cumulative = sortedWords.where((w) =>
              w.createdAt.isBefore(nextDay)).length;
          
          final label = (i % 7 == 0 || i == 0) ? DateFormat('d.M').format(day) : '';
          points.add(VocabChartPoint(
            date: day,
            label: label,
            newWords: newCount,
            cumulativeWords: cumulative,
          ));
        }
        return points;
      }
      case VocabTimeframe.twelveWeeks: {
        final List<VocabChartPoint> points = [];
        for (int i = 11; i >= 0; i--) {
          final weekStart = today.subtract(Duration(days: i * 7 + today.weekday - 1));
          final weekEnd = weekStart.add(const Duration(days: 7));
          
          final newCount = sortedWords.where((w) =>
              !w.createdAt.isBefore(weekStart) && w.createdAt.isBefore(weekEnd)).length;
          final cumulative = sortedWords.where((w) =>
              w.createdAt.isBefore(weekEnd)).length;
          
          final label = 'W${12 - i}';
          points.add(VocabChartPoint(
            date: weekStart,
            label: (i % 3 == 0 || i == 0) ? label : '',
            newWords: newCount,
            cumulativeWords: cumulative,
          ));
        }
        return points;
      }
      case VocabTimeframe.allTime: {
        final List<VocabChartPoint> points = [];
        for (int i = 5; i >= 0; i--) {
          final monthStart = DateTime(now.year, now.month - i, 1);
          final nextMonth = DateTime(now.year, now.month - i + 1, 1);
          
          final newCount = sortedWords.where((w) =>
              !w.createdAt.isBefore(monthStart) && w.createdAt.isBefore(nextMonth)).length;
          final cumulative = sortedWords.where((w) =>
              w.createdAt.isBefore(nextMonth)).length;
          
          final label = DateFormat('MMM').format(monthStart);
          points.add(VocabChartPoint(
            date: monthStart,
            label: label,
            newWords: newCount,
            cumulativeWords: cumulative,
          ));
        }
        return points;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final inkColor = isDark ? const Color(0xFFEDE8E1) : const Color(0xFF1E1B18);
    final cardBg = isDark ? const Color(0xFF221E1A) : const Color(0xFFF2EEE7);
    final rustAccent = widget.accentColor ?? (isDark ? const Color(0xFFE05338) : const Color(0xFF8C2D19));

    final points = _buildChartData(_timeframe);
    if (_selectedIndex != null && _selectedIndex! >= points.length) {
      _selectedIndex = null;
    }

    final activePoint = _selectedIndex != null ? points[_selectedIndex!] : (points.isNotEmpty ? points.last : null);

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
                l10n?.titleVocabGrowth ?? 'VOCABULARY GROWTH',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                  color: inkColor,
                ),
              ),
              if (activePoint != null)
                Text(
                  '+${activePoint.newWords} new · ${activePoint.cumulativeWords} total',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: rustAccent,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Timeframe Pills Selector
          Row(
            children: [
              _buildPill(VocabTimeframe.sevenDays, l10n?.labelTimeframe7D ?? '7D', inkColor, rustAccent),
              const SizedBox(width: 8),
              _buildPill(VocabTimeframe.thirtyDays, l10n?.labelTimeframe30D ?? '30D', inkColor, rustAccent),
              const SizedBox(width: 8),
              _buildPill(VocabTimeframe.twelveWeeks, l10n?.labelTimeframe12W ?? '12W', inkColor, rustAccent),
              const SizedBox(width: 8),
              _buildPill(VocabTimeframe.allTime, l10n?.labelTimeframeAll ?? 'All', inkColor, rustAccent),
            ],
          ),
          const SizedBox(height: 18),

          // Chart Canvas
          SizedBox(
            height: 190,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onPanDown: (details) => _handleTouch(details.localPosition, constraints.maxWidth, points.length),
                  onPanUpdate: (details) => _handleTouch(details.localPosition, constraints.maxWidth, points.length),
                  onTapUp: (_) => setState(() => _selectedIndex = null),
                  child: CustomPaint(
                    size: Size(constraints.maxWidth, 190),
                    painter: _ModernistVocabChartPainter(
                      points: points,
                      selectedIndex: _selectedIndex,
                      accentColor: rustAccent,
                      inkColor: inkColor,
                      dividerColor: theme.dividerColor,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _handleTouch(Offset localPosition, double totalWidth, int count) {
    if (count == 0) return;
    final double step = totalWidth / count;
    final int index = (localPosition.dx / step).floor().clamp(0, count - 1);
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildPill(
    VocabTimeframe timeframe,
    String label,
    Color inkColor,
    Color rustAccent,
  ) {
    final isSelected = _timeframe == timeframe;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _timeframe = timeframe;
            _selectedIndex = null;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? rustAccent : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? rustAccent : inkColor.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? Colors.white : inkColor.withValues(alpha: 0.8),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModernistVocabChartPainter extends CustomPainter {
  final List<VocabChartPoint> points;
  final int? selectedIndex;
  final Color accentColor;
  final Color inkColor;
  final Color dividerColor;

  _ModernistVocabChartPainter({
    required this.points,
    required this.selectedIndex,
    required this.accentColor,
    required this.inkColor,
    required this.dividerColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final double bottomPadding = 24.0;
    final double leftPadding = 28.0;
    final double rightPadding = 28.0;
    final double topPadding = 12.0;

    final double chartWidth = size.width - leftPadding - rightPadding;
    final double chartHeight = size.height - topPadding - bottomPadding;

    int maxDaily = points.fold<int>(0, (prev, p) => math.max(prev, p.newWords));
    if (maxDaily < 5) maxDaily = 5;
    int maxCumulative = points.fold<int>(0, (prev, p) => math.max(prev, p.cumulativeWords));
    if (maxCumulative < 10) maxCumulative = 10;

    // Draw horizontal grid lines
    final gridPaint = Paint()
      ..color = inkColor.withValues(alpha: 0.08)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final textStyle = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: inkColor.withValues(alpha: 0.5),
    );

    for (int i = 0; i <= 3; i++) {
      final double y = topPadding + (chartHeight * i / 3);
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );

      // Left axis: Daily volume scale
      final int val = (maxDaily * (3 - i) / 3).round();
      final textSpan = TextSpan(text: '$val', style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: ui.TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(leftPadding - textPainter.width - 6, y - textPainter.height / 2),
      );

      // Right axis: Cumulative scale
      final int cumVal = (maxCumulative * (3 - i) / 3).round();
      final cumSpan = TextSpan(text: '$cumVal', style: textStyle);
      final cumPainter = TextPainter(
        text: cumSpan,
        textDirection: ui.TextDirection.ltr,
      )..layout();
      cumPainter.paint(
        canvas,
        Offset(size.width - rightPadding + 6, y - cumPainter.height / 2),
      );
    }

    final int count = points.length;
    final double step = chartWidth / count;
    final double barWidth = math.max(3.0, (step * 0.5).clamp(3.0, 24.0));

    // 1. Draw Daily Volume Bars
    for (int i = 0; i < count; i++) {
      final p = points[i];
      final double x = leftPadding + (i * step) + (step / 2);
      final double barHeight = maxDaily > 0 ? (p.newWords / maxDaily) * chartHeight : 0;
      final double y = topPadding + chartHeight - barHeight;

      final isSelected = selectedIndex == i;
      final barPaint = Paint()
        ..color = isSelected
            ? accentColor
            : accentColor.withValues(alpha: 0.75)
        ..style = PaintingStyle.fill;

      if (barHeight > 0) {
        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x - (barWidth / 2), y, barWidth, barHeight),
          const Radius.circular(2),
        );
        canvas.drawRRect(rrect, barPaint);
      } else {
        // Subtle base dot for 0 words
        final dotPaint = Paint()
          ..color = inkColor.withValues(alpha: 0.15)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(x, topPadding + chartHeight - 2), 1.5, dotPaint);
      }

      // X-Axis Label
      if (p.label.isNotEmpty) {
        final labelSpan = TextSpan(
          text: p.label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? accentColor : inkColor.withValues(alpha: 0.6),
          ),
        );
        final labelPainter = TextPainter(
          text: labelSpan,
          textDirection: ui.TextDirection.ltr,
        )..layout();
        labelPainter.paint(
          canvas,
          Offset(x - labelPainter.width / 2, size.height - bottomPadding + 6),
        );
      }
    }

    // 2. Draw Cumulative Trajectory Curve
    if (count > 1) {
      final linePath = Path();
      final fillPath = Path();

      for (int i = 0; i < count; i++) {
        final p = points[i];
        final double x = leftPadding + (i * step) + (step / 2);
        final double y = topPadding + chartHeight - ((p.cumulativeWords / maxCumulative) * chartHeight);

        if (i == 0) {
          linePath.moveTo(x, y);
          fillPath.moveTo(x, topPadding + chartHeight);
          fillPath.lineTo(x, y);
        } else {
          final prevP = points[i - 1];
          final double prevX = leftPadding + ((i - 1) * step) + (step / 2);
          final double prevY = topPadding + chartHeight - ((prevP.cumulativeWords / maxCumulative) * chartHeight);

          final double controlX1 = prevX + (x - prevX) / 2;
          final double controlY1 = prevY;
          final double controlX2 = prevX + (x - prevX) / 2;
          final double controlY2 = y;

          linePath.cubicTo(controlX1, controlY1, controlX2, controlY2, x, y);
          fillPath.cubicTo(controlX1, controlY1, controlX2, controlY2, x, y);
        }
      }

      final lastX = leftPadding + ((count - 1) * step) + (step / 2);
      fillPath.lineTo(lastX, topPadding + chartHeight);
      fillPath.close();

      // Draw subtle gradient under curve
      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accentColor.withValues(alpha: 0.12),
            accentColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(leftPadding, topPadding, chartWidth, chartHeight));
      canvas.drawPath(fillPath, fillPaint);

      final linePaint = Paint()
        ..color = accentColor
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      canvas.drawPath(linePath, linePaint);
    }

    // 3. Highlight Selected Point & Tooltip
    if (selectedIndex != null && selectedIndex! < count) {
      final p = points[selectedIndex!];
      final double x = leftPadding + (selectedIndex! * step) + (step / 2);
      final double y = topPadding + chartHeight - ((p.cumulativeWords / maxCumulative) * chartHeight);

      // Scrubber vertical line
      final scrubberPaint = Paint()
        ..color = inkColor.withValues(alpha: 0.3)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(x, topPadding), Offset(x, topPadding + chartHeight), scrubberPaint);

      // Point Indicator Circle
      final circlePaint = Paint()
        ..color = accentColor
        ..style = PaintingStyle.fill;
      final borderPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      canvas.drawCircle(Offset(x, y), 5.0, circlePaint);
      canvas.drawCircle(Offset(x, y), 5.0, borderPaint);

      // Tooltip Card
      final dateStr = DateFormat('d. MMM yyyy').format(p.date);
      final tooltipText = '$dateStr\n+${p.newWords} words · ${p.cumulativeWords} total';
      final tooltipSpan = TextSpan(
        text: tooltipText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
      );
      final tooltipPainter = TextPainter(
        text: tooltipSpan,
        textDirection: ui.TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();

      final double tooltipWidth = tooltipPainter.width + 16;
      final double tooltipHeight = tooltipPainter.height + 10;
      double tooltipX = x - (tooltipWidth / 2);
      if (tooltipX < leftPadding) tooltipX = leftPadding;
      if (tooltipX + tooltipWidth > size.width - rightPadding) {
        tooltipX = size.width - rightPadding - tooltipWidth;
      }
      final double tooltipY = (y - tooltipHeight - 10) < topPadding ? y + 10 : y - tooltipHeight - 10;

      final tooltipRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(tooltipX, tooltipY, tooltipWidth, tooltipHeight),
        const Radius.circular(4),
      );
      final tooltipBgPaint = Paint()
        ..color = const Color(0xFF1E1B18).withValues(alpha: 0.92)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(tooltipRect, tooltipBgPaint);
      tooltipPainter.paint(canvas, Offset(tooltipX + 8, tooltipY + 5));
    }
  }

  @override
  bool shouldRepaint(covariant _ModernistVocabChartPainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.points != points ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.inkColor != inkColor;
  }
}
