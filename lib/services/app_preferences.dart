import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  static const String _playerNameKey = 'player_name';

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
      await preferences.setString(
        _playerNameKey,
        value,
      );
    }
  }
}