enum GamePhase {
  lobby,
  playing,
  results,
}

class GameState {
  final GamePhase phase;
  final String letter;
  final int round;
  final int timeRemaining;

  const GameState({
    required this.phase,
    required this.letter,
    required this.round,
    required this.timeRemaining,
  });

  const GameState.lobby()
      : phase = GamePhase.lobby,
        letter = '',
        round = 0,
        timeRemaining = 0;

  GameState copyWith({
    GamePhase? phase,
    String? letter,
    int? round,
    int? timeRemaining,
  }) {
    return GameState(
      phase: phase ?? this.phase,
      letter: letter ?? this.letter,
      round: round ?? this.round,
      timeRemaining:
          timeRemaining ?? this.timeRemaining,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'phase': phase.name,
      'letter': letter,
      'round': round,
      'timeRemaining': timeRemaining,
    };
  }

  factory GameState.fromJson(
    Map<String, dynamic> json,
  ) {
    final phaseName =
        json['phase']?.toString() ?? 'lobby';

    final phase = GamePhase.values.firstWhere(
      (value) => value.name == phaseName,
      orElse: () => GamePhase.lobby,
    );

    return GameState(
      phase: phase,
      letter: json['letter']?.toString() ?? '',
      round: int.tryParse(
            json['round']?.toString() ?? '0',
          ) ??
          0,
      timeRemaining: int.tryParse(
            json['timeRemaining']?.toString() ?? '0',
          ) ??
          0,
    );
  }

  @override
  String toString() {
    return 'GameState('
        'phase: ${phase.name}, '
        'letter: $letter, '
        'round: $round, '
        'timeRemaining: $timeRemaining'
        ')';
  }
}