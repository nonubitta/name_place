import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:name_place/models/player_answers.dart';

import '../models/game_state.dart';
import '../models/player.dart';
import 'discovery_service.dart';
import 'dart:math';
import '../models/game_state.dart';

class HostServer {
  static const int webSocketPort = 4040;

  HttpServer? _server;

  final DiscoveryService _discovery = DiscoveryService();

  final Map<String, WebSocket> _connections = {};
  final Map<String, Player> _players = {};
  final StreamController<PlayerAnswers> _answersController =
      StreamController<PlayerAnswers>.broadcast();

  final Map<String, PlayerAnswers> _submittedAnswers = {};
  final StreamController<List<Player>> _playersController =
      StreamController<List<Player>>.broadcast();

  final StreamController<void> _gameStartedController =
      StreamController<void>.broadcast();

  Stream<List<Player>> get playersStream => _playersController.stream;

  Stream<void> get gameStartedStream => _gameStartedController.stream;

  Stream<PlayerAnswers> get answersStream => _answersController.stream;

  Map<String, PlayerAnswers> get submittedAnswers =>
      Map.unmodifiable(_submittedAnswers);
  String get roomCode => _roomCode;

  String _roomCode = '';

  String _hostName = 'Host';

  bool _gameStarted = false;

  bool get gameStarted => _gameStarted;

  Future<void> start({required String hostName}) async {
    await stop();

    _hostName = hostName;
    _roomCode = _generateRoomCode();

    _server = await HttpServer.bind(
      InternetAddress.anyIPv4,
      webSocketPort,
      shared: true,
    );

    _server!.listen(_handleRequest);

    await _discovery.startHost(
      roomCode: _roomCode,
      hostName: _hostName,
      playerCount: _players.length,
    );

    print('Host started');
    print('Room: $_roomCode');
  }

  String _generateRoomCode() {
    const characters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

    final random = Random.secure();

    return List.generate(
      4,
      (_) => characters[random.nextInt(characters.length)],
    ).join();
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

  void broadcastGameState(GameState state) {
    final message = jsonEncode({'type': 'game_state', 'state': state.toJson()});

    for (final socket in _connections.values) {
      try {
        socket.add(message);
      } catch (_) {}
    }
  }

  void _handleWebSocket(WebSocket socket) {
    String? playerId;

    socket.listen(
      (data) {
        try {
          final message = jsonDecode(data.toString());

          final type = message['type'];

          switch (type) {
            case 'join':
              playerId = message['id']?.toString();

              if (playerId == null || playerId!.isEmpty) {
                socket.close();
                return;
              }

              final player = Player(
                id: playerId!,
                name: message['name']?.toString() ?? 'Player',
              );

              _connections[playerId!] = socket;
              _players[playerId!] = player;

              _send(socket, {
                'type': 'joined',
                'id': player.id,
                'roomCode': _roomCode,
              });

              _broadcastPlayers();

              print('Player connected: ${player.name}');
              break;

            case 'leave':
              _removePlayer(playerId);
              playerId = null;
              break;
          }
        } catch (e) {
          print('Invalid message: $e');
        }
      },
      onDone: () {
        _removePlayer(playerId);
      },
      onError: (error) {
        _removePlayer(playerId);
        print('WebSocket error: $error');
      },
      cancelOnError: false,
    );
  }

  void _removePlayer(String? playerId) {
    if (playerId == null) {
      return;
    }

    final player = _players.remove(playerId);
    _connections.remove(playerId);

    if (player != null) {
      print('Player disconnected: ${player.name}');
    }

    _broadcastPlayers();
  }

  void _broadcastPlayers() {
    final players = _players.values.map((player) => player.toJson()).toList();

    final message = jsonEncode({'type': 'players', 'players': players});

    for (final socket in _connections.values) {
      try {
        socket.add(message);
      } catch (_) {}
    }

    _playersController.add(List.unmodifiable(_players.values));

    _updateDiscovery();
  }

  void _updateDiscovery() {
    _discovery.startHost(
      roomCode: _roomCode,
      hostName: _hostName,
      playerCount: _players.length,
    );
  }

  GameState startFirstRound({List<String>? categories}) {
    final random = Random.secure();
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

    final letter = letters[random.nextInt(letters.length)];

    final selectedCategories = categories == null || categories.isEmpty
        ? <String>['Name', 'Place', 'Animal', 'Thing']
        : List<String>.from(categories);

    _submittedAnswers.clear();

    final state = GameState(
      phase: GamePhase.playing,
      letter: letter,
      round: 1,
      timeRemaining: 30,
      categories: selectedCategories,
    );

    broadcastGameState(state);

    return state;
  }

  GameState? startGame({List<String>? categories}) {
    if (_gameStarted) {
      return null;
    }

    _gameStarted = true;

    return startFirstRound(categories: categories);
  }

  void _send(WebSocket socket, Map<String, dynamic> message) {
    socket.add(jsonEncode(message));
  }

  Future<void> stop() async {
    await _discovery.stop();

    for (final socket in _connections.values) {
      try {
        await socket.close();
      } catch (_) {}
    }

    _connections.clear();
    _players.clear();

    await _server?.close(force: true);
    _server = null;

    _gameStarted = false;
    _roomCode = '';

    _playersController.add(const []);
  }

  void dispose() {
    _discovery.dispose();
    _playersController.close();
    _gameStartedController.close();

    stop();
  }
}
