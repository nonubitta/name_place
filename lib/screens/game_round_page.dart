import 'dart:async';

import 'package:flutter/material.dart';

import '../models/game_state.dart';
import '../models/player.dart';
import '../network/host_server.dart';
import '../network/player_client.dart';

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

  @override
  void initState() {
    super.initState();

    _gameState = widget.initialState;

    // Players receive game state from the host.
    if (!widget.isHost && widget.playerClient != null) {
      _gameSubscription =
          widget.playerClient!.gameStateStream.listen(_onGameState);
    }

    // Both host AND players run the visible countdown locally.
    if (_gameState.phase == GamePhase.playing) {
      _startCountdown();
    }
  }

  void _onGameState(GameState state) {
    if (!mounted) return;

    setState(() {
      _gameState = state;
    });

    if (state.phase == GamePhase.playing) {
      _startCountdown();
    }
  }

  void _startCountdown() {
    _timer?.cancel();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted) return;

        if (_gameState.timeRemaining <= 1) {
          _timer?.cancel();

          setState(() {
            _gameState = _gameState.copyWith(
              timeRemaining: 0,
              phase: GamePhase.results,
            );
          });

          return;
        }

        setState(() {
          _gameState = _gameState.copyWith(
            timeRemaining: _gameState.timeRemaining - 1,
          );
        });
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _gameSubscription?.cancel();

    // Once the game screen is closed, the host no longer needs
    // the local server for this first version.
    if (widget.isHost) {
      widget.hostServer?.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isPlaying = _gameState.phase == GamePhase.playing;
    final bool isResults = _gameState.phase == GamePhase.results;

    return Scaffold(
      appBar: AppBar(
        title: Text('Round ${_gameState.round}'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 20,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Round ${_gameState.round}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.isHost ? 'HOST' : 'PLAYER',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            if (isPlaying) ...[
              const Text(
                'YOUR LETTER',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
              ),

              const SizedBox(height: 40),

              Text(
                _gameState.letter,
                style: const TextStyle(
                  fontSize: 136,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 60),

              Text(
                '${_gameState.timeRemaining}',
                style: const TextStyle(
                  fontSize: 76,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const Text(
                'seconds',
                style: TextStyle(
                  fontSize: 18,
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Get ready!',
                style: TextStyle(
                  fontSize: 22,
                ),
              ),
            ],

            if (isResults) ...[
              const Icon(
                Icons.timer_off,
                size: 80,
              ),

              const SizedBox(height: 20),

              const Text(
                'Time!',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],

            const Spacer(),

            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Text(
                '${widget.players.length} players',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}