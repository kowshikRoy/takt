import 'package:flutter/material.dart';
import '../theme/breakpoints.dart';

/// Drop-in replacement for `GridView.builder` whose `crossAxisCount` scales
/// with [WindowClass] instead of being hardcoded, so card collections (story
/// feeds, vocab tiles, book rows) use the extra room on wide viewports
/// instead of stretching a fixed column count edge-to-edge.
class ResponsiveGrid extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double childAspectRatio;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry? padding;
  final int compactColumns;
  final int mediumColumns;
  final int expandedColumns;
  final int largeColumns;

  const ResponsiveGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.childAspectRatio = 1.0,
    this.crossAxisSpacing = 16,
    this.mainAxisSpacing = 16,
    this.shrinkWrap = true,
    this.physics = const NeverScrollableScrollPhysics(),
    this.padding,
    this.compactColumns = 1,
    this.mediumColumns = 2,
    this.expandedColumns = 3,
    this.largeColumns = 4,
  });

  int _columnsFor(WindowClass windowClass) {
    switch (windowClass) {
      case WindowClass.compact:
        return compactColumns;
      case WindowClass.medium:
        return mediumColumns;
      case WindowClass.expanded:
        return expandedColumns;
      case WindowClass.large:
        return largeColumns;
    }
  }

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = _columnsFor(WindowClass.of(context));
    return GridView.builder(
      shrinkWrap: shrinkWrap,
      physics: physics,
      padding: padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
      ),
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}
