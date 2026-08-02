import 'package:flutter/material.dart';

/// Material 3 window size classes, extended with a `large` tier for desktop
/// layouts wide enough for a secondary content pane (e.g. lesson path + detail
/// side-by-side). See docs/duolingo-style-redesign.md §7.
enum WindowClass {
  /// Phone, folded foldable. Bottom nav bar.
  compact,

  /// Unfolded foldable, small tablet (portrait). Icon-only nav rail.
  medium,

  /// Tablet (landscape), small desktop. Extended nav rail (icons + labels).
  expanded,

  /// Desktop. Extended nav rail + room for a secondary content pane.
  large;

  static const double mediumMinWidth = 600;
  static const double expandedMinWidth = 840;
  static const double largeMinWidth = 1240;

  static WindowClass fromWidth(double width) {
    if (width >= largeMinWidth) return WindowClass.large;
    if (width >= expandedMinWidth) return WindowClass.expanded;
    if (width >= mediumMinWidth) return WindowClass.medium;
    return WindowClass.compact;
  }

  static WindowClass of(BuildContext context) {
    return fromWidth(MediaQuery.sizeOf(context).width);
  }

  bool get isCompact => this == WindowClass.compact;
  bool get isAtLeastMedium => index >= WindowClass.medium.index;
  bool get isAtLeastExpanded => index >= WindowClass.expanded.index;
  bool get isAtLeastLarge => index >= WindowClass.large.index;
}
