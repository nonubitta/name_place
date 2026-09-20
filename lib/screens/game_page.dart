import 'package:flutter/material.dart';

import '../models/player.dart';

class GamePage extends StatelessWidget {
  final bool isHost;
  final List<Player> players;

  const GamePage({
    super.key,
    required this.isHost,
    required this.players,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Game'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.play_circle_fill,
                size: 80,
              ),

              const SizedBox(height: 24),

              const Text(
                'Game Started!',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                isHost
                    ? 'You are the host'
                    : 'You joined the game',
              ),

              const SizedBox(height: 30),

              Text(
                '${players.length} players',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              ...players.map(
                (player) => ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person),
                  ),
                  title: Text(player.name),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}