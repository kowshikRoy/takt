import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Primary Brand Color
  static const Color primarySeed = Color(0xFFEA2A33);
  
  // Custom semantic colors that might not map directly to Scheme
  static const Color genderMasc = Color(0xFF006493); // M3 Blue tone (Light)
  static const Color genderFem = Color(0xFFBA1A1A);  // M3 Red tone (Light)
  static const Color genderNeu = Color(0xFF1A6C30);  // M3 Green tone (Light)
  
  static const Color genderMascDark = Color(0xFF68C6FF); // M3 Blue tone (Dark)
  static const Color genderFemDark = Color(0xFFFFB4AB);  // M3 Red tone (Dark)
  static const Color genderNeuDark = Color(0xFF8CD69D);  // M3 Green tone (Dark)

  static const Color genderPlural = Color(0xFFF97316); // Orange

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

  // Light Theme
  static ThemeData lightTheme(String fontFamily) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primarySeed,
      brightness: Brightness.light,
      surface: const Color(0xFFFDF8F8), // Warm tinted surface
      surfaceContainer: const Color(0xFFFFFFFF), // Pure white cards
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFFDF8F8),
      
      // Typography
      textTheme: _buildTextTheme(ThemeData.light().textTheme, colorScheme, fontFamily),
      
      // Component Themes
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
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
          shape: const StadiumBorder(), // Expressive Roundness
          textStyle: getButtonTextStyle(fontFamily),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
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
  static ThemeData darkTheme(String fontFamily) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primarySeed,
      brightness: Brightness.dark,
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
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        margin: EdgeInsets.zero,
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: getButtonTextStyle(fontFamily),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
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
