import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_history.dart';
import '../models/player.dart';
import '../models/player_answers.dart';
import '../models/player_score.dart';

class GameHistoryService {
  static const String _currentGameIdKey =
      'current_game_id';

  static Future<String?> get currentGameId async {
    final preferences =
        await SharedPreferences.getInstance();

    return preferences.getString(
      _currentGameIdKey,
    );
  }

  static Future<Directory>
      _getDirectory() async {
    return getApplicationDocumentsDirectory();
  }

  static String _fileName(String gameId) {
    final safeGameId = gameId.replaceAll(
      RegExp(r'[^a-zA-Z0-9_-]'),
      '_',
    );

    return 'game_$safeGameId.json';
  }

  static Future<File> _getFile(
    String gameId,
  ) async {
    final directory =
        await _getDirectory();

    return File(
      '${directory.path}/${_fileName(gameId)}',
    );
  }

  /// Creates the single JSON file for a new game.
  static Future<void> startGame({
    required String gameId,
    required List<Player> players,
  }) async {
    final history = GameHistory(
      gameId: gameId,
      startedAt:
          DateTime.now().toIso8601String(),
      players: {
        for (final player in players)
          player.id: player.name,
      },
      rounds: [],
    );

    final file =
        await _getFile(gameId);

    await file.writeAsString(
      const JsonEncoder.withIndent('  ')
          .convert(history.toJson()),
      flush: true,
    );

    final preferences =
        await SharedPreferences.getInstance();

    await preferences.setString(
      _currentGameIdKey,
      gameId,
    );
  }

  /// Loads the current game's JSON file.
  static Future<GameHistory?> loadCurrentGame()
      async {
    final gameId =
        await currentGameId;

    if (gameId == null ||
        gameId.trim().isEmpty) {
      return null;
    }

    return loadGame(gameId);
  }

  /// Loads a specific game.
  static Future<GameHistory?> loadGame(
    String gameId,
  ) async {
    final file =
        await _getFile(gameId);

    if (!await file.exists()) {
      return null;
    }

    try {
      final content =
          await file.readAsString();

      if (content.trim().isEmpty) {
        return null;
      }

      final json =
          jsonDecode(content);

      if (json is! Map) {
        return null;
      }

      return GameHistory.fromJson(
        Map<String, dynamic>.from(json),
      );
    } catch (e) {
      print(
        'Failed to load game history: $e',
      );

      return null;
    }
  }

  /// Updates the player names in the current
  /// game's single JSON file.
  static Future<void> updatePlayers({
    required String gameId,
    required List<Player> players,
  }) async {
    final history =
        await loadGame(gameId);

    if (history == null) {
      return;
    }

    final updatedPlayers =
        Map<String, String>.from(
      history.players,
    );

    for (final player in players) {
      updatedPlayers[player.id] =
          player.name;
    }

    final updatedHistory =
        history.copyWith(
      players: updatedPlayers,
    );

    await _writeHistory(
      updatedHistory,
    );
  }

  /// Saves one round into the game's existing
  /// JSON file.
  ///
  /// If the round already exists, it is replaced.
  /// This is important because the host can change
  /// scores after the initial results.
  static Future<void> saveRound({
    required String gameId,
    required int round,
    required String letter,
    required Map<String, PlayerAnswers>
        submissions,
    required List<PlayerScore> scores,
    required Map<String, int> totalScores,
  }) async {
    var history =
        await loadGame(gameId);

    if (history == null) {
      history = GameHistory(
        gameId: gameId,
        startedAt:
            DateTime.now().toIso8601String(),
        players: {},
        rounds: [],
      );
    }

    final roundHistory =
        RoundHistory(
      round: round,
      letter: letter,
      submissions:
          Map<String, PlayerAnswers>.from(
        submissions,
      ),
      scores:
          List<PlayerScore>.from(scores),
      totalScores:
          Map<String, int>.from(
        totalScores,
      ),
    );

    final rounds =
        List<RoundHistory>.from(
      history.rounds,
    );

    final existingIndex =
        rounds.indexWhere(
      (item) => item.round == round,
    );

    if (existingIndex >= 0) {
      rounds[existingIndex] =
          roundHistory;
    } else {
      rounds.add(roundHistory);
    }

    rounds.sort(
      (a, b) =>
          a.round.compareTo(b.round),
    );

    final updatedHistory =
        history.copyWith(
      rounds: rounds,
    );

    await _writeHistory(
      updatedHistory,
    );
  }

  /// Convenience method for saving the exact
  /// round_results message already received
  /// by every phone.
  static Future<void> saveRoundResults(
    Map<String, dynamic> message,
  ) async {
    final gameId =
        await currentGameId;

    if (gameId == null ||
        gameId.isEmpty) {
      print(
        'Cannot save round: no current game.',
      );
      return;
    }

    final round =
        int.tryParse(
              message['round']
                      ?.toString() ??
                  '0',
            ) ??
            0;

    final letter =
        message['letter']
                ?.toString() ??
            '';

    final submissions =
        <String, PlayerAnswers>{};

    final rawAnswers =
        message['answers'];

    if (rawAnswers is Map) {
      rawAnswers.forEach(
        (key, value) {
          if (value is Map) {
            submissions[key.toString()] =
                PlayerAnswers.fromJson(
              Map<String, dynamic>.from(
                value,
              ),
            );
          }
        },
      );
    }

    final scores =
        <PlayerScore>[];

    final rawScores =
        message['scores'];

    if (rawScores is List) {
      for (final value in rawScores) {
        if (value is Map) {
          scores.add(
            PlayerScore.fromJson(
              Map<String, dynamic>.from(
                value,
              ),
            ),
          );
        }
      }
    }

    final totalScores =
        <String, int>{};

    final rawTotalScores =
        message['totalScores'];

    if (rawTotalScores is Map) {
      rawTotalScores.forEach(
        (key, value) {
          totalScores[
                  key.toString()] =
              int.tryParse(
                    value.toString(),
                  ) ??
                  0;
        },
      );
    }

    await saveRound(
      gameId: gameId,
      round: round,
      letter: letter,
      submissions: submissions,
      scores: scores,
      totalScores: totalScores,
    );
  }

  static Future<void> _writeHistory(
    GameHistory history,
  ) async {
    final file =
        await _getFile(history.gameId);

    await file.writeAsString(
      const JsonEncoder.withIndent('  ')
          .convert(history.toJson()),
      flush: true,
    );
  }
}