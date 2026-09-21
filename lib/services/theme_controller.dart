import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance = ThemeController._();

  static const String _darkThemeKey = 'dark_theme';

  bool _isDark = true;

  bool get isDark => _isDark;

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();

    _isDark = preferences.getBool(_darkThemeKey) ?? true;
    notifyListeners();
  }

  Future<void> setDarkTheme(bool value) async {
    if (_isDark == value) {
      return;
    }

    _isDark = value;
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_darkThemeKey, value);
  }
}