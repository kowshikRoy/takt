import 'package:flutter/material.dart';
import '../models/saved_word.dart';

class VocabStatusPills extends StatelessWidget {
  final VocabCategory? currentCategory;
  final ValueChanged<VocabCategory> onCategorySelected;
  final bool iconOnly;

  const VocabStatusPills({
    super.key,
    required this.currentCategory,
    required this.onCategorySelected,
    this.iconOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: iconOnly ? MainAxisSize.min : MainAxisSize.max,
      children: [
        _buildPill(
          context: context,
          label: 'Deck',
          tooltip: 'Add to Study Deck',
          icon: Icons.style_outlined,
          activeIcon: Icons.style_rounded,
          category: VocabCategory.reviewLater,
        ),
        SizedBox(width: iconOnly ? 4 : 8),
        _buildPill(
          context: context,
          label: 'Learning',
          tooltip: 'Mark as Learning',
          icon: Icons.psychology_outlined,
          activeIcon: Icons.psychology_rounded,
          category: VocabCategory.learning,
        ),
        SizedBox(width: iconOnly ? 4 : 8),
        _buildPill(
          context: context,
          label: 'Known',
          tooltip: 'Mark as Known',
          icon: Icons.check_circle_outline_rounded,
          activeIcon: Icons.check_circle_rounded,
          category: VocabCategory.mastered,
        ),
      ],
    );
  }

  Widget _buildPill({
    required BuildContext context,
    required String label,
    required String tooltip,
    required IconData icon,
    required IconData activeIcon,
    required VocabCategory category,
  }) {
    final bool isActive = currentCategory == category;
    final colorScheme = Theme.of(context).colorScheme;

    final Color activeBg = category == VocabCategory.mastered
        ? Colors.green.shade700
        : (category == VocabCategory.learning
            ? colorScheme.primary
            : Colors.amber.shade800);

    Widget pillContent = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: iconOnly
          ? const EdgeInsets.all(6)
          : const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? activeBg : colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isActive ? activeBg : colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: isActive ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? activeIcon : icon,
            size: iconOnly ? 16 : 14,
            color: isActive ? Colors.white : colorScheme.onSurfaceVariant,
          ),
          if (!iconOnly) ...[
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                  color: isActive ? Colors.white : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    Widget pillButton = Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => onCategorySelected(category),
        child: pillContent,
      ),
    );

    if (iconOnly) {
      return pillButton;
    }

    return Expanded(child: pillButton);
  }
}
