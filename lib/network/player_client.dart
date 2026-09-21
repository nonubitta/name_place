import 'dart:async';
import 'dart:convert';
import '../services/game_history_service.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import 'package:flutter/widgets.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class PlayerClient with WidgetsBindingObserver {
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

  final StreamController<Map<String, dynamic>> _resultsController =
      StreamController<Map<String, dynamic>>.broadcast();

  final StreamController<void> _gameEndedController =
      StreamController<void>.broadcast();

  final StreamController<Map<String, dynamic>> _playerActivityController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<void> get gameEndedStream => _gameEndedController.stream;

  Stream<Map<String, dynamic>> get playerActivityStream =>
      _playerActivityController.stream;

  Stream<GameState> get gameStateStream => _gameStateController.stream;

  List<Player> _latestPlayers = [];

  Completer<void>? _joinCompleter;

  Stream<List<Player>> get playersStream => _playersController.stream;

  Stream<String> get statusStream => _statusController.stream;

  Stream<void> get gameStartedStream => _gameStartedController.stream;

  List<Player> get latestPlayers => List.unmodifiable(_latestPlayers);

  Stream<void> get submissionReceivedStream =>
      _submissionReceivedController.stream;

  Stream<Map<String, dynamic>> get resultsStream => _resultsController.stream;

  bool get isConnected => _channel != null;
  String _playerId = '';
  String _playerName = '';
  final Map<String, int> _totalScores = {};

  bool _lifecycleObserverRegistered = false;
  bool _appBackgrounded = false;

  Map<String, int> get totalScores => Map.unmodifiable(_totalScores);

  Future<void> connect({
    required String host,
    required String playerId,
    required String playerName,
  }) async {
    await disconnect();
    _playerId = playerId;
    _playerName = playerName;
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

      await _joinCompleter!.future;

      print('Host confirmed player joined');

      _startLifecycleObserver();
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

        case 'round_results':
          final results = Map<String, dynamic>.from(message);

          _updateTotalScores(results);

          unawaited(GameHistoryService.saveRoundResults(results));

          _resultsController.add(results);
          break;

        case 'player_minimized':
        case 'player_resumed':
          _handlePlayerActivity(message);
          break;

        case 'game_ended':
          _gameEndedController.add(null);
          break;

        default:
          print('Unknown server message type: $type');
      }
    } catch (e) {
      print('Invalid server message: $e');
    }
  }

  void _handlePlayerActivity(Map<String, dynamic> message) {
    _playerActivityController.add(Map<String, dynamic>.from(message));
  }

  void _startLifecycleObserver() {
    if (_lifecycleObserverRegistered) {
      return;
    }

    WidgetsBinding.instance.addObserver(this);
    _lifecycleObserverRegistered = true;
    _appBackgrounded = false;
  }

  void _stopLifecycleObserver() {
    if (!_lifecycleObserverRegistered) {
      return;
    }

    WidgetsBinding.instance.removeObserver(this);
    _lifecycleObserverRegistered = false;
    _appBackgrounded = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_channel == null) {
      return;
    }

    if (state == AppLifecycleState.paused && !_appBackgrounded) {
      _appBackgrounded = true;
      _send({'type': 'player_minimized'});
      return;
    }

    if (state == AppLifecycleState.resumed && _appBackgrounded) {
      _appBackgrounded = false;
      _send({'type': 'player_resumed'});
    }
  }

  void _updateTotalScores(Map<String, dynamic> message) {
    final rawTotals = message['totalScores'];

    if (rawTotals is! Map) {
      return;
    }

    _totalScores.clear();

    rawTotals.forEach((key, value) {
      _totalScores[key.toString()] = int.tryParse(value.toString()) ?? 0;
    });
  }

  void _handleJoined(Map<String, dynamic> message) {
    final roomCode = message['roomCode']?.toString() ?? '';

    if (roomCode.isNotEmpty) {
      unawaited(
        GameHistoryService.startGame(
          gameId: roomCode,
          players: [Player(id: _playerId, name: _playerName)],
        ),
      );
    }

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

    final gameId = GameHistoryService.currentGameId;

    gameId.then((id) {
      if (id == null || id.isEmpty) {
        return;
      }

      unawaited(GameHistoryService.updatePlayers(gameId: id, players: players));
    });

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
    _stopLifecycleObserver();
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
    _resultsController.close();
    _gameEndedController.close();
    _playerActivityController.close();
  }
}
