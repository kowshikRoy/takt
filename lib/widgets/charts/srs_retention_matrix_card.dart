import 'package:flutter/material.dart';
import '../../models/saved_word.dart';
import '../../l10n/app_localizations.dart';

class SrsRetentionMatrixCard extends StatelessWidget {
  final List<SavedWord> savedWords;

  const SrsRetentionMatrixCard({
    super.key,
    required this.savedWords,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final inkColor = isDark ? const Color(0xFFEDE8E1) : const Color(0xFF1E1B18);
    final cardBg = isDark ? const Color(0xFF221E1A) : const Color(0xFFF2EEE7);

    final total = savedWords.length;

    // Calculate stage counts
    int stage0 = 0; // Learning
    int stage1 = 0; // Apprentice
    int stage2 = 0; // Familiar
    int stage3 = 0; // Proficient
    int stage4 = 0; // Mastered

    for (final w in savedWords) {
      if (w.category == VocabCategory.mastered || w.masteryLevel >= 4) {
        stage4++;
      } else if (w.masteryLevel == 3) {
        stage3++;
      } else if (w.masteryLevel == 2) {
        stage2++;
      } else if (w.masteryLevel == 1) {
        stage1++;
      } else {
        stage0++;
      }
    }

    final stages = [
      _StageData(
        title: l10n?.labelStageLearning ?? 'Learning',
        count: stage0,
        color: isDark ? const Color(0xFF81C784) : const Color(0xFF7CA982),
        total: total,
      ),
      _StageData(
        title: l10n?.labelStageApprentice ?? 'Apprentice',
        count: stage1,
        color: isDark ? const Color(0xFF66BB6A) : const Color(0xFF5E8C6A),
        total: total,
      ),
      _StageData(
        title: l10n?.labelStageFamiliar ?? 'Familiar',
        count: stage2,
        color: isDark ? const Color(0xFF43A047) : const Color(0xFF2C5E3B),
        total: total,
      ),
      _StageData(
        title: l10n?.labelStageProficient ?? 'Proficient',
        count: stage3,
        color: isDark ? const Color(0xFFE07A5F) : const Color(0xFFB5523A),
        total: total,
      ),
      _StageData(
        title: l10n?.labelStageMastered ?? 'Mastered',
        count: stage4,
        color: isDark ? const Color(0xFFE05338) : const Color(0xFF8C2D19),
        total: total,
      ),
    ];

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n?.titleMemoryRetention ?? 'MEMORY RETENTION (SRS)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                  color: inkColor,
                ),
              ),
              Text(
                '$total words total',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: inkColor.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...stages.map((stage) => _buildStageRow(context, stage, inkColor, cardBg)),
        ],
      ),
    );
  }

  Widget _buildStageRow(
    BuildContext context,
    _StageData stage,
    Color inkColor,
    Color cardBg,
  ) {
    final double ratio = stage.total > 0 ? (stage.count / stage.total) : 0.0;
    final int percent = (ratio * 100).round();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.5),
      child: Row(
        children: [
          SizedBox(
            width: 85,
            child: Text(
              stage.title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: inkColor.withValues(alpha: 0.85),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 14,
              decoration: BoxDecoration(
                color: inkColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(3),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: ratio.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: stage.color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 68,
            child: Text(
              '${stage.count} ($percent%)',
              textAlign: TextAlign.end,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: inkColor.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StageData {
  final String title;
  final int count;
  final Color color;
  final int total;

  _StageData({
    required this.title,
    required this.count,
    required this.color,
    required this.total,
  });
}
