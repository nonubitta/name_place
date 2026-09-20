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
  final List<String> categories;

  const GameState({
    required this.phase,
    required this.letter,
    required this.round,
    required this.timeRemaining,
    required this.categories,
  });

  const GameState.lobby()
      : phase = GamePhase.lobby,
        letter = '',
        round = 0,
        timeRemaining = 0,
        categories = const [
          'Name',
          'Place',
          'Animal',
          'Thing',
        ];

  GameState copyWith({
    GamePhase? phase,
    String? letter,
    int? round,
    int? timeRemaining,
    List<String>? categories,
  }) {
    return GameState(
      phase: phase ?? this.phase,
      letter: letter ?? this.letter,
      round: round ?? this.round,
      timeRemaining: timeRemaining ?? this.timeRemaining,
      categories: categories ?? this.categories,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'phase': phase.name,
      'letter': letter,
      'round': round,
      'timeRemaining': timeRemaining,
      'categories': categories,
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

    final rawCategories = json['categories'];

    final categories = rawCategories is List
        ? rawCategories
            .map((value) => value.toString())
            .where((value) => value.trim().isNotEmpty)
            .toList()
        : <String>[
            'Name',
            'Place',
            'Animal',
            'Thing',
          ];

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
      categories: categories,
    );
  }

  @override
  String toString() {
    return 'GameState('
        'phase: ${phase.name}, '
        'letter: $letter, '
        'round: $round, '
        'timeRemaining: $timeRemaining, '
        'categories: $categories'
        ')';
  }
}