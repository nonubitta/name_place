class PlayerAnswers {
  final String playerId;
  final Map<String, String> answers;
  final bool submitted;

  const PlayerAnswers({
    required this.playerId,
    required this.answers,
    this.submitted = false,
  });

  PlayerAnswers copyWith({
    String? playerId,
    Map<String, String>? answers,
    bool? submitted,
  }) {
    return PlayerAnswers(
      playerId: playerId ?? this.playerId,
      answers: answers ?? this.answers,
      submitted: submitted ?? this.submitted,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'playerId': playerId,
      'answers': answers,
      'submitted': submitted,
    };
  }

  factory PlayerAnswers.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawAnswers = json['answers'];

    final answers = <String, String>{};

    if (rawAnswers is Map) {
      rawAnswers.forEach((key, value) {
        answers[key.toString()] = value?.toString() ?? '';
      });
    }

    return PlayerAnswers(
      playerId: json['playerId']?.toString() ?? '',
      answers: answers,
      submitted: json['submitted'] == true,
    );
  }
}