import 'dart:async';
import 'dart:math';
import 'settings_page.dart';
import 'package:flutter/material.dart';
import '../services/app_preferences.dart';
import '../models/game_room.dart';
import '../network/discovery_service.dart';
import '../network/player_client.dart';
import 'join_lobby_page.dart';

class JoinPage extends StatefulWidget {
  const JoinPage({super.key});

  @override
  State<JoinPage> createState() => _JoinPageState();
}

class _JoinPageState extends State<JoinPage> {
  final TextEditingController _nameController = TextEditingController();

  final DiscoveryService _discovery = DiscoveryService();

  final PlayerClient _client = PlayerClient();

  StreamSubscription<GameRoom>? _roomSubscription;
  StreamSubscription<String>? _closedRoomSubscription;

  final Map<String, GameRoom> _rooms = {};

  String _status = 'Searching for games...';

  bool _connecting = false;

  bool _joinedSuccessfully = false;

  @override
  void initState() {
    super.initState();
    _loadSavedName();
    _startDiscovery();
  }

  Future<void> _loadSavedName() async {
    final savedName = await AppPreferences.getPlayerName();

    if (!mounted) {
      return;
    }

    if (savedName.isNotEmpty) {
      _nameController.text = savedName;
    }
  }

  Future<void> _startDiscovery() async {
    try {
      await _discovery.startDiscovery();

      _roomSubscription = _discovery.roomsStream.listen((room) {
        if (!mounted) return;

        setState(() {
          _rooms.removeWhere(
            (_, existingRoom) =>
                existingRoom.hostAddress == room.hostAddress,
          );
          _rooms[room.roomCode] = room;

          if (!_connecting) {
            _status = 'Games found';
          }
        });
      });

      _closedRoomSubscription = _discovery.closedRoomsStream.listen((roomCode) {
        if (!mounted) return;

        setState(() {
          _rooms.remove(roomCode);
          if (_rooms.isEmpty && !_connecting) {
            _status = 'Searching for games...';
          }
        });
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _status = 'Unable to search for games';
      });
    }
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

    await AppPreferences.setPlayerName(name);

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
        _status = 'Connected!';
      });

      // The JoinPage is about to be disposed.
      // Keep the WebSocket alive because the lobby
      // will now own the client connection.
      _joinedSuccessfully = true;

      // Only gets here after the HOST has confirmed
      // that this player joined successfully.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => JoinLobbyPage(
            client: _client,
            roomCode: room.roomCode,
            playerName: name,
          ),
        ),
      );
    } catch (e) {
      print('JOIN ERROR: $e');

      if (!mounted) return;

      setState(() {
        _connecting = false;
        _status = 'Connection failed';
      });

      _showError(
        'Could not connect to ${room.hostName}.\n\n'
        '$e',
      );

      await _startDiscovery();
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
    );
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    _closedRoomSubscription?.cancel();

    _discovery.dispose();

    // If we successfully joined, JoinLobbyPage now owns
    // the PlayerClient connection.
    if (!_joinedSuccessfully) {
      _client.dispose();
    }

    _nameController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rooms = _rooms.values.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Game'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: _connecting
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsPage()),
                    );
                  },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                enabled: !_connecting,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Your name',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 24),

              _buildStatus(),

              const SizedBox(height: 20),

              if (rooms.isEmpty)
                Expanded(child: _buildNoGames())
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: rooms.length,
                    itemBuilder: (context, index) {
                      return _buildRoomCard(rooms[index]);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatus() {
    final isConnecting = _connecting;

    return Row(
      children: [
        if (isConnecting)
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          )
        else
          Icon(Icons.wifi, color: _status == 'Games found' ? null : null),

        const SizedBox(width: 12),

        Expanded(
          child: Text(
            _status,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildNoGames() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 64),
          SizedBox(height: 16),
          Text(
            'No games found',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 30),
            child: Text(
              'Ask the host to create a game and make sure both phones are connected to the same Wi-Fi network.',
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
        onTap: _connecting ? null : () => _joinRoom(room),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const CircleAvatar(radius: 26, child: Icon(Icons.groups)),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.hostName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text('Room ${room.roomCode}'),

                    const SizedBox(height: 4),

                    Text(
                      '${room.playerCount} '
                      '${room.playerCount == 1 ? 'player' : 'players'}',
                    ),
                  ],
                ),
              ),

              FilledButton(
                onPressed: _connecting ? null : () => _joinRoom(room),
                child: Text(_connecting ? 'CONNECTING' : 'JOIN'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
