import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/player.dart';

class HostServer {
  HttpServer? _server;

  final Map<String, WebSocket> _connections = {};
  final Map<String, Player> _players = {};

  final StreamController<List<Player>> _playersController =
      StreamController<List<Player>>.broadcast();

  Stream<List<Player>> get playersStream => _playersController.stream;

  int get playerCount => _players.length;

  Future<String> start() async {
    await stop();

    _server = await HttpServer.bind(
      InternetAddress.anyIPv4,
      4040,
      shared: true,
    );

    _server!.listen(_handleRequest);

    final addresses = await _getLocalAddresses();

    if (addresses.isEmpty) {
      return 'http://localhost:4040';
    }

    return 'ws://${addresses.first}:4040';
  }

  Future<List<String>> _getLocalAddresses() async {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );

    final addresses = <String>[];

    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (!address.isLoopback) {
          addresses.add(address.address);
        }
      }
    }

    return addresses;
  }

  void _handleRequest(HttpRequest request) {
    if (request.uri.path != '/ws') {
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('Not Found')
        ..close();
      return;
    }

    WebSocketTransformer.upgrade(request).then(_handleWebSocket);
  }

  void _handleWebSocket(WebSocket socket) {
    String? playerId;

    socket.listen(
      (data) {
        try {
          final message = jsonDecode(data as String);

          final type = message['type'];

          if (type == 'join') {
            playerId = message['id']?.toString();

            if (playerId == null) {
              socket.close();
              return;
            }

            final player = Player(
              id: playerId!,
              name: message['name']?.toString() ?? 'Player',
              address: 'Connected',
            );

            _connections[playerId!] = socket;
            _players[playerId!] = player;

            _send(
              socket,
              {
                'type': 'joined',
                'id': player.id,
              },
            );

            _broadcastPlayers();

            print('Player connected: ${player.name}');
          }
        } catch (e) {
          print('Invalid message: $e');
        }
      },
      onDone: () {
        if (playerId != null) {
          _connections.remove(playerId);
          _players.remove(playerId);

          _broadcastPlayers();

          print('Player disconnected: $playerId');
        }
      },
      onError: (error) {
        if (playerId != null) {
          _connections.remove(playerId);
          _players.remove(playerId);

          _broadcastPlayers();
        }

        print('WebSocket error: $error');
      },
      cancelOnError: false,
    );
  }

  void _broadcastPlayers() {
    final players = _players.values
        .map(
          (player) => {
            'id': player.id,
            'name': player.name,
          },
        )
        .toList();

    final message = jsonEncode({
      'type': 'players',
      'players': players,
    });

    for (final socket in _connections.values) {
      try {
        socket.add(message);
      } catch (_) {}
    }

    _playersController.add(
      List.unmodifiable(_players.values),
    );
  }

  void _send(
    WebSocket socket,
    Map<String, dynamic> message,
  ) {
    socket.add(jsonEncode(message));
  }

  Future<void> stop() async {
    for (final socket in _connections.values) {
      try {
        await socket.close();
      } catch (_) {}
    }

    _connections.clear();
    _players.clear();

    await _server?.close(force: true);
    _server = null;

    _playersController.add(const []);
  }

  void dispose() {
    _playersController.close();
    stop();
  }
}