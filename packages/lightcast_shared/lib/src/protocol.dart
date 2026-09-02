enum MessageType {
  hello,
  pair,
  cameraStatus,
  videoOffer,
  videoAnswer,
  iceCandidate,
  heartbeat,
  sceneSnapshot,
  streamStatus,
}

class LightCastMessage {
  const LightCastMessage({
    required this.type,
    required this.senderId,
    required this.payload,
    this.protocolVersion = 1,
  });

  final MessageType type;
  final String senderId;
  final Map<String, dynamic> payload;
  final int protocolVersion;

  Map<String, dynamic> toJson() => {
        'protocolVersion': protocolVersion,
        'type': type.name,
        'senderId': senderId,
        'payload': payload,
      };

  factory LightCastMessage.fromJson(Map<String, dynamic> json) =>
      LightCastMessage(
        protocolVersion: json['protocolVersion'] as int? ?? 1,
        type: MessageType.values.firstWhere(
          (value) => value.name == json['type'],
          orElse: () => MessageType.heartbeat,
        ),
        senderId: json['senderId'] as String? ?? 'unknown',
        payload: Map<String, dynamic>.from(json['payload'] as Map? ?? {}),
      );
}
