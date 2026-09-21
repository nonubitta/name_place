import 'package:flutter/material.dart';

import '../models/game_history.dart';
import '../models/player.dart';
import '../services/game_history_service.dart';

class ScoreboardPage extends StatefulWidget {
  final List<Player> players;
  final Map<String, int> totalScores;

  /// Set this to true when the game has ended.
  final bool gameComplete;

  const ScoreboardPage({
    super.key,
    required this.players,
    required this.totalScores,
    this.gameComplete = false,
  });

  @override
  State<ScoreboardPage> createState() =>
      _ScoreboardPageState();
}

class _ScoreboardPageState
    extends State<ScoreboardPage> {
  GameHistory? _gameHistory;

  bool _loading = true;
  bool _showCompleteGame = false;

  @override
  void initState() {
    super.initState();

    _showCompleteGame = widget.gameComplete;

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
      name = 'Player';
    }

    if (playerId == 'host') {
      return '$name (Host)';
    }

    return name;
  }

  List<String> _playerIds() {
    final ids = <String>{
      'host',
      ...widget.players.map(
        (player) => player.id,
      ),
      ...widget.totalScores.keys,
    };

    if (_gameHistory != null) {
      ids.addAll(
        _gameHistory!.players.keys,
      );
    }

    return ids.toList();
  }

  int _totalScore(String playerId) {
    if (_gameHistory != null &&
        _gameHistory!.rounds.isNotEmpty) {
      final latestRound =
          _gameHistory!.rounds.last;

      return latestRound.totalScores[playerId] ??
          widget.totalScores[playerId] ??
          0;
    }

    return widget.totalScores[playerId] ?? 0;
  }

  List<MapEntry<String, int>>
      _sortedScoreEntries() {
    final entries = _playerIds()
        .map(
          (playerId) => MapEntry(
            playerId,
            _totalScore(playerId),
          ),
        )
        .toList();

    entries.sort(
      (a, b) => b.value.compareTo(a.value),
    );

    return entries;
  }

  List<RoundHistory> _roundsToShow() {
    final rounds =
        _gameHistory?.rounds ?? [];

    if (_showCompleteGame) {
      return List<RoundHistory>.from(
        rounds.reversed,
      );
    }

    return rounds
        .reversed
        .take(5)
        .toList();
  }

  int _scoreForPlayer(
    RoundHistory round,
    String playerId,
  ) {
    for (final score in round.scores) {
      if (score.playerId == playerId) {
        return score.totalScore;
      }
    }

    return 0;
  }

  String _answerForPlayer(
    RoundHistory round,
    String playerId,
    String category,
  ) {
    final submission =
        round.submissions[playerId];

    if (submission == null) {
      return '';
    }

    return submission.answers[category] ?? '';
  }

  List<String> _categories(
    RoundHistory round,
  ) {
    final categories = <String>{};

    for (final submission
        in round.submissions.values) {
      categories.addAll(
        submission.answers.keys,
      );
    }

    return categories.toList();
  }

  Widget _buildLeaderboard() {
    final entries =
        _sortedScoreEntries();

    if (entries.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: Text(
              'No scores yet.',
              style: TextStyle(
                fontSize: 18,
              ),
            ),
          ),
        ),
      );
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
                'Leaderboard',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          ...entries.asMap().entries.map(
            (item) {
              final index = item.key;
              final entry = item.value;

              return ListTile(
                leading: CircleAvatar(
                  child: Text(
                    '${index + 1}',
                  ),
                ),
                title: Text(
                  _playerName(entry.key),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                trailing: Text(
                  '${entry.value}',
                  style: const TextStyle(
                    fontSize: 22,
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

  Widget _buildRound(
    RoundHistory round,
  ) {
    final playerIds =
        round.submissions.keys.toList();

    final categories =
        _categories(round);

    return Card(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded:
            _showCompleteGame &&
            round.round ==
                (_gameHistory?.rounds.last.round ??
                    -1),
        title: Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(8),
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer,
              ),
              child: Text(
                round.letter,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context)
                      .colorScheme
                      .onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Round ${round.round}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        subtitle: Text(
          '${playerIds.length} players',
        ),
        children: [
          if (categories.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No answers recorded.',
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(
                12,
                0,
                12,
                12,
              ),
              child: _buildRoundTable(
                round,
                playerIds,
                categories,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRoundTable(
    RoundHistory round,
    List<String> playerIds,
    List<String> categories,
  ) {
    return Column(
      children: [
        for (final playerId in playerIds)
          _buildPlayerRound(
            round,
            playerId,
            categories,
          ),
      ],
    );
  }

  Widget _buildPlayerRound(
    RoundHistory round,
    String playerId,
    List<String> categories,
  ) {
    final score =
        _scoreForPlayer(
      round,
      playerId,
    );

    return Container(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context)
              .dividerColor,
        ),
        borderRadius:
            BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _playerName(playerId),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                '$score pts',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context)
                      .colorScheme
                      .primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...categories.map(
            (category) {
              final answer =
                  _answerForPlayer(
                round,
                playerId,
                category,
              );

              return Padding(
                padding:
                    const EdgeInsets.symmetric(
                  vertical: 3,
                ),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(
                        category,
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                          fontWeight:
                              FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        answer.isEmpty
                            ? '—'
                            : answer,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    final rounds = _roundsToShow();

    if (rounds.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(
                Icons.history,
                size: 40,
              ),
              const SizedBox(height: 8),
              Text(
                widget.gameComplete
                    ? 'No round history found.'
                    : 'No completed rounds yet.',
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Round History',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (!_showCompleteGame &&
                (_gameHistory?.rounds.length ??
                        0) >
                    5)
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showCompleteGame = true;
                  });
                },
                icon: const Icon(
                  Icons.history,
                ),
                label: const Text(
                  'Load Complete Game',
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ...rounds.map(
          _buildRound,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Scoreboard',
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Scoreboard',
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildLeaderboard(),
            const SizedBox(height: 20),
            _buildHistorySection(),
          ],
        ),
      ),
    );
  }
}