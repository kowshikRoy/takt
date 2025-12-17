import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors from Tailwind config
  static const Color primary = Color(0xFFEA2A33);
  static const Color backgroundLight = Color(0xFFF8F6F6);
  static const Color backgroundDark = Color(0xFF211111);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF2D1B1B);
  
  static const Color genderMasc = Color(0xFF3B82F6); // Blue
  static const Color genderFem = Color(0xFFEF4444);  // Red
  static const Color genderNeu = Color(0xFF22C55E);  // Green
  static const Color genderPlural = Color(0xFFF97316); // Orange

  static const Color textMainLight = Color(0xFF1B0E0E);
  static const Color textMainDark = Color(0xFFFCF8F8);
  static const Color textSubLight = Color(0xFF665050);
  static const Color textSubDark = Color(0xFFB09A9A);
  
  static const Color borderLight = Color(0xFFE7D0D1);
  static const Color borderDark = Color(0xFF4A2B2B);

  // Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: backgroundLight,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: primary,
        surface: surfaceLight,
        background: backgroundLight,
        onBackground: textMainLight,
        onSurface: textMainLight,
      ),
      textTheme: GoogleFonts.splineSansTextTheme().apply(
        bodyColor: textMainLight,
        displayColor: textMainLight,
      ),
      useMaterial3: true,
      /*
      cardTheme: CardTheme(
        color: surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderLight),
        ),
      ),
      */
      dividerColor: borderLight,
      cardColor: surfaceLight,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.splineSans(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primary,
      scaffoldBackgroundColor: backgroundDark,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: primary,
        surface: surfaceDark,
        background: backgroundDark,
        onBackground: textMainDark,
        onSurface: textMainDark,
      ),
      textTheme: GoogleFonts.splineSansTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: textMainDark,
        displayColor: textMainDark,
      ),
      useMaterial3: true,
      dividerColor: borderDark,
      cardColor: surfaceDark,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.splineSans(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
