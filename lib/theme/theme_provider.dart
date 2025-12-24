import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  AppColorTheme _colorTheme = AppColorTheme.retroTeal; // Default to new Teal theme

  ThemeProvider() {
    _loadTheme();
  }

  ThemeMode get themeMode => _themeMode;
  AppColorTheme get colorTheme => _colorTheme;

  void setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.toString());
  }

  void setColorTheme(AppColorTheme theme) async {
    _colorTheme = theme;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('color_theme', theme.toString());
  }

  void toggleTheme() {
    if (_themeMode == ThemeMode.dark) {
      setThemeMode(ThemeMode.light);
    } else {
      setThemeMode(ThemeMode.dark);
    }
  }

  String _fontFamily = 'Spline Sans';
  String get fontFamily => _fontFamily;

  void setFontFamily(String font) async {
    _fontFamily = font;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('font_family', font);
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final String? themeStr = prefs.getString('theme_mode');
    if (themeStr != null) {
      if (themeStr == ThemeMode.light.toString()) {
        _themeMode = ThemeMode.light;
      } else if (themeStr == ThemeMode.dark.toString()) {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.system;
      }
    }
    
    final String? colorThemeStr = prefs.getString('color_theme');
    if (colorThemeStr != null) {
      // Parse string 'AppColorTheme.classic' back to enum
      for (var theme in AppColorTheme.values) {
        if (theme.toString() == colorThemeStr) {
          _colorTheme = theme;
          break;
        }
      }
    }
    
    final String? fontStr = prefs.getString('font_family');
    if (fontStr != null) {
      _fontFamily = fontStr;
    }
    notifyListeners();
  }
}
