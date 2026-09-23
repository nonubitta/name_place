import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  static const String _playerNameKey = 'player_name';
  static const String _categoriesKey = 'game_categories';
  static const String _roundDurationKey = 'round_duration';

  static const int defaultRoundDuration = 30;

  static const List<int> roundDurationOptions = [15, 30, 45, 60, 90, 120];

  static const List<String> defaultCategories = [
    'Name',
    'Place',
    'Animal',
    'Thing',
  ];

  // --------------------------------------------------
  // Categories Export/Import
  // --------------------------------------------------

  /// Opens a save dialog for the categories JSON file.
  static Future<Uri?> exportCategories({
    String fileName = 'categories.json',
  }) async {
    final categories = await getCategories();

    final jsonData = {
      'categories': categories,
      'exportedAt': DateTime.now().toIso8601String(),
      'version': 1,
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(jsonData);

    return FilePicker.saveFile(
      fileName: fileName,
      bytes: utf8.encode(jsonString),
      mimeType: 'application/json',
      dialogTitle: 'Save categories',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
  }

  /// Imports categories from a JSON file.
  /// Returns the number of categories imported, or null if failed.
  static Future<int?> importCategories(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return null;
      }

      final jsonString = await file.readAsString();
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;

      final categories = jsonData['categories'];
      if (categories is! List) {
        return null;
      }

      final importedCategories = categories
          .map((c) => c.toString().trim())
          .where((c) => c.isNotEmpty)
          .toList();

      if (importedCategories.isEmpty) {
        return null;
      }

      await setCategories(importedCategories);
      return importedCategories.length;
    } catch (e) {
      return null;
    }
  }

  /// Picks a JSON file and imports categories from it.
  /// Returns the number of categories imported, or null if failed/cancelled.
  static Future<int?> pickAndImportCategories() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'Select categories JSON file',
      );

      if (files.isEmpty) {
        return null; // User cancelled
      }

      final filePath = files.single.path;
      if (filePath == null) {
        return null;
      }

      return await importCategories(filePath);
    } catch (e) {
      return null;
    }
  }

  static Future<String> getPlayerName() async {
    final preferences = await SharedPreferences.getInstance();

    return preferences.getString(_playerNameKey) ?? '';
  }

  static Future<void> setPlayerName(String name) async {
    final preferences = await SharedPreferences.getInstance();

    final value = name.trim();

    if (value.isEmpty) {
      await preferences.remove(_playerNameKey);
    } else {
      await preferences.setString(_playerNameKey, value);
    }
  }

  static Future<List<String>> getCategories() async {
    final preferences = await SharedPreferences.getInstance();

    final categories = preferences.getStringList(_categoriesKey);

    if (categories == null || categories.isEmpty) {
      return List<String>.from(defaultCategories);
    }

    return categories
        .map((category) => category.trim())
        .where((category) => category.isNotEmpty)
        .toList();
  }

  static Future<void> setCategories(List<String> categories) async {
    final preferences = await SharedPreferences.getInstance();

    final cleaned = categories
        .map((category) => category.trim())
        .where((category) => category.isNotEmpty)
        .toList();

    if (cleaned.isEmpty) {
      await preferences.remove(_categoriesKey);
      return;
    }

    await preferences.setStringList(_categoriesKey, cleaned);
  }

  static Future<void> resetCategories() async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.remove(_categoriesKey);
  }

  // --------------------------------------------------
  // Time / Round
  // --------------------------------------------------

  static Future<int> getRoundDuration() async {
    final preferences = await SharedPreferences.getInstance();

    final value = preferences.getInt(_roundDurationKey);

    if (value == null || value <= 0) {
      return defaultRoundDuration;
    }

    return value;
  }

  static Future<void> setRoundDuration(int seconds) async {
    final preferences = await SharedPreferences.getInstance();

    if (seconds <= 0) {
      await preferences.setInt(_roundDurationKey, defaultRoundDuration);
      return;
    }

    await preferences.setInt(_roundDurationKey, seconds);
  }

  static Future<void> resetRoundDuration() async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.remove(_roundDurationKey);
  }
}
