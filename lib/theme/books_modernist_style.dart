import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';
import 'app_theme.dart';

/// Visual identity for the Books feature using the user's preferred font family.
class BooksModernist {
  BooksModernist._();

  static const Color bg = Color(0xFFFAF6F0);
  static const Color surface = Color(0xFFF2EEE7);
  static const Color text = Color(0xFF201E1D);
  static const Color accent = Color(0xFFEC3013);
  static const Color accentDark = Color(0xFFAE1800);
  static const Color accent100 = Color(0xFFFFF2EF);
  static const Color accent200 = Color(0xFFFFE0D9);
  static const Color accent600 = Color(0xFFDD2B0F);
  static const Color accent700 = Color(0xFFAE1800);

  static final Color divider = text.withValues(alpha: 0.4);
  static final Color dividerThin = text.withValues(alpha: 0.18);

  static TextStyle font(
    BuildContext? context, {
    required double size,
    Color? color,
    FontStyle? style,
    FontWeight? weight,
    double? height,
  }) {
    String fontName = 'Spline Sans';
    if (context != null) {
      try {
        final provider = Provider.of<ThemeProvider>(context, listen: false);
        fontName = provider.fontFamily;
      } catch (_) {
        final themeFont = Theme.of(context).textTheme.bodyMedium?.fontFamily;
        if (themeFont != null && themeFont.isNotEmpty) {
          fontName = themeFont;
        }
      }
    }
    try {
      return GoogleFonts.getFont(
        fontName,
        fontSize: size,
        color: color ?? text,
        fontStyle: style,
        fontWeight: weight,
        height: height,
      );
    } catch (_) {
      return TextStyle(
        fontFamily: fontName,
        fontSize: size,
        color: color ?? text,
        fontStyle: style,
        fontWeight: weight,
        height: height,
      );
    }
  }

  static TextStyle heading({
    double size = 16,
    Color? color,
    double? height,
    BuildContext? context,
  }) =>
      font(
        context,
        size: size,
        color: color,
        height: height,
        weight: FontWeight.w800,
      );

  static TextStyle title({
    double size = 16,
    Color? color,
    FontWeight? weight,
    double? height,
    BuildContext? context,
  }) =>
      font(
        context,
        size: size,
        color: color,
        height: height,
        weight: weight ?? FontWeight.w800,
      );

  static TextStyle body({
    double size = 13,
    Color? color,
    FontStyle? style,
    FontWeight? weight,
    BuildContext? context,
  }) =>
      font(
        context,
        size: size,
        color: color,
        style: style,
        weight: weight ?? FontWeight.w400,
      );

  static TextStyle mono({double size = 12.5, Color? color}) =>
      GoogleFonts.robotoMono(fontSize: size, color: color ?? text);

  /// The Books feature keeps a fixed "print textbook" surface (`bg`,
  /// `surface`, `text`) regardless of the app's light/dark setting — but
  /// widgets in these screens also read `Theme.of(context).colorScheme.*`
  /// for secondary text/dividers/highlights. Left alone, those resolve
  /// against the *ambient* app theme, so in dark mode `onSurface` comes
  /// back near-white and goes invisible on this always-light background.
  /// Wrap each Books/reading screen's Scaffold in
  /// `Theme(data: BooksModernist.readingTheme(context), child: ...)` so
  /// every `Theme.of(context)` lookup inside resolves against a theme
  /// that's actually paired with this fixed light surface.
  static ThemeData readingTheme(BuildContext context) {
    String fontFamily = 'Spline Sans';
    AppColorTheme colorTheme = AppColorTheme.modernist;
    try {
      final provider = Provider.of<ThemeProvider>(context, listen: false);
      fontFamily = provider.fontFamily;
      colorTheme = provider.colorTheme;
    } catch (_) {}
    return AppTheme.lightTheme(fontFamily, colorTheme);
  }
}

/// `grayscale(1) contrast(1.08)` equivalent — the design filters every book
/// photo through this to keep the editorial, print-textbook feel.
const List<double> _grayscaleMatrix = <double>[
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0, 0, 0, 1, 0,
];

/// Grayscale-filtered book cover/photo, with the same "no image" fallback
/// icon already used across the Books screens.
class GrayscaleCover extends StatelessWidget {
  final String assetPath;
  final double width;
  final double height;
  final BoxFit fit;
  final Border? border;

  const GrayscaleCover({
    super.key,
    required this.assetPath,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(border: border),
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix(_grayscaleMatrix),
        child: Image.asset(
          assetPath,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, _, _) => Container(
            width: width,
            height: height,
            color: BooksModernist.text,
            child: Icon(
              Icons.book_rounded,
              size: width * 0.5,
              color: BooksModernist.bg,
            ),
          ),
        ),
      ),
    );
  }
}

/// `.tag-outline` / `.tag-accent` from the design system.
class ModernistTag extends StatelessWidget {
  final String label;
  final bool accent;

  const ModernistTag(this.label, {super.key, this.accent = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: accent ? BooksModernist.accent100 : Colors.transparent,
        border: accent
            ? null
            : Border.all(color: BooksModernist.accent, width: 1),
      ),
      child: Text(
        label,
        style: BooksModernist.body(
          size: 11,
          weight: FontWeight.w600,
          color: accent ? BooksModernist.accent700 : BooksModernist.accent,
        ),
      ),
    );
  }
}

/// The 2px `.hr` divider rule.
class ModernistDivider extends StatelessWidget {
  final EdgeInsetsGeometry margin;

  const ModernistDivider({super.key, this.margin = EdgeInsets.zero});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      height: 2,
      color: BooksModernist.divider,
    );
  }
}

/// A slim progress bar — `height:Npx; background: divider` outer track with
/// an `accent`-filled inner bar, matching every progress bar in the mockup
/// (`bookProgressBarStyle`, `unitProgressInner`, per-chapter `barInner`, ...).
class ModernistProgressBar extends StatelessWidget {
  final double progress; // 0.0-1.0
  final double height;
  final Color? trackColor;
  final Color? fillColor;

  const ModernistProgressBar({
    super.key,
    required this.progress,
    this.height = 4,
    this.trackColor,
    this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Container(height: height, color: trackColor ?? BooksModernist.dividerThin),
            Container(
              height: height,
              width: constraints.maxWidth * progress.clamp(0.0, 1.0),
              color: fillColor ?? BooksModernist.accent,
            ),
          ],
        );
      },
    );
  }
}
