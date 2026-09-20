import 'dart:async';
import 'dart:math';
import '../models/player.dart';
import 'package:flutter/material.dart';

import '../models/game_room.dart';
import '../network/discovery_service.dart';
import '../network/player_client.dart';
import 'game_page.dart';

class JoinPage extends StatefulWidget {
  const JoinPage({super.key});

  @override
  State<JoinPage> createState() => _JoinPageState();
}

class _JoinPageState extends State<JoinPage> {
  final TextEditingController _nameController =
      TextEditingController();

  final DiscoveryService _discovery =
      DiscoveryService();

  final PlayerClient _client = PlayerClient();

  StreamSubscription<GameRoom>? _roomSubscription;
  StreamSubscription<String>? _statusSubscription;
StreamSubscription<List<Player>>?
    _playersSubscription;
  StreamSubscription<void>? _gameSubscription;

  final Map<String, GameRoom> _rooms = {};

  String _status = 'Searching for games...';

  bool _connecting = false;

  List<Player> _players = [];

  @override
  void initState() {
    super.initState();

    _startDiscovery();
    _listenToClient();
  }

  Future<void> _startDiscovery() async {
    try {
      await _discovery.startDiscovery();

      _roomSubscription =
          _discovery.roomsStream.listen((room) {
        if (!mounted) return;

        setState(() {
          _rooms[room.roomCode] = room;
          _status = 'Games found';
        });
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _status = 'Unable to search for games';
      });
    }
  }

  void _listenToClient() {
    _statusSubscription =
        _client.statusStream.listen((status) {
      if (!mounted) return;

      setState(() {
        _status = status;
      });
    });

_playersSubscription =
    _client.playersStream.listen((players) {
  if (!mounted) return;

  setState(() {
    _players = players;
  });
});

    _gameSubscription =
        _client.gameStartedStream.listen((_) {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => GamePage(
            isHost: false,
            players: _players,
          ),
        ),
      );
    });
  }

  String _generatePlayerId() {
    final random = Random.secure();

    return List.generate(
      16,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
  }

  Future<void> _joinRoom(GameRoom room) async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      _showError('Please enter your name first.');
      return;
    }

    if (_connecting) {
      return;
    }

    setState(() {
      _connecting = true;
      _status = 'Connecting to ${room.hostName}...';
    });

    try {
      await _discovery.stop();

      await _client.connect(
        host: room.hostAddress,
        playerId: _generatePlayerId(),
        playerName: name,
      );

      if (!mounted) return;

      setState(() {
        _connecting = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _connecting = false;
        _status = 'Could not connect';
      });

      _showError(
        'Could not connect to the game.\n'
        'Make sure you are on the same Wi-Fi network.',
      );

      await _startDiscovery();
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    _statusSubscription?.cancel();
    _playersSubscription?.cancel();
    _gameSubscription?.cancel();

    _discovery.dispose();
    _client.dispose();

    _nameController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rooms = _rooms.values.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Game'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                enabled: !_connecting,
                textCapitalization:
                    TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Your name',
                  prefixIcon: Icon(
                    Icons.person,
                  ),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  const Icon(
                    Icons.wifi,
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Text(
                      _status,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  if (_status == 'Searching for games...')
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 20),

              if (rooms.isEmpty)
                Expanded(
                  child: _buildNoGames(),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: rooms.length,
                    itemBuilder: (context, index) {
                      return _buildRoomCard(
                        rooms[index],
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoGames() {
    return const Center(
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 64,
          ),
          SizedBox(height: 16),
          Text(
            'No games found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 30,
            ),
            child: Text(
              'Ask the host to create a game and make sure you are both connected to the same Wi-Fi network.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCard(GameRoom room) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _connecting
            ? null
            : () => _joinRoom(room),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 26,
                child: Icon(
                  Icons.groups,
                ),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.hostName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      'Room ${room.roomCode}',
                    ),

                    const SizedBox(height: 4),

                    Text(
                      '${room.playerCount} '
                      '${room.playerCount == 1 ? 'player' : 'players'}',
                    ),
                  ],
                ),
              ),

              FilledButton(
                onPressed: _connecting
                    ? null
                    : () => _joinRoom(room),
                child: const Text('JOIN'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}