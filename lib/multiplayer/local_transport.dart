import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'game_message.dart';
import 'game_transport.dart';

class LocalTransport implements GameTransport {
  LocalTransport._({
    required this.selfId,
    required this.isHost,
    HttpServer? server,
    WebSocketChannel? client,
  })  : _server = server,
        _client = client;

  @override
  final String selfId;

  @override
  final bool isHost;

  final HttpServer? _server;
  final WebSocketChannel? _client;

  final Map<String, WebSocketChannel> _clients = <String, WebSocketChannel>{};

  final StreamController<GameMessage> _incoming =
      StreamController<GameMessage>.broadcast();

  final StreamController<TransportEvent> _events =
      StreamController<TransportEvent>.broadcast();

  @override
  Stream<GameMessage> get messages => _incoming.stream;

  @override
  Stream<TransportEvent> get events => _events.stream;

  Iterable<String> get connectedPeerIds => _clients.keys;

  static Future<({LocalTransport transport, int port})> startHost({
    required String roomCode,
    int port = 0,
  }) async {
    final String selfId = 'host-${DateTime.now().microsecondsSinceEpoch}';

    late final LocalTransport transport;

    final Handler wsHandler = webSocketHandler(
      (WebSocketChannel channel) {
        final String peerId =
            'peer-${DateTime.now().microsecondsSinceEpoch}';
        transport.registerClient(peerId, channel);
      },
    );

    HttpServer? server;
    int effectivePort = port;

    if (port != 0) {
      try {
        server = await shelf_io.serve(
          (Request req) {
            if (req.url.queryParameters['code'] != roomCode) {
              return Response.forbidden('Code invalide');
            }
            return wsHandler(req);
          },
          InternetAddress.anyIPv4,
          port,
        );
      } on SocketException {
        effectivePort = 0;
      }
    }

    server ??= await shelf_io.serve(
      (Request req) {
        if (req.url.queryParameters['code'] != roomCode) {
          return Response.forbidden('Code invalide');
        }
        return wsHandler(req);
      },
      InternetAddress.anyIPv4,
      effectivePort,
    );

    transport = LocalTransport._(
      selfId: selfId,
      isHost: true,
      server: server,
    );

    return (transport: transport, port: server.port);
  }

  static Future<LocalTransport> connectToHost({
    required String host,
    required int port,
    required String roomCode,
    String? displayName,
  }) async {
    final Uri uri = Uri(
      scheme: 'ws',
      host: host,
      port: port,
      path: '/',
      queryParameters: <String, String>{'code': roomCode},
    );

    final WebSocketChannel channel = WebSocketChannel.connect(uri);
    await channel.ready;

    final String selfId = 'peer-${DateTime.now().microsecondsSinceEpoch}';
    final LocalTransport transport = LocalTransport._(
      selfId: selfId,
      isHost: false,
      client: channel,
    );

    transport._wireClient(channel);

    return transport;
  }

  void _wireClient(WebSocketChannel channel) {
    // Le hello est supprimé ici. C'est le contrôleur qui fait le join_request.
    channel.stream.listen(
      (Object? raw) {
        final GameMessage? msg = GameMessage.tryDecode(raw.toString());
        if (msg != null) _incoming.add(msg);
      },
      onDone: () => _events.add(
        const TransportEvent(
          type: TransportEventType.connectionLost,
          peerId: 'host',
        ),
      ),
      onError: (_) => _events.add(
        const TransportEvent(
          type: TransportEventType.connectionLost,
          peerId: 'host',
        ),
      ),
    );
  }

  void registerClient(String peerId, WebSocketChannel channel) {
    _clients[peerId] = channel;

    channel.stream.listen(
      (Object? raw) {
        final GameMessage? msg = GameMessage.tryDecode(raw.toString());
        if (msg != null) _incoming.add(msg);
      },
      onDone: () {
        _clients.remove(peerId);
        _events.add(
          TransportEvent(type: TransportEventType.left, peerId: peerId),
        );
      },
      onError: (_) {
        _clients.remove(peerId);
        _events.add(
          TransportEvent(
            type: TransportEventType.connectionLost,
            peerId: peerId,
          ),
        );
      },
    );

    _events.add(
      TransportEvent(type: TransportEventType.joined, peerId: peerId),
    );
  }

  @override
  void broadcast(GameMessage message) {
    final String encoded = message.encode();
    if (isHost) {
      for (final WebSocketChannel c in _clients.values) {
        c.sink.add(encoded);
      }
    } else {
      _client?.sink.add(encoded);
    }
  }

  @override
  void sendTo(String peerId, GameMessage message) {
    final String encoded = message.encode();
    if (isHost) {
      _clients[peerId]?.sink.add(encoded);
    } else if (peerId == 'host') {
      _client?.sink.add(encoded);
    }
  }

  @override
  Future<void> close() async {
    await _incoming.close();
    await _events.close();
    for (final WebSocketChannel c in _clients.values) {
      await c.sink.close();
    }
    _clients.clear();
    await _client?.sink.close();
    await _server?.close(force: true);
  }
}