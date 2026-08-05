import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Fixed "Modernist" visual identity for the Books (textbook study) feature,
/// translated from the Claude Design "Books UI redesign" project's design
/// system tokens. Deliberately independent of the app's user-selectable
/// theme/color palette (Settings > Appearance) — this feature keeps its own
/// editorial look regardless of what the rest of the app is themed as.
class BooksModernist {
  BooksModernist._();

  static const Color bg = Color(0xFFF3F2F2);
  static const Color surface = Color(0xFFEAE9E9);
  static const Color text = Color(0xFF201E1D);
  static const Color accent = Color(0xFFEC3013);
  static const Color accentDark = Color(0xFFAE1800);
  static const Color accent100 = Color(0xFFFFF2EF);
  static const Color accent200 = Color(0xFFFFE0D9);
  static const Color accent600 = Color(0xFFDD2B0F);
  static const Color accent700 = Color(0xFFAE1800);

  static final Color divider = text.withValues(alpha: 0.4);
  static final Color dividerThin = text.withValues(alpha: 0.18);

  static TextStyle heading({double size = 16, Color? color, double? height}) =>
      GoogleFonts.archivo(
        fontWeight: FontWeight.w800,
        fontSize: size,
        color: color ?? text,
        height: height,
      );

  static TextStyle body({
    double size = 13,
    Color? color,
    FontStyle? style,
    FontWeight? weight,
  }) => GoogleFonts.archivo(
    fontWeight: weight ?? FontWeight.w400,
    fontSize: size,
    color: color ?? text,
    fontStyle: style,
  );

  static TextStyle mono({double size = 12.5, Color? color}) =>
      GoogleFonts.robotoMono(fontSize: size, color: color ?? text);
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
          errorBuilder: (_, __, ___) => Container(
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
