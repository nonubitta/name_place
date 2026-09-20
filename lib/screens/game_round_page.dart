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
  State<GameRoundPage> createState() =>
      _GameRoundPageState();
}

class _GameRoundPageState
    extends State<GameRoundPage> {
  StreamSubscription<GameState>?
      _gameStateSubscription;

  GameState _gameState =
      const GameState.lobby();

  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _gameState = widget.initialState;

    if (!widget.isHost &&
        widget.playerClient != null) {
      _gameStateSubscription =
          widget.playerClient!.gameStateStream.listen(
        _onGameStateReceived,
      );
    }

    if (widget.isHost) {
      _startLocalCountdown(_gameState);
    }
  }

  void _onGameStateReceived(
    GameState state,
  ) {
    if (!mounted) return;

    setState(() {
      _gameState = state;
    });

    _startLocalCountdown(state);
  }

  void _startLocalCountdown(
    GameState state,
  ) {
    _timer?.cancel();

    if (state.phase != GamePhase.playing) {
      return;
    }

    if (state.timeRemaining <= 0) {
      return;
    }

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (_gameState.timeRemaining <= 1) {
          timer.cancel();

          setState(() {
            _gameState =
                _gameState.copyWith(
              timeRemaining: 0,
              phase: GamePhase.results,
            );
          });

          return;
        }

        setState(() {
          _gameState =
              _gameState.copyWith(
            timeRemaining:
                _gameState.timeRemaining - 1,
          );
        });
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _gameStateSubscription?.cancel();

    if (widget.isHost) {
      widget.hostServer?.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playing =
        _gameState.phase == GamePhase.playing;

    final results =
        _gameState.phase == GamePhase.results;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Round ${_gameState.round}',
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _buildTopInfo(),

              const Spacer(),

              if (playing)
                _buildPlaying()
              else if (results)
                _buildResults()
              else
                _buildWaiting(),

              const Spacer(),

              _buildPlayerCount(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopInfo() {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Round ${_gameState.round}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          widget.isHost
              ? 'HOST'
              : 'PLAYER',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildPlaying() {
    return Column(
      children: [
        const Text(
          'YOUR LETTER',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 3,
          ),
        ),

        const SizedBox(height: 10),

        Text(
          _gameState.letter,
          style: const TextStyle(
            fontSize: 110,
            fontWeight: FontWeight.w900,
          ),
        ),

        const SizedBox(height: 20),

        Text(
          '${_gameState.timeRemaining}',
          style: const TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.bold,
          ),
        ),

        const Text(
          'seconds',
          style: TextStyle(
            fontSize: 16,
          ),
        ),

        const SizedBox(height: 30),

        const Text(
          'Get ready!',
          style: TextStyle(
            fontSize: 20,
          ),
        ),
      ],
    );
  }

  Widget _buildResults() {
    return const Column(
      children: [
        Icon(
          Icons.timer_off,
          size: 70,
        ),
        SizedBox(height: 20),
        Text(
          'Time!',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildWaiting() {
    return const Column(
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 20),
        Text(
          'Waiting for round...',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerCount() {
    return Text(
      '${widget.players.length} players',
      style: const TextStyle(
        color: Colors.grey,
      ),
    );
  }
}