import 'package:flutter/material.dart';
import '../theme/breakpoints.dart';

/// Caps and centers content at Medium+ window classes so single-focus
/// screens (a flashcard, a quiz) don't stretch edge-to-edge on wide
/// desktop viewports. See design doc §7 "Practice screens".
class CappedWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const CappedWidth({super.key, required this.child, this.maxWidth = 600});

  @override
  Widget build(BuildContext context) {
    if (!WindowClass.of(context).isAtLeastMedium) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
