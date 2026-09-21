import 'player_answers.dart';
import 'player_score.dart';

class GameHistory {
  final String gameId;
  final String startedAt;
  final Map<String, String> players;
  final List<RoundHistory> rounds;

  const GameHistory({
    required this.gameId,
    required this.startedAt,
    required this.players,
    required this.rounds,
  });

  GameHistory copyWith({
    String? gameId,
    String? startedAt,
    Map<String, String>? players,
    List<RoundHistory>? rounds,
  }) {
    return GameHistory(
      gameId: gameId ?? this.gameId,
      startedAt: startedAt ?? this.startedAt,
      players: players ?? this.players,
      rounds: rounds ?? this.rounds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gameId': gameId,
      'startedAt': startedAt,
      'players': players,
      'rounds': rounds.map((round) => round.toJson()).toList(),
    };
  }

  factory GameHistory.fromJson(Map<String, dynamic> json) {
    final rawPlayers = json['players'];
    final players = <String, String>{};

    if (rawPlayers is Map) {
      rawPlayers.forEach((key, value) {
        players[key.toString()] = value?.toString() ?? '';
      });
    }

    final rawRounds = json['rounds'];
    final rounds = <RoundHistory>[];

    if (rawRounds is List) {
      for (final value in rawRounds) {
        if (value is Map) {
          rounds.add(
            RoundHistory.fromJson(
              Map<String, dynamic>.from(value),
            ),
          );
        }
      }
    }

    rounds.sort(
      (a, b) => a.round.compareTo(b.round),
    );

    return GameHistory(
      gameId: json['gameId']?.toString() ?? '',
      startedAt: json['startedAt']?.toString() ?? '',
      players: players,
      rounds: rounds,
    );
  }
}

class RoundHistory {
  final int round;
  final String letter;
  final Map<String, PlayerAnswers> submissions;
  final List<PlayerScore> scores;
  final Map<String, int> totalScores;

  const RoundHistory({
    required this.round,
    required this.letter,
    required this.submissions,
    required this.scores,
    required this.totalScores,
  });

  Map<String, dynamic> toJson() {
    return {
      'round': round,
      'letter': letter,
      'submissions': submissions.map(
        (playerId, submission) =>
            MapEntry(playerId, submission.toJson()),
      ),
      'scores': scores
          .map((score) => score.toJson())
          .toList(),
      'totalScores': totalScores,
    };
  }

  factory RoundHistory.fromJson(
    Map<String, dynamic> json,
  ) {
    final submissions =
        <String, PlayerAnswers>{};

    final rawSubmissions =
        json['submissions'];

    if (rawSubmissions is Map) {
      rawSubmissions.forEach((key, value) {
        if (value is Map) {
          submissions[key.toString()] =
              PlayerAnswers.fromJson(
            Map<String, dynamic>.from(value),
          );
        }
      });
    }

    final scores = <PlayerScore>[];

    final rawScores = json['scores'];

    if (rawScores is List) {
      for (final value in rawScores) {
        if (value is Map) {
          scores.add(
            PlayerScore.fromJson(
              Map<String, dynamic>.from(value),
            ),
          );
        }
      }
    }

    final totalScores = <String, int>{};

    final rawTotalScores =
        json['totalScores'];

    if (rawTotalScores is Map) {
      rawTotalScores.forEach((key, value) {
        totalScores[key.toString()] =
            int.tryParse(
                  value.toString(),
                ) ??
                0;
      });
    }

    return RoundHistory(
      round:
          int.tryParse(
                json['round']?.toString() ?? '0',
              ) ??
              0,
      letter:
          json['letter']?.toString() ?? '',
      submissions: submissions,
      scores: scores,
      totalScores: totalScores,
    );
  }
}