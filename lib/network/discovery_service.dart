import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/game_room.dart';

class DiscoveryService {
  static const int discoveryPort = 4041;

  RawDatagramSocket? _socket;
  Timer? _broadcastTimer;
  bool _hosting = false;
  String? _hostRoomCode;

  final StreamController<GameRoom> _roomsController =
      StreamController<GameRoom>.broadcast();

    final StreamController<String> _closedRoomsController =
      StreamController<String>.broadcast();

  Stream<GameRoom> get roomsStream => _roomsController.stream;
    Stream<String> get closedRoomsStream => _closedRoomsController.stream;

  Future<void> startHost({
    required String roomCode,
    required String hostName,
    required int playerCount,
  }) async {
    await stop(announceClosure: false);

    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      discoveryPort,
      reuseAddress: true,
      reusePort: true,
    );

    _socket!.broadcastEnabled = true;
    _hosting = true;
    _hostRoomCode = roomCode;

    void broadcast() {
      final message = jsonEncode({
        'type': 'npat_game',
        'roomCode': roomCode,
        'hostName': hostName,
        'playerCount': playerCount,
      });

      final bytes = utf8.encode(message);

      _socket!.send(
        bytes,
        InternetAddress('255.255.255.255'),
        discoveryPort,
      );
    }

    broadcast();

    _broadcastTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => broadcast(),
    );
  }

  Future<void> startDiscovery() async {
    await stop(announceClosure: false);

    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      discoveryPort,
      reuseAddress: true,
      reusePort: true,
    );

    _socket!.broadcastEnabled = true;

    _socket!.listen((event) {
      if (event != RawSocketEvent.read) {
        return;
      }

      final datagram = _socket!.receive();

      if (datagram == null) {
        return;
      }

      try {
        final message = jsonDecode(
          utf8.decode(datagram.data),
        );

        if (message['type'] == 'npat_game_closed') {
          final roomCode = message['roomCode']?.toString();
          if (roomCode != null && roomCode.isNotEmpty) {
            _closedRoomsController.add(roomCode);
          }
          return;
        }

        if (message['type'] != 'npat_game') {
          return;
        }

        final room = GameRoom.fromJson(
          Map<String, dynamic>.from(message),
          hostAddress: datagram.address.address,
        );

        _roomsController.add(room);
      } catch (e) {
        print('Discovery packet error: $e');
      }
    });
  }

  Future<void> stop({bool announceClosure = true}) async {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;

    final socket = _socket;
    final roomCode = _hostRoomCode;

    if (announceClosure && _hosting && socket != null && roomCode != null) {
      socket.send(
        utf8.encode(
          jsonEncode({
            'type': 'npat_game_closed',
            'roomCode': roomCode,
          }),
        ),
        InternetAddress('255.255.255.255'),
        discoveryPort,
      );
    }

    _hosting = false;
    _hostRoomCode = null;
    socket?.close();
    _socket = null;
  }

  void dispose() {
    stop();
    _roomsController.close();
    _closedRoomsController.close();
  }
}