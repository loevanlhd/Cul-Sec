import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../data/avatar_catalog.dart';
import '../models/player.dart';
import '../services/badges.dart';
import '../services/game_session.dart';
import 'game_message.dart';
import 'game_transport.dart';
import 'multiplayer_session.dart';

MultiplayerSnapshot _emptySnapshot(String modeId, List<Player> players) {
  return MultiplayerSnapshot(
    modeId: modeId,
    turn: 0,
    players: <MultiplayerPlayer>[
      for (final Player p in players)
        MultiplayerPlayer(
          id: p.id,
          name: p.name,
          emoji: p.emoji,
          colorIndex: p.colorIndex,
          photoBase64: p.photoBase64,
        ),
    ],
    phase: MultiplayerPhase.waiting,
    currentCard: null,
    voterIndex: 0,
    votes: const <String, String>{},
  );
}

class HostGameController extends ChangeNotifier {
  HostGameController({
    required this.transport,
    required Player hostPlayer,
  })  : _players = <Player>[hostPlayer],
        _sessions = <String, GameSession>{},
        _modeIds = <String>[],
        _multiGame = false,
        _currentModeId = 'lobby',
        _random = math.Random(),
        _snapshot = _emptySnapshot('lobby', <Player>[hostPlayer]) {
    _peerToPlayer[transport.selfId] = hostPlayer.id;
    _wireTransport();
    _broadcast();
    notifyListeners();
  }

  final GameTransport transport;
  final List<Player> _players;
  Map<String, GameSession> _sessions;
  List<String> _modeIds;
  bool _multiGame;

  final math.Random _random;

  String _currentModeId;

  GameSession get session => _sessions[_currentModeId]!;
  String get modeId => _currentModeId;
  bool get isMultiGame => _multiGame;

  bool get isInLobby => _currentModeId == 'lobby';
  List<Player> get players => List<Player>.unmodifiable(_players);

  Set<String> get connectedPlayerIds => _peerToPlayer.values.toSet();

  final Map<String, String> _peerToPlayer = <String, String>{};

  int _voterIndex = 0;
  final Map<String, String> _votes = <String, String>{};

  MultiplayerCard? _privateCard;
  String? _activePlayerId;

  late MultiplayerSnapshot _snapshot;
  MultiplayerSnapshot get snapshot => _snapshot;

  final ValueNotifier<int> connectedCount = ValueNotifier<int>(0);
  final ValueNotifier<Map<String, String>?> lastReaction = ValueNotifier(null);

  bool _disposed = false;

  bool isPlayerRemote(String playerId) =>
      _peerToPlayer.containsValue(playerId) &&
      !_peerToPlayer.entries.any(
        (MapEntry<String, String> e) =>
            e.value == playerId && e.key == transport.selfId,
      );

  bool get currentVoterIsLocal {
    if (_voterIndex >= _players.length) return false;
    return !isPlayerRemote(_players[_voterIndex].id);
  }

  int get currentVoterIndex =>
      _voterIndex >= _players.length ? -1 : _voterIndex;

  bool get activePlayerIsLocal =>
      _activePlayerId != null &&
      _players.isNotEmpty &&
      _activePlayerId == _players.first.id;

  MultiplayerCard? get localPrivateCard => _privateCard;

  @override
  void dispose() {
    _disposed = true;
    for (final GameSession s in _sessions.values) {
      s.removeListener(_onSessionChanged);
    }
    connectedCount.dispose();
    lastReaction.dispose();
    super.dispose();
  }

  void _wireTransport() {
    transport.events.listen((TransportEvent event) {
      if (_disposed) return;
      switch (event.type) {
        case TransportEventType.joined:
          break;
        case TransportEventType.left:
        case TransportEventType.connectionLost:
          final String? playerId = _peerToPlayer[event.peerId];
          if (playerId != null) {
            _peerToPlayer.remove(event.peerId);
            connectedCount.value = _peerToPlayer.length;
            
            if (!isInLobby) {
              _players.removeWhere((p) => p.id == playerId);
              _votes.remove(playerId);
              if (_voterIndex >= _players.length) {
                _voterIndex = 0;
              }
            } else {
              _players.removeWhere((p) => p.id == playerId);
            }
            
            _rebuildSnapshot();
            _broadcast();
          }
      }
    });
    transport.messages.listen(_onMessage);
  }

  void _wireSession(GameSession session) {
    session.addListener(_onSessionChanged);
  }

  void _onSessionChanged() {
    if (_disposed) return;
    _rebuildSnapshot();
    _broadcast();
  }

  void _onMessage(GameMessage message) {
    if (_disposed) return;
    switch (message.type) {
      case 'join_request':
        _handleJoinRequest(message.senderId, message.payload);
      case 'vote_cast':
        _handleVoteCast(message.senderId, message.payload);
      case 'mark_jnim':
        _handleMarkJnim(message.senderId);
      case 'av_choose':
        _handleAvChoose(message.senderId, message.payload);
      case 'av_refuse':
        _handleAvRefuse(message.senderId);
      case 'av_redraw':
        _handleAvRedraw(message.senderId);
      case 'av_done':
        _handleAvDone(message.senderId);
      case 'reaction':
        lastReaction.value = {
          'emoji': message.payload['emoji']?.toString() ?? '😂',
          'name': message.payload['name']?.toString() ?? 'Quelqu\'un',
        };
        notifyListeners();
      default:
        break;
    }
  }

  void _handleJoinRequest(String peerId, Map<String, dynamic> payload) {
    if (_peerToPlayer.containsKey(peerId)) return;

    final String? requestedPlayerId = payload['playerId']?.toString();
    if (requestedPlayerId != null) {
      final Player? existing = _players
          .where((Player p) => p.id == requestedPlayerId)
          .firstOrNull;
      final bool isConnected = _peerToPlayer.containsValue(requestedPlayerId);
      if (existing != null && !isConnected) {
        _peerToPlayer[peerId] = existing.id;
        transport.sendTo(
          peerId,
          GameMessage(
            type: 'assigned',
            senderId: transport.selfId,
            payload: <String, dynamic>{
              'playerId': existing.id,
              'name': existing.name,
              'emoji': existing.emoji,
              'colorIndex': existing.colorIndex,
              if (existing.photoBase64 != null)
                'photoBase64': existing.photoBase64,
            },
          ),
        );
        connectedCount.value = _peerToPlayer.length;
        _rebuildSnapshot();
        _broadcast();
        return;
      }
    }

    String name = payload['name']?.toString().trim() ?? 'Joueur';
    if (name.length < 3) {
      name = 'Joueur ${_players.length + 1}';
    }

    String emoji = payload['emoji']?.toString() ?? '🎉';
    final String? photoBase64 = payload['photoBase64']?.toString();

    if (photoBase64 == null || photoBase64.isEmpty) {
      final Set<String> takenAvatars = _players
          .where((p) => !p.hasPhoto)
          .map((p) => p.emoji)
          .toSet();
      
      if (takenAvatars.contains(emoji)) {
        emoji = AvatarCatalog.randomMascot(taken: takenAvatars);
      }
    }

    final Player newPlayer = Player(
      id: 'p_${DateTime.now().microsecondsSinceEpoch}_${_players.length}',
      name: name,
      emoji: emoji,
      photoBase64: photoBase64,
      colorIndex: _players.length,
    );

    _players.add(newPlayer);
    _peerToPlayer[peerId] = newPlayer.id;

    transport.sendTo(
      peerId,
      GameMessage(
        type: 'assigned',
        senderId: transport.selfId,
        payload: <String, dynamic>{
          'playerId': newPlayer.id,
          'name': newPlayer.name,
          'emoji': newPlayer.emoji,
          'colorIndex': newPlayer.colorIndex,
          if (newPlayer.photoBase64 != null) 'photoBase64': newPlayer.photoBase64,
        },
      ),
    );

    connectedCount.value = _peerToPlayer.length;
    _rebuildSnapshot();
    _broadcast();
  }

  void _handleVoteCast(String peerId, Map<String, dynamic> payload) {
    if (isInLobby) return;
    final String? voterPlayerId = _peerToPlayer[peerId];
    if (voterPlayerId == null) return;
    if (_voterIndex >= _players.length) return;
    if (_players[_voterIndex].id != voterPlayerId) return;

    final String choice = payload['choice']?.toString() ?? '';
    if (choice.isEmpty) return;

    _votes[voterPlayerId] = choice;
    _advanceVoter();
  }

  void _handleMarkJnim(String peerId) {
    if (isInLobby) return;
    final String? playerId = _peerToPlayer[peerId];
    if (playerId == null) return;
    _votes[playerId] = 'marked';
    _rebuildSnapshot();
    _broadcast();
  }

  void _handleAvChoose(String peerId, Map<String, dynamic> payload) {
    if (isInLobby || _currentModeId != 'action_ou_verite') return;
    final String? playerId = _peerToPlayer[peerId];
    if (playerId == null || playerId != _activePlayerId) return;
    final String kind = payload['kind']?.toString() ?? 'action';
    _drawPrivateCard(kind);
  }

  void _handleAvRefuse(String peerId) {
    if (isInLobby || _currentModeId != 'action_ou_verite') return;
    final String? playerId = _peerToPlayer[peerId];
    if (playerId == null || playerId != _activePlayerId) return;
    _resolveAv(refused: true);
  }

  void _handleAvRedraw(String peerId) {
    if (isInLobby || _currentModeId != 'action_ou_verite') return;
    final String? playerId = _peerToPlayer[peerId];
    if (playerId == null || playerId != _activePlayerId) return;

    final Player? player = _playerById(_activePlayerId!);
    if (player == null) return;
    session.recordSips(player, session.cappedSips(session.rules.actionRedraw));

    final String kind = _snapshot.activeKind ?? 'action';
    _drawPrivateCard(kind);
  }

  void _handleAvDone(String peerId) {
    if (isInLobby || _currentModeId != 'action_ou_verite') return;
    final String? playerId = _peerToPlayer[peerId];
    if (playerId == null || playerId != _activePlayerId) return;
    _resolveAv(refused: false);
  }

  void chooseAvLocally(String kind) {
    if (!activePlayerIsLocal) return;
    _drawPrivateCard(kind);
  }

  void refuseAvLocally() {
    if (!activePlayerIsLocal) return;
    _resolveAv(refused: true);
  }

  void redrawAvLocally() {
    if (!activePlayerIsLocal) return;
    final Player? player = _playerById(_activePlayerId!);
    if (player == null) return;
    session.recordSips(player, session.cappedSips(session.rules.actionRedraw));
    final String kind = _snapshot.activeKind ?? 'action';
    _drawPrivateCard(kind);
  }

  void doneAvLocally() {
    if (!activePlayerIsLocal) return;
    _resolveAv(refused: false);
  }

  void _drawPrivateCard(String kind) {
    final prompt = session.drawWhere((p) => p.kind.name == kind);
    if (prompt == null) return;

    _privateCard = MultiplayerCard(
      id: prompt.id,
      text: prompt.text,
      kind: prompt.kind.name,
      categoryName: prompt.category.name,
    );

    _snapshot = _snapshot.copyWith(
      phase: MultiplayerPhase.voting,
      clearCurrentCard: true,
      activeKind: kind,
      verdict: null,
    );

    final String? peerId = _peerForPlayer(_activePlayerId!);
    if (peerId != null && peerId != transport.selfId) {
      transport.sendTo(
        peerId,
        GameMessage(
          type: 'card_private',
          senderId: transport.selfId,
          payload: <String, dynamic>{
            'card': _privateCard!.toJson(),
            'kind': kind,
          },
        ),
      );
    }

    notifyListeners();
    _broadcast();
  }

  void _resolveAv({required bool refused}) {
    final Player? player = _playerById(_activePlayerId!);
    if (player == null) return;

    if (refused) {
      session.recordSips(
        player,
        session.cappedSips(session.rules.actionRefusal),
      );
      _snapshot = _snapshot.copyWith(
        phase: MultiplayerPhase.revealed,
        verdict: MultiplayerVerdict(
          loserIds: <String>[_activePlayerId!],
          summary: '${player.name} s’est dégonflé·e',
        ),
      );
    } else {
      _snapshot = _snapshot.copyWith(
        phase: MultiplayerPhase.revealed,
        verdict: MultiplayerVerdict(
          loserIds: const <String>[],
          summary: '${player.name} a relevé le défi !',
        ),
      );
    }

    _privateCard = null;
    notifyListeners();
    _broadcast();
  }

  String? _peerForPlayer(String playerId) {
    for (final MapEntry<String, String> e in _peerToPlayer.entries) {
      if (e.value == playerId) return e.key;
    }
    return null;
  }

  void castVoteLocally(String choice) {
    if (isInLobby) return;
    if (_voterIndex >= _players.length) return;
    final Player voter = _players[_voterIndex];
    if (isPlayerRemote(voter.id)) return;
    _votes[voter.id] = choice;
    _advanceVoter();
  }

  void markJnimLocally() {
    if (isInLobby) return;
    _votes[_players.first.id] = 'marked';
    _rebuildSnapshot();
    _broadcast();
  }

  void unmarkJnimLocally() {
    if (isInLobby) return;
    _votes.remove(_players.first.id);
    _rebuildSnapshot();
    _broadcast();
  }

  void _advanceVoter() {
    _voterIndex++;
    if (_voterIndex >= _players.length) {
      _computeVerdict();
    } else {
      _rebuildSnapshot();
      _broadcast();
    }
  }

  void _computeVerdict() {
    final MultiplayerVerdict verdict = _buildVerdict();
    _snapshot = _snapshot.copyWith(
      phase: MultiplayerPhase.revealed,
      votes: Map<String, String>.from(_votes),
      verdict: verdict,
    );
    _applyVerdict(verdict);
    notifyListeners();
    _broadcast();
  }

  void endJnimRound() {
    final MultiplayerVerdict verdict = _buildVerdictJnim();
    _snapshot = _snapshot.copyWith(
      phase: MultiplayerPhase.revealed,
      votes: Map<String, String>.from(_votes),
      verdict: verdict,
    );
    _applyVerdict(verdict);
    notifyListeners();
    _broadcast();
  }

  MultiplayerVerdict _buildVerdict() {
    switch (_currentModeId) {
      case 'tu_preferes':
        return _buildVerdictPreferes();
      case 'qui_pourrait':
        return _buildVerdictQuiPourrait();
      case 'je_nai_jamais':
        return _buildVerdictJnim();
      default:
        return const MultiplayerVerdict(loserIds: <String>[], summary: '');
    }
  }

  MultiplayerVerdict _buildVerdictPreferes() {
    int votesA = 0;
    int votesB = 0;
    for (final String choice in _votes.values) {
      if (choice == '0') {
        votesA++;
      } else if (choice == '1') {
        votesB++;
      }
    }
    final bool tie = votesA == votesB;
    final int losingSide = tie ? -1 : (votesA < votesB ? 0 : 1);
    final List<String> loserIds = <String>[
      for (final MapEntry<String, String> e in _votes.entries)
        if (tie || e.value == '$losingSide') e.key,
    ];
    final int sanction = session.cappedSips(session.rules.prefereMinority);
    final String summary = tie
        ? 'Égalité parfaite · tout le monde boit'
        : 'La minorité boit ${session.sanctionLabel(sanction)}';
    return MultiplayerVerdict(
      loserIds: loserIds,
      summary: summary,
      extraJson: <String, dynamic>{
        'votesA': votesA,
        'votesB': votesB,
        'losingSide': losingSide,
      },
    );
  }

  MultiplayerVerdict _buildVerdictQuiPourrait() {
    final Map<String, int> tally = <String, int>{};
    for (final String targetId in _votes.values) {
      tally[targetId] = (tally[targetId] ?? 0) + 1;
    }
    int best = 0;
    for (final int v in tally.values) {
      if (v > best) best = v;
    }
    final List<String> designated = best == 0
        ? const <String>[]
        : <String>[
            for (final MapEntry<String, int> e in tally.entries)
              if (e.value == best) e.key,
          ];
    final int sanction = session.cappedSips(session.rules.quiDesigne);
    final String summary = designated.isEmpty
        ? 'Personne n’a été désigné'
        : designated.length > 1
            ? 'Ex æquo · $sanction chacun'
            : session.sanctionLabel(sanction);
    return MultiplayerVerdict(
      loserIds: designated,
      summary: summary,
      extraJson: <String, dynamic>{'tally': tally},
    );
  }

  MultiplayerVerdict _buildVerdictJnim() {
    final List<String> concerned = <String>[
      for (final MapEntry<String, String> e in _votes.entries)
        if (e.value == 'marked') e.key,
    ];
    final int sanction = session.cappedSips(session.rules.jamaisConcerned);
    final String summary = concerned.isEmpty
        ? 'Personne n’est concerné'
        : concerned.length == 1
            ? '1 personne sur ${_players.length} est concernée'
            : '${concerned.length} sur ${_players.length} sont concernés';
    return MultiplayerVerdict(
      loserIds: concerned,
      summary: summary,
      extraJson: <String, dynamic>{
        'total': _players.length,
        'sanction': sanction,
      },
    );
  }

  void _applyVerdict(MultiplayerVerdict verdict) {
    if (verdict.loserIds.isEmpty) return;
    final int sips = switch (_currentModeId) {
      'qui_pourrait' => session.rules.quiDesigne,
      'je_nai_jamais' => session.rules.jamaisConcerned,
      _ => session.rules.prefereMinority,
    };
    for (final String id in verdict.loserIds) {
      final Player? player = _playerById(id);
      if (player == null) continue;
      session.recordSips(player, sips);
    }
  }

  void startGame({
    required Map<String, GameSession> sessions,
    required String modeId,
    required bool multiGame,
  }) {
    _sessions = sessions;
    _modeIds = sessions.keys.toList();
    _multiGame = multiGame;
    _currentModeId = modeId;

    for (final GameSession s in _sessions.values) {
      _wireSession(s);
    }

    _voterIndex = 0;
    _votes.clear();
    _privateCard = null;

    if (_currentModeId == 'action_ou_verite') {
      _activePlayerId = _players.isEmpty ? null : _players.first.id;
      _snapshot = MultiplayerSnapshot(
        modeId: _currentModeId,
        turn: session.turn,
        players: _snapshot.players,
        phase: MultiplayerPhase.waiting,
        currentCard: null,
        voterIndex: 0,
        votes: const <String, String>{},
        activePlayerId: _activePlayerId,
        activeKind: null,
        verdict: null,
      );
      notifyListeners();
      _broadcast(extra: <String, dynamic>{'event': 'game_started'});
      return;
    }

    _activePlayerId = null;
    session.next();
    _rebuildSnapshot();
    _broadcast(extra: <String, dynamic>{'event': 'game_started'});
  }

  void nextRound() {
    _voterIndex = 0;
    _votes.clear();
    _privateCard = null;

    if (_multiGame) {
      _currentModeId = _modeIds[_random.nextInt(_modeIds.length)];
    }

    if (_currentModeId == 'action_ou_verite') {
      final int currentIndex = _players.indexWhere(
        (Player p) => p.id == _activePlayerId,
      );
      final int nextIndex = currentIndex < 0
          ? 0
          : (currentIndex + 1) % _players.length;
      _activePlayerId = _players[nextIndex].id;

      _snapshot = MultiplayerSnapshot(
        modeId: _currentModeId,
        turn: session.turn,
        players: _snapshot.players,
        phase: MultiplayerPhase.waiting,
        currentCard: null,
        voterIndex: 0,
        votes: const <String, String>{},
        activePlayerId: _activePlayerId,
        activeKind: null,
        verdict: null,
      );
      notifyListeners();
      _broadcast();
      return;
    }

    _activePlayerId = null;
    session.next();
    _rebuildSnapshot();
    _broadcast();
  }

  void removePlayer(String playerId) {
    if (playerId == _players.first.id) return;
    final String? peerToRemove = _peerForPlayer(playerId);

    _players.removeWhere((p) => p.id == playerId);
    if (peerToRemove != null) _peerToPlayer.remove(peerToRemove);

    _votes.remove(playerId);
    if (_voterIndex >= _players.length) _voterIndex = 0;

    _rebuildSnapshot();
    _broadcast();
  }

  void endGame() {
    if (isInLobby) return;

    final List<Player> ranked = List<Player>.from(_players)
      ..sort((a, b) => session.sipsOf(b).compareTo(session.sipsOf(a)));

    final List<EveningBadge> rawBadges = computeBadges(session);
    final List<MultiplayerBadgeData> netBadges = rawBadges.map((b) => MultiplayerBadgeData(
      emoji: b.emoji,
      title: b.title,
      detail: b.detail,
      playerId: b.player.id,
      playerName: b.player.name,
      colorValue: b.color.toARGB32(),
    ),).toList();

    final MultiplayerEndData endData = MultiplayerEndData(
      ranking: ranked.map((p) => MultiplayerPlayer(id: p.id, name: p.name, emoji: p.emoji, colorIndex: p.colorIndex, photoBase64: p.photoBase64)).toList(),
      sips: Map<String, int>.from(session.sips),
      badges: netBadges,
    );

    _snapshot = _snapshot.copyWith(
      phase: MultiplayerPhase.finished,
      endGameData: endData,
    );

    notifyListeners();
    _broadcast();
  }

  void resetForReplay() {
    _currentModeId = 'lobby';
    _sessions.clear();
    _modeIds.clear();
    _votes.clear();
    _voterIndex = 0;
    _privateCard = null;
    _activePlayerId = null;
    
    _snapshot = _emptySnapshot('lobby', _players);
    
    notifyListeners();
    _broadcast();
  }

  void _rebuildSnapshot() {
    _snapshot = MultiplayerSnapshot(
      modeId: _currentModeId,
      turn: isInLobby ? 0 : session.turn,
      players: <MultiplayerPlayer>[
        for (final p in _players)
          MultiplayerPlayer(
            id: p.id,
            name: p.name,
            emoji: p.emoji,
            colorIndex: p.colorIndex,
            photoBase64: p.photoBase64,
          ),
      ],
      phase: isInLobby ? MultiplayerPhase.waiting : _phaseFromSession(),
      currentCard: isInLobby ? null : _cardFromSession(),
      voterIndex: _voterIndex,
      votes: Map<String, String>.from(_votes),
      activePlayerId: _activePlayerId,
      activeKind: _snapshot.activeKind,
      verdict: _snapshot.verdict,
      endGameData: _snapshot.endGameData,
    );
    notifyListeners();
  }

  MultiplayerPhase _phaseFromSession() {
    if (_currentModeId == 'je_nai_jamais' ||
        _currentModeId == 'action_ou_verite') {
      return _snapshot.phase;
    }
    if (_voterIndex >= _players.length) {
      return MultiplayerPhase.revealed;
    }
    if (session.current == null) {
      return MultiplayerPhase.waiting;
    }
    return MultiplayerPhase.voting;
  }

  MultiplayerCard? _cardFromSession() {
    if (_currentModeId == 'action_ou_verite') return null;
    final prompt = session.current;
    if (prompt == null) return null;
    return MultiplayerCard(
      id: prompt.id,
      text: prompt.text,
      kind: prompt.kind.name,
      categoryName: prompt.category.name,
      options: prompt.options,
    );
  }

  void _broadcast({Map<String, dynamic>? extra}) {
    final Map<String, dynamic> payload = <String, dynamic>{
      'snapshot': _snapshot.toJson(),
      if (extra != null) ...extra,
    };
    transport.broadcast(
      GameMessage(
        type: 'snapshot',
        senderId: transport.selfId,
        payload: payload,
      ),
    );
  }

  Player? _playerById(String id) {
    for (final Player p in _players) {
      if (p.id == id) {
        return p;
      }
    }
    return null;
  }
}