class PlayerScore {
  final String playerId;
  final Map<String, int> categoryScores;
  final int totalScore;

  const PlayerScore({
    required this.playerId,
    required this.categoryScores,
    required this.totalScore,
  });

  Map<String, dynamic> toJson() {
    return {
      'playerId': playerId,
      'categoryScores': categoryScores,
      'totalScore': totalScore,
    };
  }

  factory PlayerScore.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawScores = json['categoryScores'];

    final categoryScores = <String, int>{};

    if (rawScores is Map) {
      rawScores.forEach((key, value) {
        categoryScores[key.toString()] =
            int.tryParse(value.toString()) ?? 0;
      });
    }

    return PlayerScore(
      playerId: json['playerId']?.toString() ?? '',
      categoryScores: categoryScores,
      totalScore:
          int.tryParse(json['totalScore']?.toString() ?? '0') ?? 0,
    );
  }
}