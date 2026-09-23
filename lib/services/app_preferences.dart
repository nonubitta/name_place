import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  static const String _playerNameKey = 'player_name';
  static const String _categoriesKey = 'game_categories';
  static const String _roundDurationKey = 'round_duration';

  static const int defaultRoundDuration = 30;

  static const List<int> roundDurationOptions = [
    15,
    30,
    45,
    60,
    90,
    120,
  ];

  static const List<String> defaultCategories = [
    'Name',
    'Place',
    'Animal',
    'Thing',
  ];

  static Future<String> getPlayerName() async {
    final preferences =
        await SharedPreferences.getInstance();

    return preferences.getString(_playerNameKey) ?? '';
  }

  static Future<void> setPlayerName(
    String name,
  ) async {
    final preferences =
        await SharedPreferences.getInstance();

    final value = name.trim();

    if (value.isEmpty) {
      await preferences.remove(_playerNameKey);
    } else {
      await preferences.setString(
        _playerNameKey,
        value,
      );
    }
  }

  static Future<List<String>> getCategories() async {
    final preferences =
        await SharedPreferences.getInstance();

    final categories =
        preferences.getStringList(
      _categoriesKey,
    );

    if (categories == null ||
        categories.isEmpty) {
      return List<String>.from(
        defaultCategories,
      );
    }

    return categories
        .map((category) => category.trim())
        .where(
          (category) => category.isNotEmpty,
        )
        .toList();
  }

  static Future<void> setCategories(
    List<String> categories,
  ) async {
    final preferences =
        await SharedPreferences.getInstance();

    final cleaned = categories
        .map((category) => category.trim())
        .where(
          (category) => category.isNotEmpty,
        )
        .toList();

    if (cleaned.isEmpty) {
      await preferences.remove(_categoriesKey);
      return;
    }

    await preferences.setStringList(
      _categoriesKey,
      cleaned,
    );
  }

  static Future<void> resetCategories() async {
    final preferences =
        await SharedPreferences.getInstance();

    await preferences.remove(
      _categoriesKey,
    );
  }

  // --------------------------------------------------
  // Time / Round
  // --------------------------------------------------

  static Future<int> getRoundDuration() async {
    final preferences =
        await SharedPreferences.getInstance();

    final value = preferences.getInt(
      _roundDurationKey,
    );

    if (value == null ||
        value <= 0) {
      return defaultRoundDuration;
    }

    return value;
  }

  static Future<void> setRoundDuration(
    int seconds,
  ) async {
    final preferences =
        await SharedPreferences.getInstance();

    if (seconds <= 0) {
      await preferences.setInt(
        _roundDurationKey,
        defaultRoundDuration,
      );
      return;
    }

    await preferences.setInt(
      _roundDurationKey,
      seconds,
    );
  }

  static Future<void> resetRoundDuration() async {
    final preferences =
        await SharedPreferences.getInstance();

    await preferences.remove(
      _roundDurationKey,
    );
  }


}