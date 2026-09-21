import 'dart:async';
import 'dart:convert';
import '../models/game_state.dart';
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

  final StreamController<GameState> _gameStateController =
      StreamController<GameState>.broadcast();

  final StreamController<void> _submissionReceivedController =
      StreamController<void>.broadcast();

  Stream<GameState> get gameStateStream => _gameStateController.stream;

  List<Player> _latestPlayers = [];

  Completer<void>? _joinCompleter;

  Stream<List<Player>> get playersStream => _playersController.stream;

  Stream<String> get statusStream => _statusController.stream;

  Stream<void> get gameStartedStream => _gameStartedController.stream;

  List<Player> get latestPlayers => List.unmodifiable(_latestPlayers);

  Stream<void> get submissionReceivedStream =>
      _submissionReceivedController.stream;

  bool get isConnected => _channel != null;

  Future<void> connect({
    required String host,
    required String playerId,
    required String playerName,
  }) async {
    await disconnect();

    final url = Uri.parse('ws://$host:4040/ws');

    _statusController.add('Connecting...');

    _joinCompleter = Completer<void>();

    try {
      print('Connecting to: $url');

      _channel = WebSocketChannel.connect(url);

      await _channel!.ready;

      print('WebSocket connection established');

      _statusController.add('Connected to host');

      _channel!.stream.listen(
        _handleMessage,
        onDone: () {
          print('WebSocket disconnected');

          _channel = null;

          if (_joinCompleter != null && !_joinCompleter!.isCompleted) {
            _joinCompleter!.completeError(
              Exception('Host closed the connection before joining.'),
            );
          }

          _statusController.add('Disconnected');
        },
        onError: (error) {
          print('WebSocket error: $error');

          _channel = null;

          if (_joinCompleter != null && !_joinCompleter!.isCompleted) {
            _joinCompleter!.completeError(error);
          }

          _statusController.add('Connection error: $error');
        },
        cancelOnError: false,
      );

      _send({'type': 'join', 'id': playerId, 'name': playerName});

      print('Join request sent');

      // Wait until the HOST confirms that we joined.
      await _joinCompleter!.future;

      print('Host confirmed player joined');

      _statusController.add('Joined game');
    } catch (e) {
      print('Connection failed: $e');

      _channel = null;

      _statusController.add('Connection failed');

      rethrow;
    }
  }

  void _handleMessage(dynamic data) {
    try {
      final message = jsonDecode(data.toString());

      final type = message['type'];

      print('Received message: $message');

      switch (type) {
        case 'joined':
          _handleJoined(message);
          break;

        case 'players':
          _handlePlayers(message);
          break;

        case 'start_game':
          _gameStartedController.add(null);
          break;

        case 'game_state':
          final state = GameState.fromJson(
            Map<String, dynamic>.from(message['state']),
          );

          _gameStateController.add(state);
          break;

        case 'submission_received':
          print('Host received our answers');
          _submissionReceivedController.add(null);
          break;

        default:
          print('Unknown server message type: $type');
      }
    } catch (e) {
      print('Invalid server message: $e');
    }
  }

  void _handleJoined(Map<String, dynamic> message) {
    final roomCode = message['roomCode']?.toString() ?? '';

    print('JOIN CONFIRMED. Room: $roomCode');

    if (_joinCompleter != null && !_joinCompleter!.isCompleted) {
      _joinCompleter!.complete();
    }
  }

  void _handlePlayers(Map<String, dynamic> message) {
    final rawPlayers = message['players'] as List<dynamic>? ?? [];

    final players = rawPlayers
        .map((json) => Player.fromJson(Map<String, dynamic>.from(json)))
        .toList();

    _latestPlayers = players;

    _playersController.add(List.unmodifiable(_latestPlayers));
  }

  void _send(Map<String, dynamic> message) {
    if (_channel == null) {
      return;
    }

    _channel!.sink.add(jsonEncode(message));
  }

  void submitAnswers(Map<String, String> answers) {
    if (_channel == null) {
      print('Cannot submit answers: not connected');
      return;
    }

    final message = {'type': 'submit_answers', 'answers': answers};

    print('Submitting answers: $answers');

    _channel!.sink.add(jsonEncode(message));
  }

  Future<void> disconnect() async {
    _joinCompleter = null;

    if (_channel != null) {
      try {
        _send({'type': 'leave'});

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
    _gameStateController.close();
    _submissionReceivedController.close();
  }
}
