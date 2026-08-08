import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppColorTheme {
  classic,
  retroTeal,
  retroBlue,
  retroGold,
  retroRust,
  modernist,
  retroPurple,
  slateGrey,
}

class CefrBadgeColors {
  final Color foreground;
  final Color background;
  final Color border;

  const CefrBadgeColors({
    required this.foreground,
    required this.background,
    required this.border,
  });
}

class AppTheme {
  // Theme Palettes
  static const Color _classicSeed = Color(0xFFEA2A33); // Original Red
  static const Color _tealSeed = Color(0xFF2BBAA5);    // Keppel
  static const Color _blueSeed = Color(0xFF005F73);    // Retro Blue
  static const Color _goldSeed = Color(0xFFEE9B00);    // Retro Gold
  static const Color _rustSeed = Color(0xFFBB3E03);    // Retro Rust
  static const Color _modernistSeed = Color(0xFFEC3013); // Modernist Red Accent
  static const Color _purpleSeed = Color(0xFF7C3AED); // Amethyst Violet (Gender Neutral)
  static const Color _slateSeed = Color(0xFF64748B);  // Slate Grey Accent
  
  static const Color _classicBg = Color(0xFFFAF6F0);   // Warm Aged Vintage Paper
  static const Color _retroBg = Color(0xFFFAF6F0);     // Warm Aged Vintage Paper
  static const Color _modernistBg = Color(0xFFFAF6F0); // Warm Aged Vintage Paper
  static const Color _purpleBg = Color(0xFFFAF6F0);    // Warm Aged Vintage Paper
  static const Color _slateBg = Color(0xFFFAF6F0);     // Warm Aged Vintage Paper

  // Custom semantic colors that might not map directly to Scheme
  // Updated to match "Retro Rainbow" palette
  static const Color genderMasc = Color(0xFF277DA1); // Retro Blue
  static const Color genderFem = Color(0xFFF94144);  // Retro Red
  static const Color genderNeu = Color(0xFF90BE6D);  // Retro Green
  
  static const Color genderMascDark = Color(0xFF5AA5C6); // Lighter Blue for Dark Mode
  static const Color genderFemDark = Color(0xFFFF8A8C);  // Lighter Red for Dark Mode
  static const Color genderNeuDark = Color(0xFFB5DB99);  // Lighter Green for Dark Mode

  static const Color genderPlural = Color(0xFFF9844A); // Retro Orange (from palette)

  /// Returns harmonious CEFR badge colors (foreground, background, border)
  /// tailored for Light and Dark themes to avoid clashing with grammatical genders.
  static CefrBadgeColors getCefrColors(String level, {bool isDark = false}) {
    switch (level.toUpperCase().trim()) {
      case 'A1':
        return isDark
            ? const CefrBadgeColors(
                foreground: Color(0xFF81C784),
                background: Color(0xFF1B3B22),
                border: Color(0xFF2E7D32),
              )
            : const CefrBadgeColors(
                foreground: Color(0xFF1B5E20),
                background: Color(0xFFE8F5E9),
                border: Color(0xFFC8E6C9),
              );
      case 'A2':
        return isDark
            ? const CefrBadgeColors(
                foreground: Color(0xFF4DB6AC),
                background: Color(0xFF133834),
                border: Color(0xFF00695C),
              )
            : const CefrBadgeColors(
                foreground: Color(0xFF00695C),
                background: Color(0xFFE0F2F1),
                border: Color(0xFFB2DFDB),
              );
      case 'B1':
        return isDark
            ? const CefrBadgeColors(
                foreground: Color(0xFF64B5F6),
                background: Color(0xFF152E4D),
                border: Color(0xFF1565C0),
              )
            : const CefrBadgeColors(
                foreground: Color(0xFF1565C0),
                background: Color(0xFFE3F2FD),
                border: Color(0xFFBBDEFB),
              );
      case 'B2':
        return isDark
            ? const CefrBadgeColors(
                foreground: Color(0xFFFBBF24),
                background: Color(0xFF422D0A),
                border: Color(0xFFB45309),
              )
            : const CefrBadgeColors(
                foreground: Color(0xFFB45309),
                background: Color(0xFFFEF3C7),
                border: Color(0xFFFDE68A),
              );
      case 'C1':
        return isDark
            ? const CefrBadgeColors(
                foreground: Color(0xFFA78BFA),
                background: Color(0xFF2E1C4E),
                border: Color(0xFF6D28D9),
              )
            : const CefrBadgeColors(
                foreground: Color(0xFF6D28D9),
                background: Color(0xFFEDE9FE),
                border: Color(0xFFDDD6FE),
              );
      case 'C2':
      default:
        return isDark
            ? const CefrBadgeColors(
                foreground: Color(0xFFFB7185),
                background: Color(0xFF3D101E),
                border: Color(0xFF9F1239),
              )
            : const CefrBadgeColors(
                foreground: Color(0xFF9F1239),
                background: Color(0xFFFFE4E6),
                border: Color(0xFFFECDD3),
              );
    }
  }

  static TextTheme _buildTextTheme(TextTheme base, ColorScheme colorScheme, [String fontFamily = 'Spline Sans']) {
    TextTheme baseTheme;
    
    switch (fontFamily) {
      case 'Lora':
        baseTheme = GoogleFonts.loraTextTheme(base);
        break;
      case 'Roboto':
        baseTheme = GoogleFonts.robotoTextTheme(base);
        break;
      case 'Merriweather':
        baseTheme = GoogleFonts.merriweatherTextTheme(base);
        break;
      case 'Open Sans':
        baseTheme = GoogleFonts.openSansTextTheme(base);
        break;
      case 'Lexend':
        baseTheme = GoogleFonts.lexendTextTheme(base);
        break;
      case 'Montserrat':
        baseTheme = GoogleFonts.montserratTextTheme(base);
        break;
      case 'Lato':
        baseTheme = GoogleFonts.latoTextTheme(base);
        break;

      case 'Spline Sans':
      default:
        baseTheme = GoogleFonts.splineSansTextTheme(base);
        break;
    }
    
    return baseTheme.copyWith(
      displayLarge: baseTheme.displayLarge?.copyWith(
        fontWeight: FontWeight.w800,
        color: colorScheme.onSurface,
        letterSpacing: -1.0,
      ),
      displayMedium: baseTheme.displayMedium?.copyWith(
        fontWeight: FontWeight.w800,
        color: colorScheme.onSurface,
        letterSpacing: -0.5,
      ),
      displaySmall: baseTheme.displaySmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: colorScheme.onSurface,
      ),
      headlineLarge: baseTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: colorScheme.onSurface,
        letterSpacing: -0.5,
      ),
      headlineMedium: baseTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: colorScheme.onSurface,
      ),
      headlineSmall: baseTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      titleLarge: baseTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      titleMedium: baseTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      titleSmall: baseTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurfaceVariant,
      ),
      bodyLarge: baseTheme.bodyLarge?.copyWith(
        fontSize: 16,
        height: 1.5,
        color: colorScheme.onSurface,
      ),
      bodyMedium: baseTheme.bodyMedium?.copyWith(
        fontSize: 14,
        height: 1.5,
        color: colorScheme.onSurface,
      ),
      bodySmall: baseTheme.bodySmall?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
      labelLarge: baseTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }
  
  static TextStyle getButtonTextStyle(String fontFamily, {FontWeight fontWeight = FontWeight.bold}) {
      switch (fontFamily) {
      case 'Lora':
        return GoogleFonts.lora(fontWeight: fontWeight, fontSize: 16);
      case 'Roboto':
        return GoogleFonts.roboto(fontWeight: fontWeight, fontSize: 16);
      case 'Merriweather':
        return GoogleFonts.merriweather(fontWeight: fontWeight, fontSize: 16);
      case 'Open Sans':
        return GoogleFonts.openSans(fontWeight: fontWeight, fontSize: 16);
      case 'Lexend':
        return GoogleFonts.lexend(fontWeight: fontWeight, fontSize: 16);
      case 'Montserrat':
        return GoogleFonts.montserrat(fontWeight: fontWeight, fontSize: 16);

      case 'Spline Sans':
      default:
        return GoogleFonts.splineSans(fontWeight: fontWeight, fontSize: 16);
    }
  }
  
  static TextStyle getAppBarTextStyle(String fontFamily, Color color) {
      TextStyle style;
      switch (fontFamily) {
      case 'Lora':
        style = GoogleFonts.lora(fontSize: 22, fontWeight: FontWeight.bold);
        break;
      case 'Roboto':
        style = GoogleFonts.roboto(fontSize: 22, fontWeight: FontWeight.bold);
        break;
      case 'Merriweather':
        style = GoogleFonts.merriweather(fontSize: 22, fontWeight: FontWeight.bold);
        break;
      case 'Open Sans':
        style = GoogleFonts.openSans(fontSize: 22, fontWeight: FontWeight.bold);
        break;
      case 'Lexend':
        style = GoogleFonts.lexend(fontSize: 22, fontWeight: FontWeight.bold);
        break;
      case 'Montserrat':
        style = GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.bold);
        break;
      case 'Lato':
        style = GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.bold);
        break;

      case 'Spline Sans':
      default:
        style = GoogleFonts.splineSans(fontSize: 22, fontWeight: FontWeight.bold);
        break;
    }
    return style.copyWith(color: color);
  }

  static Color _getSeedColor(AppColorTheme theme) {
    switch (theme) {
      case AppColorTheme.classic: return _classicSeed;
      case AppColorTheme.retroTeal: return _tealSeed;
      case AppColorTheme.retroBlue: return _blueSeed;
      case AppColorTheme.retroGold: return _goldSeed;
      case AppColorTheme.retroRust: return _rustSeed;
      case AppColorTheme.modernist: return _modernistSeed;
      case AppColorTheme.retroPurple: return _purpleSeed;
      case AppColorTheme.slateGrey: return _slateSeed;
    }
  }

  static Color _getBackgroundColor(AppColorTheme theme) {
    if (theme == AppColorTheme.modernist) return _modernistBg;
    if (theme == AppColorTheme.retroPurple) return _purpleBg;
    if (theme == AppColorTheme.slateGrey) return _slateBg;
    return theme == AppColorTheme.classic ? _classicBg : _retroBg;
  }

  // Light Theme
  static ThemeData lightTheme(String fontFamily, [AppColorTheme theme = AppColorTheme.modernist]) {
    final seed = _getSeedColor(theme);
    final bg = _getBackgroundColor(theme);

    // Generate base scheme
    final baseScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
      surface: bg, 
      surfaceContainer: const Color(0xFFF2EEE7),
    );

    // Override primary to match seed exactly
    final colorScheme = baseScheme.copyWith(
      primary: seed,
      // Ensure onPrimary is visible. 
      // For Gold (EE9B00), white text is poor contrast. Black is better.
      // For others (Red, Teal, Blue, Rust), White is fine.
      onPrimary: theme == AppColorTheme.retroGold ? Colors.black : Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bg,
      
      // Typography
      textTheme: _buildTextTheme(ThemeData.light().textTheme, colorScheme, fontFamily),
      
      // Component Themes
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        margin: EdgeInsets.zero,
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: getButtonTextStyle(fontFamily),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
      ),

      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
        ),
      ),

      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      snackBarTheme: SnackBarThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
            // Standardize generic icon buttons if needed
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent, // Disable default scroll tint
        elevation: 0,
        centerTitle: false,
        titleTextStyle: getAppBarTextStyle(fontFamily, colorScheme.onSurface),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      
      dividerColor: colorScheme.outlineVariant,
    );
  }

  // Dark Theme
  static ThemeData darkTheme(String fontFamily, [AppColorTheme theme = AppColorTheme.modernist]) {
    final seed = _getSeedColor(theme);
    
    final baseScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    );

    final colorScheme = baseScheme.copyWith(
      // For Dark Mode, usually we want a lighter Primary (Tone 80).
      // But if user wants "seed color reflected", we might want to stick closer to it?
      // Actually, in Dark Mode, forcing the exact seed (which is often dark/saturated) might be bad for visibility against dark bg.
      // But let's try to honor it if it's usable.
      // Gold (EE9B00) is bright enough. Teal (2BBAA5) is bright enough.
      // Blue (005F73) is VERY dark. It will be invisible on dark grey.
      // So for Dark Theme, we should probably NOT override primary with a dark seed like 005F73.
      // Let's only override if it's safe, or let fromSeed handle dark mode mapping which is usually smart.
      // Or maybe the user primarily cares about Light Mode matching?
      // Let's override primary ONLY for light mode for now ensuring exact match.
      // And for Dark Mode let's manually pick a harmonizing color if needed, or just let it be.
      // Re-reading user request: "I don't think all the seed colors are properly being reflected".
      // Usually users test in Light Mode first.
      // I will leave Dark Theme as generated (safe) and only override Light Theme (branding).
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      
      // Typography
      textTheme: _buildTextTheme(ThemeData.dark().textTheme, colorScheme, fontFamily),
      
      // Component Themes
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        margin: EdgeInsets.zero,
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: getButtonTextStyle(fontFamily),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
      ),

      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
        ),
      ),

      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      snackBarTheme: SnackBarThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: getAppBarTextStyle(fontFamily, colorScheme.onSurface),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),

      dividerColor: colorScheme.outlineVariant,
    );
  }
}
