import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class PlayerClient {
  WebSocketChannel? _channel;

  final StreamController<List<Map<String, dynamic>>> _playersController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  final StreamController<String> _statusController =
      StreamController<String>.broadcast();

  Stream<List<Map<String, dynamic>>> get playersStream =>
      _playersController.stream;

  Stream<String> get statusStream => _statusController.stream;

  Future<void> connect({
    required String host,
    required String playerId,
    required String playerName,
  }) async {
    await disconnect();

    final url = Uri.parse('ws://$host:4040/ws');

    _statusController.add('Connecting...');

    try {
      _channel = WebSocketChannel.connect(url);

      await _channel!.ready;

      _statusController.add('Connected');

      _channel!.stream.listen(
        (data) {
          _handleMessage(data);
        },
        onDone: () {
          _statusController.add('Disconnected');
        },
        onError: (error) {
          _statusController.add('Connection error');
        },
      );

      _send({
        'type': 'join',
        'id': playerId,
        'name': playerName,
      });
    } catch (e) {
      _statusController.add('Unable to connect');
      rethrow;
    }
  }

  void _handleMessage(dynamic data) {
    try {
      final message = jsonDecode(data.toString());

      if (message['type'] == 'joined') {
        _statusController.add('Joined game');
      }

      if (message['type'] == 'players') {
        final players =
            List<Map<String, dynamic>>.from(message['players'] ?? []);

        _playersController.add(players);
      }
    } catch (e) {
      print('Invalid server message: $e');
    }
  }

  void _send(Map<String, dynamic> message) {
    _channel?.sink.add(jsonEncode(message));
  }

  Future<void> disconnect() async {
    try {
      await _channel?.sink.close();
    } catch (_) {}

    _channel = null;
  }

  void dispose() {
    disconnect();
    _playersController.close();
    _statusController.close();
  }
}