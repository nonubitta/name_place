import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/game_room.dart';

class DiscoveryService {
  static const int discoveryPort = 4041;

  RawDatagramSocket? _socket;
  Timer? _broadcastTimer;

  final StreamController<GameRoom> _roomsController =
      StreamController<GameRoom>.broadcast();

  Stream<GameRoom> get roomsStream => _roomsController.stream;

  Future<void> startHost({
    required String roomCode,
    required String hostName,
    required int playerCount,
  }) async {
    await stop();

    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      discoveryPort,
      reuseAddress: true,
      reusePort: true,
    );

    _socket!.broadcastEnabled = true;

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
    await stop();

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

  Future<void> stop() async {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;

    _socket?.close();
    _socket = null;
  }

  void dispose() {
    stop();
    _roomsController.close();
  }
}