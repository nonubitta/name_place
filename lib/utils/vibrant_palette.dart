import 'dart:math';

import 'package:flutter/material.dart';

/// A vibrant color palette used to give the light theme a colorful,
/// playful look (see the reference: green "Host", blue "Join",
/// purple "Round" screens).
class VibrantPalette {
  const VibrantPalette({
    required this.name,
    required this.background,
    required this.backgroundGradientEnd,
    required this.accent,
    required this.onBackground,
  });

  /// A human readable name (useful for debugging).
  final String name;

  /// The main scaffold background color.
  final Color background;

  /// A slightly shifted color used for a subtle gradient.
  final Color backgroundGradientEnd;

  /// A bright accent used for primary buttons.
  final Color accent;

  /// Foreground color that reads well on [background].
  final Color onBackground;

  /// All the palettes we can randomly pick from.
  static const List<VibrantPalette> palettes = [
    VibrantPalette(
      name: 'Emerald',
      background: Color(0xFF1FA35B),
      backgroundGradientEnd: Color(0xFF0E7A41),
      accent: Color(0xFFFFFFFF),
      onBackground: Colors.white,
    ),
    VibrantPalette(
      name: 'Ocean',
      background: Color(0xFF2E7CF6),
      backgroundGradientEnd: Color(0xFF1657C8),
      accent: Color(0xFFBFE0FF),
      onBackground: Colors.white,
    ),
    VibrantPalette(
      name: 'Grape',
      background: Color(0xFF7A3FF2),
      backgroundGradientEnd: Color(0xFF531FBF),
      accent: Color(0xFFFFD166),
      onBackground: Colors.white,
    ),
    VibrantPalette(
      name: 'Teal',
      background: Color.fromARGB(255, 2, 219, 200),
      backgroundGradientEnd: Color(0xFF068C82),
      accent: Color(0xFFFFFFFF),
      onBackground: Colors.white,
    ),
    // VibrantPalette(
    //   name: 'Ruby',
    //   background: Color(0xFFE53958),
    //   backgroundGradientEnd: Color(0xFFB91F3E),
    //   accent: Color(0xFFFFD6DE),
    //   onBackground: Colors.white,
    // ),

    VibrantPalette(
      name: 'Sky',
      background: Color(0xFF1597E5),
      backgroundGradientEnd: Color(0xFF0870B5),
      accent: Color(0xFFCBEAFF),
      onBackground: Colors.white,
    ),

    VibrantPalette(
      name: 'Indigo',
      background: Color(0xFF5967E8),
      backgroundGradientEnd: Color(0xFF3542B8),
      accent: Color(0xFFD9DDFF),
      onBackground: Colors.white,
    ),

    VibrantPalette(
      name: 'Violet',
      background: Color(0xFF9B4DEB),
      backgroundGradientEnd: Color(0xFF7025B8),
      accent: Color(0xFFEBD5FF),
      onBackground: Colors.white,
    ),

    VibrantPalette(
      name: 'Berry',
      background: Color(0xFFB83A8F),
      backgroundGradientEnd: Color(0xFF822363),
      accent: Color(0xFFFFD8EF),
      onBackground: Colors.white,
    ),

    VibrantPalette(
      name: 'Mint',
      background: Color(0xFF16A878),
      backgroundGradientEnd: Color(0xFF087C5A),
      accent: Color(0xFFC8F5E5),
      onBackground: Colors.white,
    ),

    VibrantPalette(
      name: 'Cyan',
      background: Color(0xFF0EA9C6),
      backgroundGradientEnd: Color(0xFF087E9A),
      accent: Color(0xFFC8F4FA),
      onBackground: Colors.white,
    ),

    VibrantPalette(
      name: 'Turquoise',
      background: Color(0xFF13AFA0),
      backgroundGradientEnd: Color(0xFF087D74),
      accent: Color(0xFFC7F3EF),
      onBackground: Colors.white,
    ),
    VibrantPalette(
      name: 'Plum',
      background: Color(0xFF7946A8),
      backgroundGradientEnd: Color(0xFF522B79),
      accent: Color(0xFFE8D8F7),
      onBackground: Colors.white,
    ),

    VibrantPalette(
      name: 'Steel',
      background: Color(0xFF4679A8),
      backgroundGradientEnd: Color(0xFF2D587F),
      accent: Color(0xFFD6E8F8),
      onBackground: Colors.white,
    ),
  ];

  static final Random _random = Random();

  /// Picks a random palette from [palettes].
  static VibrantPalette random() {
    return palettes[_random.nextInt(palettes.length)];
  }
}
