import 'package:flutter/material.dart';
import '../models/player_score.dart';
import '../models/player.dart';
import '../models/player_answers.dart';

class ResultsPage extends StatelessWidget {
  final int round;
  final String letter;
  final List<Player> players;
  final Map<String, PlayerAnswers> submissions;
  final List<PlayerScore> scores;
  const ResultsPage({
    super.key,
    required this.round,
    required this.letter,
    required this.players,
    required this.submissions,
    required this.scores,
  });

  PlayerScore? _scoreFor(String playerId) {
    for (final score in scores) {
      if (score.playerId == playerId) {
        return score;
      }
    }

    return null;
  }

  String _playerName(String playerId) {
    if (playerId == 'host') {
      return 'Host';
    }

    for (final player in players) {
      if (player.id == playerId) {
        return player.name;
      }
    }

    return 'Player';
  }

  @override
  Widget build(BuildContext context) {
    final entries = submissions.entries.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Round $round Results'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildRoundHeader(context),

            Expanded(
              child: entries.isEmpty
                  ? const Center(
                      child: Text(
                        'No submissions.',
                        style: TextStyle(fontSize: 18),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];

                        return _buildPlayerCard(
                          context,
                          entry.key,
                          entry.value,
                        );
                      },
                    ),
            ),

            _buildBottomBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildRoundHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        children: [
          Text(
            'ROUND $round',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),

          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Letter:', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                letter,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

Widget _buildPlayerCard(
  BuildContext context,
  String playerId,
  PlayerAnswers submission,
) {
  final playerName = _playerName(playerId);
  final playerScore = _scoreFor(playerId);

  return Card(
    margin: const EdgeInsets.only(bottom: 14),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                child: Text(
                  playerName.isNotEmpty
                      ? playerName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  playerName,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              Text(
                '${playerScore?.totalScore ?? 0} pts',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const Divider(height: 24),

          for (final answer in submission.answers.entries)
            _buildAnswerRow(
              answer.key,
              answer.value,
              playerScore?.categoryScores[answer.key] ?? 0,
            ),
        ],
      ),
    ),
  );
}

  Widget _buildAnswerRow(String category, String answer, int points) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              category,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              answer.isEmpty ? '—' : answer,
              style: TextStyle(
                fontSize: 16,
                color: answer.isEmpty ? Colors.grey : null,
              ),
            ),
          ),

          Text(
            '+$points',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: points == 0 ? Colors.grey : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: null,
            child: const Text(
              'NEXT ROUND',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
          ),
        ),
      ),
    );
  }
}
