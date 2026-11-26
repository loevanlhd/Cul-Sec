import 'dart:convert';

/// Message échangé entre les appareils d'une partie multijoueur.
///
/// Volontairement minimal : un type, un émetteur, et une charge utile JSON.
/// La logique de jeu vit dans les écrans ; le transport ne fait que
/// transporter.
class GameMessage {
  const GameMessage({
    required this.type,
    required this.senderId,
    this.payload = const <String, dynamic>{},
  });

  final String type;
  final String senderId;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type,
        'senderId': senderId,
        'payload': payload,
      };

  factory GameMessage.fromJson(Map<String, dynamic> json) => GameMessage(
        type: json['type'] as String? ?? '',
        senderId: json['senderId'] as String? ?? '',
        payload: json['payload'] as Map<String, dynamic>? ??
            <String, dynamic>{},
      );

  String encode() => jsonEncode(toJson());

  static GameMessage? tryDecode(String raw) {
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return GameMessage.fromJson(decoded);
    } on FormatException {
      return null;
    }
  }
}

/// Événement de transport : arrivée ou départ d'un pair.
class TransportEvent {
  const TransportEvent({
    required this.type,
    required this.peerId,
    this.displayName,
  });

  final TransportEventType type;
  final String peerId;
  final String? displayName;
}

enum TransportEventType { joined, left, connectionLost }