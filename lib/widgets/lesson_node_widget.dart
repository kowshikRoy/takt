import 'package:flutter/material.dart';
import '../models/lesson_node.dart';

class LessonNodeWidget extends StatelessWidget {
  final LessonNode node;
  final Color unitColor;
  final int? dueCount;
  final VoidCallback onTap;

  const LessonNodeWidget({
    super.key,
    required this.node,
    required this.unitColor,
    this.dueCount,
    required this.onTap,
  });

  static const double diameter = 68;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showDueBadge = node.type == LessonNodeType.review && (dueCount ?? 0) > 0;

    Color background;
    Color foreground;
    Widget icon;

    if (node.completed) {
      background = unitColor;
      foreground = Colors.white;
      icon = const Icon(Icons.check_rounded, color: Colors.white, size: 30);
    } else if (node.unlocked) {
      background = unitColor;
      foreground = Colors.white;
      icon = Icon(node.type.icon, color: Colors.white, size: 28);
    } else {
      background = theme.dividerColor.withValues(alpha: 0.3);
      foreground = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6);
      icon = Icon(Icons.lock_rounded, color: foreground, size: 24);
    }

    return GestureDetector(
      onTap: node.unlocked ? onTap : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: diameter,
                height: diameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: background,
                  border: Border.all(
                    color: node.unlocked ? unitColor.withValues(alpha: 0.4) : Colors.transparent,
                    width: 4,
                  ),
                  boxShadow: node.unlocked && !node.completed
                      ? [
                          BoxShadow(
                            color: unitColor.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Center(child: icon),
              ),
              if (showDueBadge)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
                    ),
                    child: Text(
                      '$dueCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: diameter + 24,
            child: Text(
              node.type.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: node.unlocked ? FontWeight.bold : FontWeight.normal,
                color: node.unlocked ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
