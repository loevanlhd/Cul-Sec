import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'game_message.dart';
import 'game_transport.dart';

class WebClientTransport implements GameTransport {
  WebClientTransport._({
    required this.selfId,
    required WebSocketChannel channel,
  }) : _channel = channel;

  @override
  final String selfId;

  @override
  bool get isHost => false;

  final WebSocketChannel _channel;

  final StreamController<GameMessage> _incoming =
      StreamController<GameMessage>.broadcast();

  final StreamController<TransportEvent> _events =
      StreamController<TransportEvent>.broadcast();

  @override
  Stream<GameMessage> get messages => _incoming.stream;

  @override
  Stream<TransportEvent> get events => _events.stream;

  static Future<WebClientTransport> connect({
    required Uri uri,
    String? displayName,
  }) async {
    final WebSocketChannel channel = WebSocketChannel.connect(uri);
    await channel.ready;

    final String selfId = 'web-${DateTime.now().microsecondsSinceEpoch}';
    final WebClientTransport transport = WebClientTransport._(
      selfId: selfId,
      channel: channel,
    );

    channel.stream.listen(
      (Object? raw) {
        final GameMessage? msg = GameMessage.tryDecode(raw.toString());
        if (msg != null) transport._incoming.add(msg);
      },
      onDone: () => transport._events.add(
        const TransportEvent(
          type: TransportEventType.connectionLost,
          peerId: 'host',
        ),
      ),
      onError: (_) => transport._events.add(
        const TransportEvent(
          type: TransportEventType.connectionLost,
          peerId: 'host',
        ),
      ),
    );

    // Le hello est supprimé ici. C'est le ClientGameController qui gère l'arrivée.

    return transport;
  }

  @override
  void broadcast(GameMessage message) {
    _channel.sink.add(message.encode());
  }

  @override
  void sendTo(String peerId, GameMessage message) {
    _channel.sink.add(message.encode());
  }

  @override
  Future<void> close() async {
    await _incoming.close();
    await _events.close();
    await _channel.sink.close();
  }
}