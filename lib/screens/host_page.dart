import 'dart:async';

import 'package:flutter/material.dart';

import '../models/player.dart';
import '../network/host_server.dart';

class HostPage extends StatefulWidget {
  const HostPage({super.key});

  @override
  State<HostPage> createState() => _HostPageState();
}

class _HostPageState extends State<HostPage> {
  final HostServer _server = HostServer();

  StreamSubscription<List<Player>>? _subscription;

  List<Player> _players = [];
  String? _serverAddress;
  bool _starting = true;

  @override
  void initState() {
    super.initState();
    _startServer();
  }

  Future<void> _startServer() async {
    try {
      final address = await _server.start();

      _subscription = _server.playersStream.listen((players) {
        if (!mounted) return;

        setState(() {
          _players = players;
        });
      });

      if (!mounted) return;

      setState(() {
        _serverAddress = address;
        _starting = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _starting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not start server: $e'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _server.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Host Game'),
      ),
      body: _starting
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.wifi_tethering,
                    size: 70,
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Host is ready',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    'Make sure all phones are connected to the same Wi-Fi network.',
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 24),

                  if (_serverAddress != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Text(
                              'Server Address',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              _serverAddress!,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  Text(
                    '${_players.length} connected',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Expanded(
                    child: _players.isEmpty
                        ? const Center(
                            child: Text(
                              'Waiting for players...',
                              style: TextStyle(
                                fontSize: 18,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _players.length,
                            itemBuilder: (context, index) {
                              final player = _players[index];

                              return Card(
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    child: Icon(Icons.person),
                                  ),
                                  title: Text(player.name),
                                  subtitle: Text(player.id),
                                  trailing: const Icon(
                                    Icons.check_circle,
                                  ),
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