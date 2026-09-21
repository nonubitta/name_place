import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../models/game_history.dart';
import '../models/player.dart';
import '../services/game_history_service.dart';

class FinalScoreboardPage extends StatefulWidget {
  final List<Player> players;
  final Map<String, int> totalScores;

  const FinalScoreboardPage({
    super.key,
    required this.players,
    required this.totalScores,
  });

  @override
  State<FinalScoreboardPage> createState() =>
      _FinalScoreboardPageState();
}

class _FinalScoreboardPageState
    extends State<FinalScoreboardPage> {
  late final ConfettiController _confettiController;

  GameHistory? _gameHistory;
  bool _loading = true;

  @override
  void initState() {
    super.initState();

    _confettiController = ConfettiController(
      duration: const Duration(seconds: 4),
    );

    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history =
        await GameHistoryService.loadCurrentGame();

    if (!mounted) {
      return;
    }

    setState(() {
      _gameHistory = history;
      _loading = false;
    });

    if (_sortedScoreEntries().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _confettiController.play();
        }
      });
    }
  }

  List<String> _playerIds() {
    final ids = <String>{
      'host',
      ...widget.players.map((player) => player.id),
      ...widget.totalScores.keys,
    };

    if (_gameHistory != null) {
      ids.addAll(_gameHistory!.players.keys);

      if (_gameHistory!.rounds.isNotEmpty) {
        ids.addAll(
          _gameHistory!.rounds.last.totalScores.keys,
        );
      }
    }

    return ids.toList();
  }

  String _playerName(String playerId) {
    String? name;

    if (_gameHistory != null) {
      name = _gameHistory!.players[playerId];
    }

    if (name == null || name.trim().isEmpty) {
      for (final player in widget.players) {
        if (player.id == playerId) {
          name = player.name;
          break;
        }
      }
    }

    if (name == null || name.trim().isEmpty) {
      name = playerId == 'host'
          ? 'Host'
          : 'Player';
    }

    return playerId == 'host'
        ? '$name (Host)'
        : name;
  }

  int _totalScore(String playerId) {
    if (_gameHistory != null &&
        _gameHistory!.rounds.isNotEmpty) {
      final latestRound =
          _gameHistory!.rounds.last;

      final historyScore =
          latestRound.totalScores[playerId];

      if (historyScore != null) {
        return historyScore;
      }
    }

    return widget.totalScores[playerId] ?? 0;
  }

  List<MapEntry<String, int>> _sortedScoreEntries() {
    final entries = _playerIds()
        .map(
          (playerId) => MapEntry(
            playerId,
            _totalScore(playerId),
          ),
        )
        .toList();

    entries.sort((a, b) {
      final scoreComparison =
          b.value.compareTo(a.value);

      if (scoreComparison != 0) {
        return scoreComparison;
      }

      return _playerName(a.key)
          .toLowerCase()
          .compareTo(
            _playerName(b.key).toLowerCase(),
          );
    });

    return entries;
  }

  Widget _buildPodium(
    BuildContext context,
    List<MapEntry<String, int>> entries,
  ) {
    final top = entries.take(3).toList();

    if (top.isEmpty) {
      return const SizedBox.shrink();
    }

    final first = top.isNotEmpty ? top[0] : null;
    final second =
        top.length > 1 ? top[1] : null;
    final third =
        top.length > 2 ? top[2] : null;

    return Column(
      children: [
        if (first != null)
          _buildWinnerCard(
            context,
            first,
          ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment:
              CrossAxisAlignment.end,
          children: [
            if (second != null)
              Expanded(
                child: _buildPlaceCard(
                  context,
                  second,
                  2,
                  Icons.looks_two_outlined,
                ),
              ),
            if (second != null && third != null)
              const SizedBox(width: 12),
            if (third != null)
              Expanded(
                child: _buildPlaceCard(
                  context,
                  third,
                  3,
                  Icons.looks_3_outlined,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildWinnerCard(
    BuildContext context,
    MapEntry<String, int> entry,
  ) {
    final scheme =
        Theme.of(context).colorScheme;

    return Card(
      elevation: 5,
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
          20,
          20,
          20,
          18,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              scheme.primaryContainer,
              scheme.surface,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.workspace_premium,
              size: 56,
            ),
            const SizedBox(height: 4),
            const Text(
              'WINNER',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _playerName(entry.key),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${entry.value} points',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: scheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceCard(
    BuildContext context,
    MapEntry<String, int> entry,
    int place,
    IconData icon,
  ) {
    final suffix =
        place == 2 ? 'ND' : 'RD';

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          10,
          16,
          10,
          14,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 34,
            ),
            const SizedBox(height: 6),
            Text(
              '$place$suffix PLACE',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              _playerName(entry.key),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${entry.value} pts',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemainingPlayers(
    BuildContext context,
    List<MapEntry<String, int>> entries,
  ) {
    if (entries.length <= 3) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              8,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Final Standings',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          ...entries
              .skip(3)
              .toList()
              .asMap()
              .entries
              .map(
            (item) {
              final index = item.key + 4;
              final entry = item.value;

              return ListTile(
                leading: CircleAvatar(
                  radius: 17,
                  child: Text('$index'),
                ),
                title: Text(
                  _playerName(entry.key),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: Text(
                  '${entry.value}',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRoundSummary() {
    final rounds =
        _gameHistory?.rounds ?? [];

    if (rounds.isEmpty) {
      return const SizedBox.shrink();
    }

    final playerCount =
        _playerIds().length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Game Summary',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _summaryItem(
                    Icons.sports_score_outlined,
                    '${rounds.length}',
                    rounds.length == 1
                        ? 'Round'
                        : 'Rounds',
                  ),
                ),
                Expanded(
                  child: _summaryItem(
                    Icons.people_outline,
                    '$playerCount',
                    playerCount == 1
                        ? 'Player'
                        : 'Players',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(
    IconData icon,
    String value,
    String label,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          size: 25,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label),
      ],
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Final Scoreboard',
          ),
          automaticallyImplyLeading: false,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final entries =
        _sortedScoreEntries();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Final Scoreboard',
        ),
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                16,
                16,
                16,
                28,
              ),
              children: [
                const Text(
                  'GAME COMPLETE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Congratulations!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                if (entries.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'No scores recorded.',
                        ),
                      ),
                    ),
                  )
                else ...[
                  _buildPodium(
                    context,
                    entries,
                  ),
                  const SizedBox(height: 16),
                  _buildRemainingPlayers(
                    context,
                    entries,
                  ),
                  const SizedBox(height: 16),
                  _buildRoundSummary(),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context)
                          .popUntil(
                        (route) => route.isFirst,
                      );
                    },
                    icon: const Icon(
                      Icons.home_outlined,
                    ),
                    label: const Text(
                      'DONE',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          IgnorePointer(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController:
                    _confettiController,
                blastDirectionality:
                    BlastDirectionality.explosive,
                shouldLoop: false,
                numberOfParticles: 35,
                maxBlastForce: 28,
                minBlastForce: 10,
                emissionFrequency: 0.04,
                gravity: 0.22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}