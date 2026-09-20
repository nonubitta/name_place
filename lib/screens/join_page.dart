import 'dart:math';

import 'package:flutter/material.dart';

import '../network/player_client.dart';

class JoinPage extends StatefulWidget {
  const JoinPage({super.key});

  @override
  State<JoinPage> createState() => _JoinPageState();
}

class _JoinPageState extends State<JoinPage> {
  final _nameController = TextEditingController();
  final _hostController = TextEditingController();

  final PlayerClient _client = PlayerClient();

  String _status = 'Not connected';
  List<Map<String, dynamic>> _players = [];

  @override
  void initState() {
    super.initState();

    _client.statusStream.listen((status) {
      if (!mounted) return;

      setState(() {
        _status = status;
      });
    });

    _client.playersStream.listen((players) {
      if (!mounted) return;

      setState(() {
        _players = players;
      });
    });
  }

  String _generatePlayerId() {
    final random = Random.secure();

    return List.generate(
      8,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
  }

  Future<void> _connect() async {
    final name = _nameController.text.trim();
    var host = _hostController.text.trim();

    if (name.isEmpty) {
      _showError('Enter your name');
      return;
    }

    if (host.isEmpty) {
      _showError('Enter the host IP address');
      return;
    }

    host = host
        .replaceFirst('ws://', '')
        .replaceFirst('http://', '')
        .replaceAll('/ws', '')
        .replaceAll(':4040', '');

    try {
      await _client.connect(
        host: host,
        playerId: _generatePlayerId(),
        playerName: name,
      );
    } catch (e) {
      if (!mounted) return;

      _showError(
        'Could not connect.\n'
        'Make sure both phones are on the same Wi-Fi.',
      );
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
    _client.dispose();
    _nameController.dispose();
    _hostController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connected = _status == 'Connected' || _status == 'Joined game';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Game'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Your name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _hostController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Host IP address',
                hintText: '192.168.1.20',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.wifi),
              ),
            ),

            const SizedBox(height: 16),

            FilledButton.icon(
              onPressed: connected ? null : _connect,
              icon: const Icon(Icons.link),
              label: Text(
                connected ? 'Connected' : 'Connect',
              ),
            ),

            const SizedBox(height: 20),

            Card(
              child: ListTile(
                leading: Icon(
                  connected
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                ),
                title: const Text('Status'),
                subtitle: Text(_status),
              ),
            ),

            const SizedBox(height: 20),

            Text(
              'Players: ${_players.length}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Expanded(
              child: ListView.builder(
                itemCount: _players.length,
                itemBuilder: (context, index) {
                  final player = _players[index];

                  return ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person),
                    ),
                    title: Text(
                      player['name']?.toString() ?? 'Player',
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}