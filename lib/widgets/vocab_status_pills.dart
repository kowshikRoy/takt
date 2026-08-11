import 'package:flutter/material.dart';
import '../models/saved_word.dart';
import '../services/haptic_service.dart';

/// Single-line action toolbar for word cards:
/// [ 🗂️ In Deck / Study Deck ] [ ✔️ Known / Known ✓ ] [ 📖 Explore ]
class VocabStatusPills extends StatelessWidget {
  final VocabCategory? currentCategory;
  final ValueChanged<VocabCategory> onCategorySelected;
  final VoidCallback? onExplore;
  final bool iconOnly;

  const VocabStatusPills({
    super.key,
    required this.currentCategory,
    required this.onCategorySelected,
    this.onExplore,
    this.iconOnly = false,
  });

  bool get isInDeck =>
      currentCategory == VocabCategory.reviewLater ||
      currentCategory == VocabCategory.learning;

  bool get isKnown => currentCategory == VocabCategory.mastered;

  @override
  Widget build(BuildContext context) {
    final hasExplore = onExplore != null;

    return Row(
      mainAxisSize: iconOnly ? MainAxisSize.min : MainAxisSize.max,
      children: [
        _buildPill(
          context: context,
          label: isInDeck ? 'In Deck' : (hasExplore ? 'Deck' : 'Study Deck'),
          tooltip: isInDeck ? 'Remove from Study Deck' : 'Add to Study Deck',
          icon: Icons.style_outlined,
          activeIcon: Icons.style_rounded,
          isActive: isInDeck,
          activeColor: Colors.amber.shade800,
          category: VocabCategory.reviewLater,
        ),
        SizedBox(width: iconOnly ? 6 : (hasExplore ? 8 : 10)),
        _buildPill(
          context: context,
          label: isKnown ? 'Known ✓' : 'Known',
          tooltip: isKnown ? 'Mark as Not Known' : 'Mark as Known',
          icon: Icons.check_circle_outline_rounded,
          activeIcon: Icons.check_circle_rounded,
          isActive: isKnown,
          activeColor: Colors.green.shade700,
          category: VocabCategory.mastered,
        ),
        if (hasExplore) ...[
          SizedBox(width: iconOnly ? 6 : 8),
          _buildActionButton(
            context: context,
            label: 'Explore',
            tooltip: 'Explore in Dictionary',
            icon: Icons.menu_book_rounded,
            onTap: onExplore!,
          ),
        ],
      ],
    );
  }

  Widget _buildPill({
    required BuildContext context,
    required String label,
    required String tooltip,
    required IconData icon,
    required IconData activeIcon,
    required bool isActive,
    required Color activeColor,
    required VocabCategory category,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget pillContent = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: iconOnly
          ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
          : const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
      decoration: BoxDecoration(
        color: isActive
            ? activeColor.withValues(alpha: 0.15)
            : colorScheme.surfaceContainerHigh.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isActive
              ? activeColor
              : colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: isActive ? 1.6 : 1.0,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? activeIcon : icon,
            size: iconOnly ? 18 : 16,
            color: isActive ? activeColor : colorScheme.onSurfaceVariant,
          ),
          if (!iconOnly) ...[
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                  color: isActive ? activeColor : colorScheme.onSurface,
                  letterSpacing: 0.2,
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
        onTap: () {
          AppHaptics.medium();
          onCategorySelected(category);
        },
        child: pillContent,
      ),
    );

    if (iconOnly) {
      return pillButton;
    }

    return Expanded(child: pillButton);
  }

  Widget _buildActionButton({
    required BuildContext context,
    required String label,
    required String tooltip,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget actionContent = Container(
      padding: iconOnly
          ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
          : const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: iconOnly ? 18 : 16,
            color: colorScheme.primary,
          ),
          if (!iconOnly) ...[
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    Widget actionButton = Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () {
          AppHaptics.selection();
          onTap();
        },
        child: actionContent,
      ),
    );

    if (iconOnly) {
      return actionButton;
    }

    return Expanded(child: actionButton);
  }
}
