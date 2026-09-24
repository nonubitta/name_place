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

    final broadcastAddresses = await _getBroadcastAddresses();

    void broadcast() {
      final message = jsonEncode({
        'type': 'npat_game',
        'roomCode': roomCode,
        'hostName': hostName,
        'playerCount': playerCount,
      });

      final bytes = utf8.encode(message);

      for (final address in broadcastAddresses) {
        try {
          _socket!.send(
            bytes,
            address,
            discoveryPort,
          );
        } catch (e) {
          print('Discovery broadcast error to $address: $e');
        }
      }
    }

    broadcast();

    _broadcastTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => broadcast(),
    );
  }

  Future<List<InternetAddress>> _getBroadcastAddresses() async {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );

    final addresses = <InternetAddress>[];

    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (address.type != InternetAddressType.IPv4) {
          continue;
        }

        final parts = address.address.split('.');

        if (parts.length != 4) {
          continue;
        }

        final broadcastAddress =
            '${parts[0]}.${parts[1]}.${parts[2]}.255';

        final broadcast = InternetAddress(broadcastAddress);

        if (!addresses.any((a) => a.address == broadcast.address)) {
          addresses.add(broadcast);
        }
      }
    }

    // Fallback in case no interface was found.
    if (addresses.isEmpty) {
      addresses.add(InternetAddress('255.255.255.255'));
    }

    return addresses;
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
      final broadcastAddresses = await _getBroadcastAddresses();

      final message = utf8.encode(
        jsonEncode({
          'type': 'npat_game_closed',
          'roomCode': roomCode,
        }),
      );

      for (final address in broadcastAddresses) {
        try {
          socket.send(
            message,
            address,
            discoveryPort,
          );
        } catch (e) {
          print('Discovery close broadcast error to $address: $e');
        }
      }
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