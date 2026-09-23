import 'dart:async';

import 'package:flutter/material.dart';
import 'final_scoreboard_page.dart';
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
  StreamSubscription<Map<String, dynamic>>? _playerActivitySubscription;

  bool _groupByCategory = true;

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

        final totalScores = <String, int>{};

        totalScores.addAll(widget.playerClient!.totalScores);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => FinalScoreboardPage(
              players: widget.players,
              totalScores: totalScores,
            ),
          ),
        );
      });
    }

    if (widget.isHost && widget.hostServer != null) {
      _playerActivitySubscription =
          widget.hostServer!.playerActivityStream.listen(_onPlayerActivity);
    } else if (!widget.isHost && widget.playerClient != null) {
      _playerActivitySubscription =
          widget.playerClient!.playerActivityStream.listen(_onPlayerActivity);
    }
  }

  void _onPlayerActivity(Map<String, dynamic> message) {
    if (!mounted) {
      return;
    }

    final playerName = message['playerName']?.toString() ?? 'Player';
    final type = message['type']?.toString();
    final minimized = type == 'player_minimized';

    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            minimized
                ? '⚠️ $playerName left the game app'
                : '✓ $playerName returned to the game',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
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

  int _grandTotalFor(String playerId) {
    if (widget.isHost) {
      return widget.hostServer?.totalScores[playerId] ?? 0;
    }

    return widget.playerClient?.totalScores[playerId] ?? 0;
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

      final totalScores = <String, int>{};

      totalScores.addAll(widget.hostServer?.totalScores ?? {});

      await widget.hostServer?.endGame();

      if (!mounted) {
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => FinalScoreboardPage(
            players: widget.players,
            totalScores: totalScores,
          ),
        ),
      );

      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Exit Game?'),
          content: const Text('You will leave the game and return home.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('EXIT GAME'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await widget.playerClient?.disconnect();

    if (!mounted) {
      return;
    }

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
            tooltip: _groupByCategory ? 'Group by player' : 'Group by category',
            icon: Icon(
              _groupByCategory ? Icons.person_outline : Icons.category_outlined,
            ),
            onPressed: () {
              setState(() {
                _groupByCategory = !_groupByCategory;
              });
            },
          ),
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
                  ? ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'No submissions.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                        _buildRoundTotalsCard(),
                      ],
                    )
                  : _groupByCategory
                  ? _buildCategoryView()
                  : _buildPlayerView(entries),
            ),

            _buildBottomBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerView(List<MapEntry<String, PlayerAnswers>> entries) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: entries.length + 1,
      itemBuilder: (context, index) {
        if (index == entries.length) {
          return _buildRoundTotalsCard();
        }

        final entry = entries[index];

        return _buildPlayerCard(context, entry.key, entry.value);
      },
    );
  }

  Widget _buildCategoryView() {
    final categories = <String>[];

    for (final submission in widget.submissions.values) {
      for (final category in submission.answers.keys) {
        if (!categories.contains(category)) {
          categories.add(category);
        }
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: categories.length + 1,
      itemBuilder: (context, index) {
        if (index == categories.length) {
          return _buildRoundTotalsCard();
        }

        final category = categories[index];

        return _buildCategoryCard(category);
      },
    );
  }

  Widget _buildCategoryCard(String category) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              category,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),

            const Divider(height: 24),

            for (final entry in widget.submissions.entries)
              _buildCategoryAnswerRow(
                entry.key,
                category,
                entry.value.answers[category] ?? '',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoundTotalsCard() {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: colorScheme.primaryContainer,
      elevation: 2,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colorScheme.primary, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.emoji_events_outlined, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Totals',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            Divider(height: 24, color: colorScheme.primary.withValues(alpha: 0.4)),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  _buildTotalsCell('Name', flex: 2, header: true),
                  _buildTotalsCell('Round Total', flex: 1, header: true),
                  _buildTotalsCell('Grand Total', flex: 1, header: true),
                ],
              ),
            ),
            for (final player in widget.players)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(
                  children: [
                    _buildTotalsCell(_playerName(player.id), flex: 2),
                    _buildTotalsCell(
                      '${_scoreFor(player.id)?.totalScore ?? 0}',
                      flex: 1,
                    ),
                    _buildTotalsCell('${_grandTotalFor(player.id)}', flex: 1),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalsCell(String text, {required int flex, bool header = false}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(
          text,
          maxLines: header ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          textAlign: flex == 2 ? TextAlign.left : TextAlign.right,
          style: TextStyle(
            fontSize: header ? 12 : 16,
            fontWeight: header ? FontWeight.bold : FontWeight.w600,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryAnswerRow(
    String playerId,
    String category,
    String answer,
  ) {
    final playerName = _playerName(playerId);

    final playerScore = _scoreFor(playerId);

    final points = playerScore?.categoryScores[category] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              '$playerName: '
              '${answer.isEmpty ? '—' : answer}',
              style: const TextStyle(fontSize: 16),
            ),
          ),

          _buildScoreButton(context, playerId, category, points),
        ],
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
    _playerActivitySubscription?.cancel();

    super.dispose();
  }
}
