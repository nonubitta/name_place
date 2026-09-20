class GameRoom {
  final String roomCode;
  final String hostName;
  final String hostAddress;
  final int playerCount;

  GameRoom({
    required this.roomCode,
    required this.hostName,
    required this.hostAddress,
    required this.playerCount,
  });

  factory GameRoom.fromJson(
    Map<String, dynamic> json, {
    required String hostAddress,
  }) {
    return GameRoom(
      roomCode: json['roomCode']?.toString() ?? '',
      hostName: json['hostName']?.toString() ?? 'Host',
      hostAddress: hostAddress,
      playerCount: int.tryParse(
            json['playerCount']?.toString() ?? '0',
          ) ??
          0,
    );
  }
}