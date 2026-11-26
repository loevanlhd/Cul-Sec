import 'game_message.dart';

/// Abstraction du transport entre appareils.
///
/// Une seule interface pour deux implémentations :
///  * `LocalTransport`      — serveur WebSocket embarqué (mobile/desktop).
///  * `WebClientTransport`  — client WebSocket pur (mobile, desktop, web).
///
/// Les écrans de jeu ne connaissent que cette interface : le jour où un
/// vrai serveur distant arrive, il suffit d'écrire une troisième
/// implémentation sans toucher au reste.
abstract class GameTransport {
  /// Identifiant unique de cet appareil dans la session.
  String get selfId;

  /// Vrai si ce transport est l'hôte (autorité de la partie).
  bool get isHost;

  /// Envoie un message à tous les autres pairs.
  void broadcast(GameMessage message);

  /// Envoie un message à un pair précis.
  void sendTo(String peerId, GameMessage message);

  /// Flux des messages reçus (tous pairs confondus).
  Stream<GameMessage> get messages;

  /// Flux des événements de connexion (arrivée / départ).
  Stream<TransportEvent> get events;

  /// Ferme le transport et libère les ressources.
  Future<void> close();
}