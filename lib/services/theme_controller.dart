import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/vibrant_palette.dart';

class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance = ThemeController._();

  static const String _darkThemeKey = 'dark_theme';

  bool _isDark = true;

  bool get isDark => _isDark;

  /// The vibrant palette used to color the light theme. A new random palette
  /// is chosen each time the app starts so every session feels fresh.
  VibrantPalette _lightPalette = VibrantPalette.random();

  VibrantPalette get lightPalette => _lightPalette;

  /// Picks a new random palette for the light theme and notifies listeners.
  void shuffleLightPalette() {
    _lightPalette = VibrantPalette.random();
    notifyListeners();
  }

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
