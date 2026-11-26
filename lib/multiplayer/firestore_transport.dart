import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'game_message.dart';
import 'game_transport.dart';

class FirestoreTransport implements GameTransport {
  FirestoreTransport({
    required this.selfId,
    required this.isHost,
    required this.roomCode,
  });

  @override
  final String selfId;
  @override
  final bool isHost;
  final String roomCode;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final StreamController<GameMessage> _incoming = StreamController.broadcast();
  final StreamController<TransportEvent> _events = StreamController.broadcast();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _hostActionsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _clientActionsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _playersSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _stateSub;

  @override
  Stream<GameMessage> get messages => _incoming.stream;
  @override
  Stream<TransportEvent> get events => _events.stream;

  DocumentReference<Map<String, dynamic>> get _gameRef =>
      _db.collection('games').doc(roomCode);

  /// Démarre l'écoute en tant qu'Hôte.
  void listenAsHost() {
    // Écoute des actions (votes, join_request…) de tous les clients.
    _hostActionsSub = _gameRef
        .collection('actions')
        .orderBy('timestamp')
        .snapshots()
        .listen((QuerySnapshot<Map<String, dynamic>> snapshot) {
      for (final DocumentChange<Map<String, dynamic>> docChange
          in snapshot.docChanges) {
        if (docChange.type != DocumentChangeType.added) continue;
        final Map<String, dynamic>? data = docChange.doc.data();
        if (data == null || data['message'] == null) continue;

        // Un message ciblé qui ne nous concerne pas est ignoré.
        final Object? target = data['target'];
        if (target != null && target != selfId) continue;

        final Map<String, dynamic> rawMsg =
            (data['message'] as Map).cast<String, dynamic>();
        _incoming.add(GameMessage.fromJson(rawMsg));
      }
    });

    // Écoute des joueurs qui rejoignent ou quittent.
    _playersSub = _gameRef
        .collection('players')
        .snapshots()
        .listen((QuerySnapshot<Map<String, dynamic>> snapshot) {
      for (final DocumentChange<Map<String, dynamic>> docChange
          in snapshot.docChanges) {
        if (docChange.type == DocumentChangeType.added) {
          _events.add(
            TransportEvent(
              type: TransportEventType.joined,
              peerId: docChange.doc.id,
            ),
          );
        } else if (docChange.type == DocumentChangeType.removed) {
          _events.add(
            TransportEvent(
              type: TransportEventType.left,
              peerId: docChange.doc.id,
            ),
          );
        }
      }
    });
  }

  /// Démarre l'écoute en tant que Client.
  void listenAsClient() {
    _stateSub = _gameRef
        .snapshots()
        .listen((DocumentSnapshot<Map<String, dynamic>> snapshot) {
      // Si le document n'existe plus, c'est que l'hôte a quitté et a détruit la partie
      if (!snapshot.exists) {
        _events.add(
          const TransportEvent(
            type: TransportEventType.connectionLost,
            peerId: 'host',
          ),
        );
        return;
      }

      final Map<String, dynamic>? data = snapshot.data();
      if (data == null || data['snapshot'] == null) return;
      _incoming.add(
        GameMessage(
          type: 'snapshot',
          senderId: 'host',
          payload: <String, dynamic>{'snapshot': data['snapshot']},
        ),
      );
    });

    _clientActionsSub = _gameRef
        .collection('actions')
        .where('target', isEqualTo: selfId)
        .snapshots()
        .listen((QuerySnapshot<Map<String, dynamic>> snapshot) {
      for (final DocumentChange<Map<String, dynamic>> docChange
          in snapshot.docChanges) {
        if (docChange.type != DocumentChangeType.added) continue;
        final Map<String, dynamic>? data = docChange.doc.data();
        if (data == null || data['message'] == null) continue;
        final Map<String, dynamic> rawMsg =
            (data['message'] as Map).cast<String, dynamic>();
        _incoming.add(GameMessage.fromJson(rawMsg));
      }
    });
  }

  /// Rejoint la partie (côté client).
  Future<void> join() async {
    await _gameRef.collection('players').doc(selfId).set(
      <String, dynamic>{
        'joinedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  @override
  void broadcast(GameMessage message) {
    if (isHost) {
      _gameRef.set(
        <String, dynamic>{
          'snapshot': message.payload['snapshot'],
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } else {
      _gameRef.collection('actions').add(
        <String, dynamic>{
          'message': message.toJson(),
          'timestamp': FieldValue.serverTimestamp(),
        },
      );
    }
  }

  @override
  void sendTo(String peerId, GameMessage message) {
    _gameRef.collection('actions').add(
      <String, dynamic>{
        'message': message.toJson(),
        'target': peerId,
        'timestamp': FieldValue.serverTimestamp(),
      },
    );
  }

  @override
  Future<void> close() async {
    await _stateSub?.cancel();
    await _hostActionsSub?.cancel();
    await _clientActionsSub?.cancel();
    await _playersSub?.cancel();
    
    await _incoming.close();
    await _events.close();

    try {
      if (isHost) {
        // Si l'hôte quitte, on supprime la partie entière (et les sous-collections via le cascade delete si activé, sinon on supprime le doc principal)
        // Idéalement, il faudrait aussi nettoyer les sous-collections, mais supprimer le doc principal suffit pour notifier les clients.
        await _gameRef.delete();
      } else {
        // Si un client quitte, il supprime juste son profil
        await _gameRef.collection('players').doc(selfId).delete();
      }
    } catch (e) {
      // On ignore les erreurs réseau lors de la fermeture (ex: perte de wifi)
    }
  }
}