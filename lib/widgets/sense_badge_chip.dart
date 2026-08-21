import 'package:flutter/material.dart';

enum SenseBadgeType {
  primary,
  context,
  colloquial,
  figurative,
  specialized,
  archaic,
  other;

  static SenseBadgeType fromString(String? type) {
    if (type == null) return other;
    return switch (type.toLowerCase().trim()) {
      'primary' => primary,
      'context' => context,
      'colloquial' => colloquial,
      'figurative' => figurative,
      'specialized' => specialized,
      'archaic' => archaic,
      _ => other,
    };
  }

  Color resolveColor(BuildContext context, {bool isDark = false}) {
    return switch (this) {
      SenseBadgeType.primary => Colors.teal,
      SenseBadgeType.context => Colors.indigo,
      SenseBadgeType.colloquial => Colors.amber.shade800,
      SenseBadgeType.figurative => Colors.deepPurple,
      SenseBadgeType.specialized => Colors.blue.shade700,
      SenseBadgeType.archaic => Colors.brown,
      SenseBadgeType.other => Colors.grey.shade600,
    };
  }
}

class SenseBadgeChip extends StatelessWidget {
  final String label;
  final SenseBadgeType type;
  final double fontSize;

  const SenseBadgeChip({
    super.key,
    required this.label,
    required this.type,
    this.fontSize = 9.5,
  });

  factory SenseBadgeChip.fromMap(
    Map<String, dynamic> map, {
    Key? key,
    double fontSize = 9.5,
  }) {
    final label = map['label']?.toString() ?? '';
    final type = SenseBadgeType.fromString(map['type']?.toString());
    return SenseBadgeChip(
      key: key,
      label: label,
      type: type,
      fontSize: fontSize,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tagColor = type.resolveColor(context, isDark: isDark);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: tagColor.withValues(alpha: isDark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(3.5),
        border: Border.all(
          color: tagColor.withValues(alpha: 0.35),
          width: 0.6,
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: tagColor,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class SenseBadgeWrap extends StatelessWidget {
  final List<dynamic> badges;
  final double spacing;
  final double runSpacing;

  const SenseBadgeWrap({
    super.key,
    required this.badges,
    this.spacing = 4,
    this.runSpacing = 4,
  });

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: badges.map((b) {
        if (b is Map<String, dynamic>) {
          return SenseBadgeChip.fromMap(b);
        } else if (b is Map) {
          return SenseBadgeChip.fromMap(Map<String, dynamic>.from(b));
        } else if (b is SenseBadgeChip) {
          return b;
        }
        return const SizedBox.shrink();
      }).toList(),
    );
  }
}
