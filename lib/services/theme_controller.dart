import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/vibrant_palette.dart';

class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance = ThemeController._();

  static const String _darkThemeKey = 'dark_theme';
  static const String _lightPaletteKey = 'light_palette';

  bool _isDark = true;

  bool get isDark => _isDark;

  /// The vibrant palette used to color the light theme. A random palette is
  /// used until the player chooses and saves a preference.
  VibrantPalette _lightPalette = VibrantPalette.random();

  VibrantPalette get lightPalette => _lightPalette;

  /// Picks a new random palette for the light theme and notifies listeners.
  Future<void> shuffleLightPalette() async {
    _lightPalette = VibrantPalette.random();
    notifyListeners();
  }

  // Future<void> load() async {
  //   final preferences = await SharedPreferences.getInstance();

  //   _isDark = preferences.getBool(_darkThemeKey) ?? true;
  //   notifyListeners();
  // }

  Future<void> clearPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_lightPaletteKey);
    await shuffleLightPalette();
  }


  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();

    _isDark = preferences.getBool(_darkThemeKey) ?? true;

    final savedPaletteName = preferences.getString(_lightPaletteKey);
    if (savedPaletteName != null) {
      for (final palette in VibrantPalette.palettes) {
        if (palette.name == savedPaletteName) {
          _lightPalette = palette;
          break;
        }
      }
    }

    notifyListeners();
  }

  Future<void> setLightPalette(VibrantPalette palette) async {
    if (_lightPalette.name == palette.name) {
      return;
    }

    _lightPalette = palette;
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_lightPaletteKey, palette.name);
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
