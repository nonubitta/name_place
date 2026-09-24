import 'package:flutter/material.dart';

import '../utils/vibrant_palette.dart';

class AppTheme {
  AppTheme._();

  static const Color _background = Color(0xFF181A1F);
  static const Color _surface = Color(0xFF22242B);
  static const Color _elevated = Color(0xFF2A2D35);
  static const Color _primary = Color(0xFF9B7BFF);
  static const Color _secondary = Color(0xFFB8A1FF);
  static const Color _text = Color(0xFFF4F2FA);
  static const Color _muted = Color(0xFFAAA8B3);
  static const Color _border = Color(0xFF3A3D46);

  static ThemeData dark() {
    final colorScheme = ColorScheme.dark(
      primary: _primary,
      onPrimary: Colors.white,
      secondary: _secondary,
      onSecondary: Colors.black,
      surface: _surface,
      onSurface: _text,
      surfaceContainerHighest: _elevated,
      onSurfaceVariant: _muted,
      outline: _border,
      error: const Color(0xFFFF6B7A),
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _background,
      appBarTheme: const AppBarTheme(
        backgroundColor: _background,
        foregroundColor: _text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: const CardThemeData(
        color: _surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: _border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _elevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
        labelStyle: const TextStyle(color: _muted),
        hintStyle: const TextStyle(color: _muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _secondary,
          side: const BorderSide(color: _border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: _secondary),
      ),
      iconTheme: const IconThemeData(color: _secondary),
      listTileTheme: const ListTileThemeData(iconColor: _secondary),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _elevated,
        contentTextStyle: const TextStyle(color: _text),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(_surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _primary;
          }
          return _muted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _primary.withValues(alpha: 0.35);
          }
          return _border;
        }),
      ),
    );
  }

  static ThemeData light(VibrantPalette palette) {
    final background = palette.background;
    final onColor = palette.onBackground;
    final translucentSurface = Colors.white.withValues(alpha: 0.16);
    final translucentSurfaceStrong = Colors.white.withValues(alpha: 0.24);
    final translucentBorder = onColor.withValues(alpha: 0.45);
    final mutedOnColor = onColor.withValues(alpha: 0.75);

    final colorScheme = ColorScheme.light(
      primary: Colors.white,
      onPrimary: background,
      secondary: palette.accent,
      onSecondary: background,
      surface: background,
      onSurface: onColor,
      surfaceContainerHighest: translucentSurface,
      onSurfaceVariant: mutedOnColor,
      outline: translucentBorder,
      error: const Color(0xFFFFD1D1),
      onError: const Color(0xFF7A1020),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: onColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: onColor,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: onColor),
      ),
      cardTheme: CardThemeData(
        color: translucentSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(
        color: onColor.withValues(alpha: 0.2),
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: translucentSurfaceStrong,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: translucentBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: translucentBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: onColor, width: 1.5),
        ),
        labelStyle: TextStyle(color: mutedOnColor),
        hintStyle: TextStyle(color: mutedOnColor),
        prefixIconColor: onColor,
        suffixIconColor: onColor,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          elevation: 2,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onColor,
          backgroundColor: translucentSurface,
          side: BorderSide(color: translucentBorder, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: onColor),
      ),
      iconTheme: IconThemeData(color: onColor),
      listTileTheme: ListTileThemeData(iconColor: onColor, textColor: onColor),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.backgroundGradientEnd,
        contentTextStyle: TextStyle(color: onColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.backgroundGradientEnd,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: onColor,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(color: mutedOnColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(
            palette.backgroundGradientEnd,
          ),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return mutedOnColor;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white.withValues(alpha: 0.4);
          }
          return onColor.withValues(alpha: 0.2);
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: onColor),
    );
  }
}