import 'package:flutter/foundation.dart';

import '../models/player.dart';
import 'game_message.dart';
import 'game_transport.dart';
import 'multiplayer_session.dart';

class ClientGameController extends ChangeNotifier {
  ClientGameController({ required this.transport });

  final GameTransport transport;

  MultiplayerSnapshot? _snapshot;
  MultiplayerSnapshot? get snapshot => _snapshot;

  String? _assignedPlayerId;
  String? get assignedPlayerId => _assignedPlayerId;

  String? _assignedName;
  String? get assignedName => _assignedName;

  String? _assignedEmoji;
  String? get assignedEmoji => _assignedEmoji;

  int _assignedColorIndex = 0;
  int get assignedColorIndex => _assignedColorIndex;

  String? _assignedPhotoBase64;
  String? get assignedPhotoBase64 => _assignedPhotoBase64;

  MultiplayerCard? _privateCard;
  MultiplayerCard? get privateCard => _privateCard;

  MultiplayerEndData? get endData => _snapshot?.endGameData;

  bool get isMarked {
    final MultiplayerSnapshot? snap = _snapshot;
    final String? id = _assignedPlayerId;
    if (snap == null || id == null) return false;
    return snap.votes[id] == 'marked';
  }

  final ValueNotifier<bool> disconnected = ValueNotifier<bool>(false);
  final ValueNotifier<Map<String, String>?> lastReaction = ValueNotifier(null);
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    disconnected.dispose();
    lastReaction.dispose();
    super.dispose();
  }

  void start({ required Player player, String? reconnectPlayerId }) {
    transport.messages.listen(_onMessage);
    transport.events.listen(_onEvent);

    transport.broadcast(
      GameMessage(
        type: 'join_request',
        senderId: transport.selfId,
        payload: <String, dynamic>{
          'name': player.name,
          'emoji': player.emoji,
          if (player.photoBase64 != null) 'photoBase64': player.photoBase64,
          if (reconnectPlayerId != null) 'playerId': reconnectPlayerId,
        },
      ),
    );
  }

  void _onEvent(TransportEvent event) {
    if (_disposed) return;
    if (event.type == TransportEventType.connectionLost || event.type == TransportEventType.left) {
      if (event.peerId == 'host') {
        disconnected.value = true;
        notifyListeners();
      }
    }
  }

  void _onMessage(GameMessage message) {
    if (_disposed) return;
    switch (message.type) {
      case 'assigned':
        _assignedPlayerId = message.payload['playerId']?.toString();
        _assignedName = message.payload['name']?.toString();
        _assignedEmoji = message.payload['emoji']?.toString();
        _assignedColorIndex = (message.payload['colorIndex'] as num?)?.toInt() ?? 0;
        _assignedPhotoBase64 = message.payload['photoBase64']?.toString();
        notifyListeners();
      case 'snapshot':
        _handleSnapshot(message.payload);
      case 'card_private':
        _handlePrivateCard(message.payload);
      case 'reaction':
        lastReaction.value = {
          'emoji': message.payload['emoji']?.toString() ?? '😂',
          'name': message.payload['name']?.toString() ?? 'Quelqu\'un',
        };
        notifyListeners();
      default: break;
    }
  }

  void _handleSnapshot(Map<String, dynamic> payload) {
    final Object? raw = payload['snapshot'];
    if (raw is! Map<String, dynamic>) return;
    final MultiplayerSnapshot next = MultiplayerSnapshot.fromJson(raw);
    if (next.activePlayerId != _snapshot?.activePlayerId || next.phase != MultiplayerPhase.voting) {
      _privateCard = null;
    }
    _snapshot = next;
    notifyListeners();
  }

  void _handlePrivateCard(Map<String, dynamic> payload) {
    final Object? raw = payload['card'];
    if (raw is! Map<String, dynamic>) return;
    _privateCard = MultiplayerCard.fromJson(raw);
    notifyListeners();
  }

  void castVote(String choice) {
    if (_assignedPlayerId == null) return;
    transport.broadcast(GameMessage(type: 'vote_cast', senderId: transport.selfId, payload: <String, dynamic>{'playerId': _assignedPlayerId, 'choice': choice}));
  }

  void markJnim() { transport.broadcast(GameMessage(type: 'mark_jnim', senderId: transport.selfId, payload: const <String, dynamic>{})); }
  void chooseAv(String kind) { transport.broadcast(GameMessage(type: 'av_choose', senderId: transport.selfId, payload: <String, dynamic>{'kind': kind})); }
  void refuseAv() { transport.broadcast(GameMessage(type: 'av_refuse', senderId: transport.selfId, payload: const <String, dynamic>{})); }
  void redrawAv() { transport.broadcast(GameMessage(type: 'av_redraw', senderId: transport.selfId, payload: const <String, dynamic>{})); }
  void doneAv() { transport.broadcast(GameMessage(type: 'av_done', senderId: transport.selfId, payload: const <String, dynamic>{})); }

  void sendReaction(String emoji, String playerName) {
    transport.broadcast(GameMessage(
      type: 'reaction', 
      senderId: transport.selfId, 
      payload: {'emoji': emoji, 'name': playerName},
    ),);
  }
}