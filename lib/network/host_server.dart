import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:name_place/models/player_answers.dart';

import '../models/player_score.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import 'discovery_service.dart';

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

  final StreamController<Map<String, dynamic>> _resultsController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get resultsStream =>
      _resultsController.stream;

  Stream<List<Player>> get playersStream => _playersController.stream;

  Stream<void> get gameStartedStream =>
      _gameStartedController.stream;

  Stream<PlayerAnswers> get answersStream =>
      _answersController.stream;

  Map<String, PlayerAnswers> get submittedAnswers =>
      Map.unmodifiable(_submittedAnswers);

  String get roomCode => _roomCode;

  String _currentLetter = '';
  int _currentRound = 0;
  String _roomCode = '';

  String _hostName = 'Host';

  bool _gameStarted = false;

  bool get gameStarted => _gameStarted;

  bool _resultsBroadcasted = false;

  // Host overrides:
  // playerId -> category -> manually assigned score
  final Map<String, Map<String, int>> _scoreOverrides = {};

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

  bool get allPlayersSubmitted {
    return _submittedAnswers.length >= _players.length + 1;
  }

  void broadcastGameState(GameState state) {
    final message = jsonEncode({
      'type': 'game_state',
      'state': state.toJson(),
    });

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

            case 'submit_answers':
              _handleSubmitAnswers(
                playerId,
                message['answers'],
              );
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

  void _handleSubmitAnswers(
    String? playerId,
    dynamic rawAnswers,
  ) {
    if (playerId == null || playerId.isEmpty) {
      return;
    }

    if (!_connections.containsKey(playerId)) {
      return;
    }

    if (_submittedAnswers.containsKey(playerId)) {
      return;
    }

    final answers = <String, String>{};

    if (rawAnswers is Map) {
      rawAnswers.forEach((key, value) {
        answers[key.toString()] = value?.toString() ?? '';
      });
    }

    final submission = PlayerAnswers(
      playerId: playerId,
      answers: answers,
      submitted: true,
    );

    _submittedAnswers[playerId] = submission;

    _answersController.add(submission);

    if (allPlayersSubmitted) {
      _broadcastResults();
    }

    final socket = _connections[playerId];

    if (socket != null) {
      _send(socket, {
        'type': 'submission_received',
      });
    }

    final player = _players[playerId];

    print(
      'Answers received from ${player?.name ?? playerId}: $answers',
    );
  }

  void _removePlayer(String? playerId) {
    if (playerId == null) {
      return;
    }

    final player = _players.remove(playerId);

    _connections.remove(playerId);
    _submittedAnswers.remove(playerId);

    if (player != null) {
      print('Player disconnected: ${player.name}');
    }

    _broadcastPlayers();
  }

  void _broadcastPlayers() {
    final players =
        _players.values.map((player) => player.toJson()).toList();

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

    _updateDiscovery();
  }

  List<PlayerScore> _calculateScores() {
    final scores = <PlayerScore>[];

    final playerIds = _submittedAnswers.keys.toList();

    for (final playerId in playerIds) {
      final submission = _submittedAnswers[playerId]!;

      final categoryScores = <String, int>{};

      var total = 0;

      for (final category in submission.answers.keys) {
        final answer =
            submission.answers[category]?.trim() ?? '';

        int points;

        if (answer.isEmpty) {
          points = 0;
        } else {
          final normalizedAnswer = answer.toLowerCase();

          var matchingPlayers = 0;

          for (final otherPlayerId in playerIds) {
            final otherSubmission =
                _submittedAnswers[otherPlayerId];

            if (otherSubmission == null) {
              continue;
            }

            final otherAnswer =
                otherSubmission.answers[category]?.trim() ?? '';

            if (otherAnswer.isNotEmpty &&
                otherAnswer.toLowerCase() ==
                    normalizedAnswer) {
              matchingPlayers++;
            }
          }

          points = matchingPlayers > 1 ? 5 : 10;
        }

        // Host override takes precedence over automatic score.
        final override =
            _scoreOverrides[playerId]?[category];

        if (override != null) {
          points = override;
        }

        categoryScores[category] = points;
        total += points;
      }

      scores.add(
        PlayerScore(
          playerId: playerId,
          categoryScores: categoryScores,
          totalScore: total,
        ),
      );
    }

    return scores;
  }

  /// Called by the host to manually change one category score.
  void updateScore({
    required String playerId,
    required String category,
    required int score,
  }) {
    final safeScore = score < 0 ? 0 : score;

    _scoreOverrides.putIfAbsent(
      playerId,
      () => <String, int>{},
    )[category] = safeScore;

    print(
      'Score override: $playerId / $category = $safeScore',
    );

    // Recalculate and broadcast updated results.
    _broadcastResults(force: true);
  }

  void _updateDiscovery() {
    _discovery.startHost(
      roomCode: _roomCode,
      hostName: _hostName,
      playerCount: _players.length,
    );
  }

  GameState startFirstRound({
    List<String>? categories,
  }) {
    final random = Random.secure();

    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

    final letter =
        letters[random.nextInt(letters.length)];

    _currentLetter = letter;
    _currentRound = 1;

    final selectedCategories =
        categories == null || categories.isEmpty
            ? <String>[
                'Name',
                'Place',
                'Animal',
                'Thing',
              ]
            : List<String>.from(categories);

    _submittedAnswers.clear();

    _scoreOverrides.clear();

    _resultsBroadcasted = false;

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

  GameState? startGame({
    List<String>? categories,
  }) {
    if (_gameStarted) {
      return null;
    }

    _gameStarted = true;

    return startFirstRound(
      categories: categories,
    );
  }

  void _send(
    WebSocket socket,
    Map<String, dynamic> message,
  ) {
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

    _currentRound = 0;

    await _server?.close(force: true);

    _server = null;

    _gameStarted = false;
    _roomCode = '';
    _currentLetter = '';

    _submittedAnswers.clear();
    _scoreOverrides.clear();
    _resultsBroadcasted = false;

    _playersController.add(const []);
  }

  void submitHostAnswers(
    Map<String, String> answers,
  ) {
    if (_submittedAnswers.containsKey('host')) {
      return;
    }

    final submission = PlayerAnswers(
      playerId: 'host',
      answers: answers,
      submitted: true,
    );

    _submittedAnswers['host'] = submission;

    _answersController.add(submission);

    print('Host answers submitted: $answers');

    if (allPlayersSubmitted) {
      _broadcastResults();
    }
  }

  void _broadcastResults({
    bool force = false,
  }) {
    if (_resultsBroadcasted && !force) {
      return;
    }

    _resultsBroadcasted = true;

    final submissions = <String, dynamic>{};

    for (final entry in _submittedAnswers.entries) {
      submissions[entry.key] = entry.value.toJson();
    }

    final scores = _calculateScores();

    final message = {
      'type': 'round_results',
      'round': _currentRound,
      'letter': _currentLetter,
      'answers': submissions,
      'scores': scores
          .map((score) => score.toJson())
          .toList(),
    };

    _resultsController.add(message);

    final encoded = jsonEncode(message);

    for (final socket in _connections.values) {
      try {
        socket.add(encoded);
      } catch (_) {}
    }

    print(
      force
          ? 'Broadcasting updated results.'
          : 'All players submitted. Broadcasting results.',
    );
  }

  void dispose() {
    stop();
  }
}