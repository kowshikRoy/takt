import 'package:flutter/material.dart';
import '../models/saved_word.dart';

class VocabStatusPills extends StatelessWidget {
  final VocabCategory? currentCategory;
  final ValueChanged<VocabCategory> onCategorySelected;

  const VocabStatusPills({
    super.key,
    required this.currentCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildPill(
          context: context,
          label: 'Save',
          icon: Icons.bookmark_border_rounded,
          activeIcon: Icons.bookmark_rounded,
          category: VocabCategory.reviewLater,
        ),
        const SizedBox(width: 8),
        _buildPill(
          context: context,
          label: 'Learning',
          icon: Icons.psychology_outlined,
          activeIcon: Icons.psychology_rounded,
          category: VocabCategory.learning,
        ),
        const SizedBox(width: 8),
        _buildPill(
          context: context,
          label: 'Known',
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

    return Expanded(
      child: GestureDetector(
        onTap: () => onCategorySelected(category),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
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
                size: 14,
                color: isActive ? Colors.white : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                    color: isActive ? Colors.white : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
