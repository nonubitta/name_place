import 'package:flutter/material.dart';

import '../models/player.dart';

class ScoreboardPage extends StatelessWidget {
  final List<Player> players;
  final Map<String, int> totalScores;

  const ScoreboardPage({
    super.key,
    required this.players,
    required this.totalScores,
  });

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
    final playerIds = <String>{
      'host',
      ...players.map((player) => player.id),
      ...totalScores.keys,
    };

    final entries = playerIds.map((playerId) {
      return MapEntry(
        playerId,
        totalScores[playerId] ?? 0,
      );
    }).toList();

    entries.sort(
      (a, b) => b.value.compareTo(a.value),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scoreboard'),
      ),
      body: entries.isEmpty
          ? const Center(
              child: Text(
                'No scores yet.',
                style: TextStyle(fontSize: 18),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final entry = entries[index];
                final playerId = entry.key;
                final score = entry.value;

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        '${index + 1}',
                      ),
                    ),
                    title: Text(
                      _playerName(playerId),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing: Text(
                      '$score',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}