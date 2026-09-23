import 'dart:async';

import 'package:flutter/material.dart';

import '../models/game_state.dart';
import '../models/player.dart';
import '../network/player_client.dart';
import 'game_round_page.dart';
import 'home_page.dart';

class JoinLobbyPage extends StatefulWidget {
  final PlayerClient client;
  final String roomCode;
  final String playerName;

  const JoinLobbyPage({
    super.key,
    required this.client,
    required this.roomCode,
    required this.playerName,
  });

  @override
  State<JoinLobbyPage> createState() => _JoinLobbyPageState();
}

class _JoinLobbyPageState extends State<JoinLobbyPage> {
  StreamSubscription<List<Player>>? _playersSubscription;

  StreamSubscription<String>? _statusSubscription;

  StreamSubscription<GameState>? _gameStateSubscription;

  StreamSubscription<void>? _roomCancelledSubscription;

  List<Player> _players = [];

  String _status = 'Connected';

  bool _gameStarted = false;

  bool _leaving = false;

  @override
  void initState() {
    super.initState();

    _players = widget.client.latestPlayers;

    _playersSubscription = widget.client.playersStream.listen((players) {
      if (!mounted) return;

      setState(() {
        _players = players;
      });
    });

    _statusSubscription = widget.client.statusStream.listen((status) {
      if (!mounted) return;

      setState(() {
        _status = status;
      });
    });

    _gameStateSubscription = widget.client.gameStateStream.listen(_onGameState);

    _roomCancelledSubscription = widget.client.roomCancelledStream.listen(
      _onRoomCancelled,
    );
  }

  Future<void> _onRoomCancelled(_) async {
    if (!mounted || _leaving) {
      return;
    }

    _leaving = true;
    await widget.client.disconnect();

    if (!mounted) {
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }

  void _onGameState(GameState state) {
    if (!mounted || _gameStarted) {
      return;
    }

    if (state.phase == GamePhase.playing) {
      _gameStarted = true;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => GameRoundPage(
            isHost: false,
            players: _players,
            initialState: state,
            playerClient: widget.client,
          ),
        ),
      );
    }
  }

  Future<void> _leaveLobby() async {
    if (_leaving || _gameStarted) {
      return;
    }

    _leaving = true;
    await widget.client.disconnect();

    if (!mounted) {
      return;
    }

    Navigator.pop(context);
  }

  @override
  void dispose() {
    _playersSubscription?.cancel();
    _statusSubscription?.cancel();
    _gameStateSubscription?.cancel();
    _roomCancelledSubscription?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connected = _status == 'Connected' || _status == 'Joined game';

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (_, _) {
        _leaveLobby();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Leave lobby',
            icon: const Icon(Icons.arrow_back),
            onPressed: _leaving ? null : _leaveLobby,
          ),
          title: const Text('Game Lobby'),
        ),
        body: SafeArea(
          child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildConnectionCard(connected),

              const SizedBox(height: 24),

              Text(
                'Players (${_players.length})',
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              Expanded(
                child: _players.isEmpty
                    ? const Center(
                        child: Text(
                          'Waiting for players...',
                          style: TextStyle(fontSize: 18),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _players.length,
                        itemBuilder: (context, index) {
                          final player = _players[index];

                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text(
                                  player.name.isEmpty
                                      ? '?'
                                      : player.name[0].toUpperCase(),
                                ),
                              ),
                              title: Text(
                                player.id == 'host'
                                    ? '${player.name} (Host)'
                                    : player.name,
                              ),
                            ),
                          );
                        },
                      ),
              ),

              const SizedBox(height: 12),

              const Text(
                'Waiting for the host to start the game...',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionCard(bool connected) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(
              connected ? Icons.check_circle : Icons.error_outline,
              size: 42,
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    connected ? 'Connected!' : _status,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text('Room ${widget.roomCode}'),

                  const SizedBox(height: 2),

                  Text('Playing as ${widget.playerName}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
