import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/player.dart';

class PlayerClient {
  WebSocketChannel? _channel;

  final StreamController<List<Player>> _playersController =
      StreamController<List<Player>>.broadcast();

  final StreamController<String> _statusController =
      StreamController<String>.broadcast();

  final StreamController<void> _gameStartedController =
      StreamController<void>.broadcast();

  Stream<List<Player>> get playersStream =>
      _playersController.stream;

  Stream<String> get statusStream =>
      _statusController.stream;

  Stream<void> get gameStartedStream =>
      _gameStartedController.stream;

  bool get isConnected => _channel != null;

  Future<void> connect({
    required String host,
    required String playerId,
    required String playerName,
  }) async {
    await disconnect();

    final url = Uri.parse(
      'ws://$host:4040/ws',
    );

    _statusController.add('Connecting...');

    try {
      _channel = WebSocketChannel.connect(url);

      await _channel!.ready;

      _statusController.add('Connected');

      _channel!.stream.listen(
        _handleMessage,
        onDone: () {
          _channel = null;
          _statusController.add('Disconnected');
        },
        onError: (error) {
          _channel = null;
          _statusController.add('Connection error');
        },
      );

      _send({
        'type': 'join',
        'id': playerId,
        'name': playerName,
      });
    } catch (e) {
      _channel = null;
      _statusController.add('Unable to connect');
      rethrow;
    }
  }

  void _handleMessage(dynamic data) {
    try {
      final message = jsonDecode(data.toString());

      final type = message['type'];

      switch (type) {
        case 'joined':
          _statusController.add('Joined game');
          break;

        case 'players':
          final rawPlayers = message['players'] as List<dynamic>;

          final players = rawPlayers
              .map(
                (json) => Player.fromJson(
                  Map<String, dynamic>.from(json),
                ),
              )
              .toList();

          _playersController.add(players);
          break;

        case 'start_game':
          _gameStartedController.add(null);
          break;
      }
    } catch (e) {
      print('Invalid server message: $e');
    }
  }

  void _send(Map<String, dynamic> message) {
    _channel?.sink.add(
      jsonEncode(message),
    );
  }

  Future<void> disconnect() async {
    if (_channel != null) {
      try {
        _send({
          'type': 'leave',
        });

        await _channel!.sink.close();
      } catch (_) {}
    }

    _channel = null;
  }

  void dispose() {
    disconnect();

    _playersController.close();
    _statusController.close();
    _gameStartedController.close();
  }
}