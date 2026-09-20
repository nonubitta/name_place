import 'dart:async';

import 'package:flutter/material.dart';

import '../models/game_state.dart';
import '../models/player.dart';
import '../network/host_server.dart';
import 'game_round_page.dart';

class HostPage extends StatefulWidget {
  const HostPage({super.key});

  @override
  State<HostPage> createState() => _HostPageState();
}

class _HostPageState extends State<HostPage> {
  final HostServer _server = HostServer();

  final TextEditingController _nameController = TextEditingController(
    text: 'Host',
  );

  StreamSubscription<List<Player>>? _playersSubscription;

  StreamSubscription<void>? _gameSubscription;

  List<Player> _players = [];

  bool _starting = true;

  bool _gameStarted = false;

  @override
  void initState() {
    super.initState();

    _startHost();
  }

  Future<void> _startHost() async {
    await _server.start(hostName: _nameController.text.trim());

    _playersSubscription = _server.playersStream.listen((players) {
      if (!mounted) return;

      setState(() {
        _players = players;
      });
    });

    if (!mounted) return;

    setState(() {
      _starting = false;
    });
  }

  void _startGame() {
    if (_players.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Waiting for at least one player.')),
      );

      return;
    }

    final state = _server.startGame();

    if (state == null) {
      return;
    }

    _gameStarted = true;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GameRoundPage(
          isHost: true,
          players: List<Player>.from(_players),
          initialState: state,
          hostServer: _server,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _playersSubscription?.cancel();
    _gameSubscription?.cancel();

    _nameController.dispose();

    // IMPORTANT:
    // Keep the server alive after moving to GameRoundPage.
    if (!_gameStarted) {
      _server.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Game Lobby')),
      body: _starting
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildRoomCard(),

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
                          ? _buildWaiting()
                          : _buildPlayers(),
                    ),

                    const SizedBox(height: 12),

                    FilledButton.icon(
                      onPressed: _startGame,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('START GAME'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildRoomCard() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'ROOM CODE',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              _server.roomCode,
              style: const TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w800,
                letterSpacing: 8,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Players can find this game automatically.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaiting() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 60),
          SizedBox(height: 16),
          Text('Waiting for players...', style: TextStyle(fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildPlayers() {
    return ListView.builder(
      itemCount: _players.length,
      itemBuilder: (context, index) {
        final player = _players[index];

        return Card(
          child: ListTile(
            leading: CircleAvatar(
              child: Text(
                player.name.isEmpty ? '?' : player.name[0].toUpperCase(),
              ),
            ),
            title: Text(
              player.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            trailing: const Icon(Icons.check_circle),
          ),
        );
      },
    );
  }
}
