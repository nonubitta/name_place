import 'dart:async';

import 'package:flutter/material.dart';
import 'package:name_place/models/player_score.dart';
import 'final_scoreboard_page.dart';
import '../models/player_answers.dart';
import 'results_page.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../network/host_server.dart';
import '../network/player_client.dart';
import 'scoreboard_page.dart';
import 'settings_page.dart';

class GameRoundPage extends StatefulWidget {
  final bool isHost;
  final List<Player> players;
  final GameState initialState;
  final HostServer? hostServer;
  final PlayerClient? playerClient;

  const GameRoundPage({
    super.key,
    required this.isHost,
    required this.players,
    required this.initialState,
    this.hostServer,
    this.playerClient,
  });

  @override
  State<GameRoundPage> createState() => _GameRoundPageState();
}

class _GameRoundPageState extends State<GameRoundPage> {
  late GameState _gameState;

  Timer? _timer;

  StreamSubscription<GameState>? _gameSubscription;

  StreamSubscription<void>? _submissionSubscription;

  StreamSubscription<PlayerAnswers>? _answersSubscription;

  StreamSubscription<Map<String, dynamic>>? _resultsSubscription;
  StreamSubscription<void>? _gameEndedSubscription;
  StreamSubscription<Map<String, dynamic>>? _playerActivitySubscription;
  final Map<String, TextEditingController> _controllers = {};

  final Set<String> _submittedPlayerIds = {};

  final Map<String, int> _totalScores = {};

  bool _submitted = false;

  @override
  void initState() {
    super.initState();

    _gameState = widget.initialState;

    // Get the current cumulative scores from
    // whichever networking side owns this game.
    if (widget.isHost && widget.hostServer != null) {
      _totalScores.addAll(widget.hostServer!.totalScores);
    } else if (!widget.isHost && widget.playerClient != null) {
      _totalScores.addAll(widget.playerClient!.totalScores);
    }

    _createControllers();

    if (!widget.isHost && widget.playerClient != null) {
      _submissionSubscription = widget.playerClient!.submissionReceivedStream
          .listen((_) {
            if (!mounted) {
              return;
            }

            setState(() {
              _submitted = true;
            });
          });
    }

    if (!widget.isHost && widget.playerClient != null) {
      _gameSubscription = widget.playerClient!.gameStateStream.listen(
        _onGameState,
      );
    }

    if (_gameState.phase == GamePhase.playing) {
      _startCountdown();
    }

    if (widget.isHost && widget.hostServer != null) {
      _answersSubscription = widget.hostServer!.answersStream.listen(
        _onPlayerSubmitted,
      );
    }

    if (widget.isHost && widget.hostServer != null) {
      _resultsSubscription = widget.hostServer!.resultsStream.listen(
        _onResults,
      );
    } else if (!widget.isHost && widget.playerClient != null) {
      _resultsSubscription = widget.playerClient!.resultsStream.listen(
        _onResults,
      );

      _gameEndedSubscription = widget.playerClient!.gameEndedStream.listen((_) {
        if (!mounted) {
          return;
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => FinalScoreboardPage(
              players: widget.players,
              totalScores: widget.playerClient!.totalScores,
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

  void _openScoreboard() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ScoreboardPage(players: widget.players, totalScores: _totalScores),
      ),
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
  }

  Future<void> _endGame() async {
    if (!widget.isHost) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('End Game?'),
          content: const Text(
            'This will end the game and disconnect '
            'all players.',
          ),
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
              child: const Text('END GAME'),
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
  }

  void _createControllers() {
    for (final category in _gameState.categories) {
      _controllers[category] = TextEditingController();
    }
  }

  void _onGameState(GameState state) {
    if (!mounted) {
      return;
    }

    // Ignore duplicate state updates for the
    // currently displayed round.
    if (state.round == _gameState.round && state.letter == _gameState.letter) {
      setState(() {
        _gameState = state;
      });

      if (state.phase == GamePhase.playing) {
        _startCountdown();
      }

      return;
    }

    _timer?.cancel();

    for (final controller in _controllers.values) {
      controller.dispose();
    }

    _controllers.clear();
    _submittedPlayerIds.clear();
    _submitted = false;

    setState(() {
      _gameState = state;
    });

    _createControllers();

    if (state.phase == GamePhase.playing) {
      _startCountdown();
    }
  }

  void _onPlayerSubmitted(PlayerAnswers submission) {
    if (!mounted) {
      return;
    }

    setState(() {
      _submittedPlayerIds.add(submission.playerId);
    });

    print(
      'Submission received: '
      '${submission.playerId} -> '
      '${submission.answers}',
    );
  }

  void _onResults(Map<String, dynamic> message) {
    if (!mounted) {
      return;
    }

    final rawTotals = message['totalScores'];

    if (rawTotals is Map) {
      _totalScores.clear();

      rawTotals.forEach((key, value) {
        _totalScores[key.toString()] = int.tryParse(value.toString()) ?? 0;
      });
    }

    final rawAnswers = message['answers'];

    final submissions = <String, PlayerAnswers>{};

    if (rawAnswers is Map) {
      rawAnswers.forEach((playerId, value) {
        if (value is Map) {
          submissions[playerId.toString()] = PlayerAnswers.fromJson(
            Map<String, dynamic>.from(value),
          );
        }
      });
    }

    final round =
        int.tryParse(message['round']?.toString() ?? '') ?? _gameState.round;

    final letter = message['letter']?.toString() ?? '';

    final rawScores = message['scores'];

    final scores = <PlayerScore>[];

    if (rawScores is List) {
      for (final value in rawScores) {
        if (value is Map) {
          scores.add(PlayerScore.fromJson(Map<String, dynamic>.from(value)));
        }
      }
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultsPage(
          round: round,
          letter: letter,
          players: widget.players,
          submissions: submissions,
          scores: scores,
          isHost: widget.isHost,
          hostServer: widget.hostServer,
          playerClient: widget.playerClient,
        ),
      ),
    );
  }

  void _startCountdown() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }

      if (_gameState.timeRemaining <= 1) {
        _timer?.cancel();

        setState(() {
          _gameState = _gameState.copyWith(timeRemaining: 0);
        });

        if (!_submitted) {
          _submitAnswers();
        }

        return;
      }

      setState(() {
        _gameState = _gameState.copyWith(
          timeRemaining: _gameState.timeRemaining - 1,
        );
      });
    });
  }

  void _submitAnswers() {
    if (_submitted) {
      return;
    }

    final answers = <String, String>{};

    for (final category in _gameState.categories) {
      answers[category] = _controllers[category]?.text.trim() ?? '';
    }

    _submitted = true;

    if (widget.isHost) {
      widget.hostServer?.submitHostAnswers(answers);
    } else {
      widget.playerClient?.submitAnswers(answers);
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _gameEndedSubscription?.cancel();
    _gameSubscription?.cancel();
    _answersSubscription?.cancel();
    _submissionSubscription?.cancel();
    _resultsSubscription?.cancel();
    _playerActivitySubscription?.cancel();

    for (final controller in _controllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _gameState.phase == GamePhase.playing;

    final isResults = _gameState.phase == GamePhase.results;

    return Scaffold(
      appBar: AppBar(
        title: Text('Round ${_gameState.round}'),
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
          if (widget.isHost)
            IconButton(
              tooltip: 'End Game',
              icon: const Icon(Icons.stop_circle_outlined),
              onPressed: _endGame,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),

            if (isPlaying) Expanded(child: _buildAnswerSheet()),

            if (isResults) Expanded(child: _buildResultsPlaceholder()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Round ${_gameState.round}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                widget.isHost ? 'HOST' : 'PLAYER',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Letter', style: TextStyle(fontSize: 15)),
              const SizedBox(width: 10),
              Text(
                _gameState.letter,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (_gameState.phase == GamePhase.playing)
                Text(
                  '${_gameState.timeRemaining}s',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _gameState.timeRemaining <= 5 ? Colors.red : null,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerSheet() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final category in _gameState.categories)
            _buildCategoryField(category),

          const SizedBox(height: 12),

          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _submitted ? null : _submitAnswers,
              child: Text(
                _submitted ? 'SUBMITTED' : 'SUBMIT',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),

          _buildSubmissionStatus(),

          if (_submitted)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Your answers have been submitted.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryField(String category) {
    final controller = _controllers[category];

    if (controller == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        enabled: !_submitted,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: category,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildResultsPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.timer_off, size: 72),
          const SizedBox(height: 20),
          const Text(
            'Time!',
            style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            _submitted ? 'Answers submitted' : 'Round finished',
            style: const TextStyle(fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmissionStatus() {
    if (!widget.isHost) {
      return const SizedBox.shrink();
    }

    final totalPlayers = widget.players.length;
    final submittedCount = _submittedPlayerIds.length;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Submissions',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          Text('$submittedCount / $totalPlayers submitted'),

          const SizedBox(height: 12),

          for (final player in widget.players)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    _submittedPlayerIds.contains(player.id)
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 20,
                  ),
                  const SizedBox(width: 8),

                  Text(
                    player.id == 'host' ? '${player.name} (Host)' : player.name,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
