import 'dart:async';

import 'package:flutter/material.dart';

import '../models/game_state.dart';
import '../models/player.dart';
import '../models/player_answers.dart';
import '../models/player_score.dart';
import '../network/host_server.dart';
import '../network/player_client.dart';
import 'game_round_page.dart';
import 'scoreboard_page.dart';
import 'settings_page.dart';

class ResultsPage extends StatefulWidget {
  final int round;
  final String letter;
  final List<Player> players;
  final Map<String, PlayerAnswers> submissions;
  final List<PlayerScore> scores;

  final bool isHost;
  final HostServer? hostServer;
  final PlayerClient? playerClient;

  const ResultsPage({
    super.key,
    required this.round,
    required this.letter,
    required this.players,
    required this.submissions,
    required this.scores,
    required this.isHost,
    this.hostServer,
    this.playerClient,
  });

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  late List<PlayerScore> _scores;

  StreamSubscription<Map<String, dynamic>>? _resultsSubscription;
  StreamSubscription<GameState>? _gameStateSubscription;
  StreamSubscription<void>? _gameEndedSubscription;

  @override
  void initState() {
    super.initState();

    _scores = List<PlayerScore>.from(widget.scores);

    if (widget.isHost && widget.hostServer != null) {
      _resultsSubscription = widget.hostServer!.resultsStream.listen(
        _handleUpdatedResults,
      );
    } else if (!widget.isHost && widget.playerClient != null) {
      _resultsSubscription = widget.playerClient!.resultsStream.listen(
        _handleUpdatedResults,
      );

      _gameStateSubscription = widget.playerClient!.gameStateStream.listen(
        _handleGameState,
      );
    }

    if (!widget.isHost && widget.playerClient != null) {
      _gameEndedSubscription = widget.playerClient!.gameEndedStream.listen((_) {
        if (!mounted) {
          return;
        }

        Navigator.of(context).popUntil((route) => route.isFirst);
      });
    }
  }

  void _handleGameState(GameState state) {
    if (!mounted) {
      return;
    }

    if (state.phase != GamePhase.playing) {
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GameRoundPage(
          isHost: false,
          players: widget.players,
          initialState: state,
          playerClient: widget.playerClient,
        ),
      ),
    );
  }

  void _nextRound() {
    if (!widget.isHost || widget.hostServer == null) {
      return;
    }

    final nextState = widget.hostServer!.startNextRound();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GameRoundPage(
          isHost: true,
          players: widget.players,
          initialState: nextState,
          hostServer: widget.hostServer,
        ),
      ),
    );
  }

  void _handleUpdatedResults(Map<String, dynamic> message) {
    if (!mounted) {
      return;
    }

    final rawScores = message['scores'];

    if (rawScores is! List) {
      return;
    }

    final updatedScores = <PlayerScore>[];

    for (final value in rawScores) {
      if (value is Map) {
        updatedScores.add(
          PlayerScore.fromJson(Map<String, dynamic>.from(value)),
        );
      }
    }

    setState(() {
      _scores = updatedScores;
    });
  }

  PlayerScore? _scoreFor(String playerId) {
    for (final score in _scores) {
      if (score.playerId == playerId) {
        return score;
      }
    }

    return null;
  }

  String _playerName(String playerId) {
    for (final player in widget.players) {
      if (player.id == playerId) {
        if (player.id == 'host') {
          return '${player.name} (Host)';
        }

        return player.name;
      }
    }

    // Important:
    // Never use this phone's SharedPreferences here.
    // The client's saved name is NOT the host's name.
    if (playerId == 'host') {
      return 'Host';
    }

    return 'Player';
  }

  Future<void> _exitGame() async {
    if (widget.isHost) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Exit Game?'),
            content: const Text('This will end the game for everyone.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context, false);
                },
                child: const Text('CANCEL'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context, true);
                },
                child: const Text('EXIT GAME'),
              ),
            ],
          );
        },
      );

      if (confirmed != true) {
        return;
      }

      await widget.hostServer?.endGame();

      if (!mounted) {
        return;
      }

      Navigator.of(context).popUntil((route) => route.isFirst);

      return;
    }

    // Non-host player simply leaves locally.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.submissions.entries.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Round ${widget.round} Results'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Scoreboard',
            icon: const Icon(Icons.leaderboard_outlined),
            onPressed: _openScoreboard,
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
          ),
          IconButton(
            tooltip: 'Exit Game',
            icon: const Icon(Icons.exit_to_app),
            onPressed: _exitGame,
          ),
        ],
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

  void _openScoreboard() {
    final totalScores = <String, int>{};

    if (widget.isHost && widget.hostServer != null) {
      totalScores.addAll(widget.hostServer!.totalScores);
    } else if (!widget.isHost && widget.playerClient != null) {
      totalScores.addAll(widget.playerClient!.totalScores);
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ScoreboardPage(players: widget.players, totalScores: totalScores),
      ),
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
  }

  Widget _buildRoundHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        children: [
          Text(
            'ROUND ${widget.round}',
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
                widget.letter,
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
                    playerName.isNotEmpty ? playerName[0].toUpperCase() : '?',
                    style: const TextStyle(fontWeight: FontWeight.bold),
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
                context,
                playerId,
                answer.key,
                answer.value,
                playerScore?.categoryScores[answer.key] ?? 0,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerRow(
    BuildContext context,
    String playerId,
    String category,
    String answer,
    int points,
  ) {
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
          _buildScoreButton(context, playerId, category, points),
        ],
      ),
    );
  }

  Widget _buildScoreButton(
    BuildContext context,
    String playerId,
    String category,
    int points,
  ) {
    if (!widget.isHost) {
      return Text(
        '+$points',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: points == 0 ? Colors.grey : null,
        ),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _editScore(context, playerId, category, points),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '+$points',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: points == 0 ? Colors.grey : null,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.edit, size: 15),
          ],
        ),
      ),
    );
  }

  Future<void> _editScore(
    BuildContext context,
    String playerId,
    String category,
    int currentScore,
  ) async {
    final score = await showModalBottomSheet<int>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Score: $category',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _scoreOption(
                        context,
                        playerId,
                        category,
                        0,
                        currentScore,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _scoreOption(
                        context,
                        playerId,
                        category,
                        5,
                        currentScore,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _scoreOption(
                        context,
                        playerId,
                        category,
                        10,
                        currentScore,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (score == null) {
      return;
    }

    widget.hostServer?.updateScore(
      playerId: playerId,
      category: category,
      score: score,
    );
  }

  Widget _scoreOption(
    BuildContext context,
    String playerId,
    String category,
    int score,
    int currentScore,
  ) {
    final selected = score == currentScore;

    return FilledButton(
      onPressed: () {
        Navigator.pop(context, score);
      },
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        backgroundColor: selected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        foregroundColor: selected
            ? Theme.of(context).colorScheme.onPrimary
            : Theme.of(context).colorScheme.onSurface,
      ),
      child: Text(
        '$score',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    if (!widget.isHost) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: _nextRound,
            child: const Text(
              'NEXT ROUND',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _resultsSubscription?.cancel();
    _gameStateSubscription?.cancel();
    _gameEndedSubscription?.cancel();
    super.dispose();
  }
}
