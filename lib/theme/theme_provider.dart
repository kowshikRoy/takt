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
      notifyListeners();
    }
  }
}
