import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeProvider() {
    _loadTheme();
  }

  ThemeMode get themeMode => _themeMode;

  void setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.toString());
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
    
    final String? fontStr = prefs.getString('font_family');
    if (fontStr != null) {
      _fontFamily = fontStr;
    }
    notifyListeners();
  }
}
