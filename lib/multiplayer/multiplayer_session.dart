import 'dart:convert';

class MultiplayerSnapshot {
  const MultiplayerSnapshot({
    required this.modeId,
    required this.turn,
    required this.players,
    required this.phase,
    required this.currentCard,
    required this.voterIndex,
    required this.votes,
    this.activePlayerId,
    this.activeKind,
    this.verdict,
    this.endGameData,
  });

  final String modeId;
  final int turn;
  final List<MultiplayerPlayer> players;
  final MultiplayerPhase phase;
  final MultiplayerCard? currentCard;
  final int voterIndex;
  final Map<String, String> votes;
  final String? activePlayerId;
  final String? activeKind;
  final MultiplayerVerdict? verdict;
  final MultiplayerEndData? endGameData;

  static const Object _sentinel = Object();

  MultiplayerSnapshot copyWith({
    String? modeId,
    int? turn,
    MultiplayerPhase? phase,
    MultiplayerCard? currentCard,
    bool clearCurrentCard = false,
    int? voterIndex,
    Map<String, String>? votes,
    Object? activePlayerId = _sentinel,
    Object? activeKind = _sentinel,
    Object? verdict = _sentinel,
    Object? endGameData = _sentinel,
  }) =>
      MultiplayerSnapshot(
        modeId: modeId ?? this.modeId,
        turn: turn ?? this.turn,
        players: players,
        phase: phase ?? this.phase,
        currentCard: clearCurrentCard ? null : (currentCard ?? this.currentCard),
        voterIndex: voterIndex ?? this.voterIndex,
        votes: votes ?? this.votes,
        activePlayerId: identical(activePlayerId, _sentinel)
            ? this.activePlayerId
            : activePlayerId as String?,
        activeKind: identical(activeKind, _sentinel)
            ? this.activeKind
            : activeKind as String?,
        verdict: identical(verdict, _sentinel)
            ? this.verdict
            : verdict as MultiplayerVerdict?,
        endGameData: identical(endGameData, _sentinel)
            ? this.endGameData
            : endGameData as MultiplayerEndData?,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'modeId': modeId,
        'turn': turn,
        'players': players.map((MultiplayerPlayer p) => p.toJson()).toList(),
        'phase': phase.name,
        'currentCard': currentCard?.toJson(),
        'voterIndex': voterIndex,
        'votes': votes,
        if (activePlayerId != null) 'activePlayerId': activePlayerId,
        if (activeKind != null) 'activeKind': activeKind,
        'verdict': verdict?.toJson(),
        if (endGameData != null) 'endGameData': endGameData!.toJson(),
      };

  factory MultiplayerSnapshot.fromJson(Map<String, dynamic> json) {
    final Object? rawPlayers = json['players'];
    final Object? rawCard = json['currentCard'];
    final Object? rawVotes = json['votes'];
    final Object? rawVerdict = json['verdict'];
    final Object? rawEnd = json['endGameData'];

    return MultiplayerSnapshot(
      modeId: json['modeId'] as String? ?? '',
      turn: (json['turn'] as num?)?.toInt() ?? 0,
      players: rawPlayers is List
          ? rawPlayers
              .whereType<Map<String, dynamic>>()
              .map(MultiplayerPlayer.fromJson)
              .toList()
          : const <MultiplayerPlayer>[],
      phase: MultiplayerPhase.fromName(json['phase'] as String?),
      currentCard: rawCard is Map<String, dynamic>
          ? MultiplayerCard.fromJson(rawCard)
          : null,
      voterIndex: (json['voterIndex'] as num?)?.toInt() ?? 0,
      votes: rawVotes is Map
          ? <String, String>{
              for (final MapEntry<dynamic, dynamic> e in rawVotes.entries)
                e.key.toString(): e.value.toString(),
            }
          : <String, String>{},
      activePlayerId: json['activePlayerId'] as String?,
      activeKind: json['activeKind'] as String?,
      verdict: rawVerdict is Map<String, dynamic>
          ? MultiplayerVerdict.fromJson(rawVerdict)
          : null,
      endGameData: rawEnd is Map<String, dynamic>
          ? MultiplayerEndData.fromJson(rawEnd)
          : null,
    );
  }

  String encode() => jsonEncode(toJson());

  static MultiplayerSnapshot? tryDecode(String raw) {
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return MultiplayerSnapshot.fromJson(decoded);
    } on FormatException {
      return null;
    }
  }
}

enum MultiplayerPhase {
  waiting,
  voting,
  revealed,
  finished;

  static MultiplayerPhase fromName(String? name) {
    for (final MultiplayerPhase p in MultiplayerPhase.values) {
      if (p.name == name) return p;
    }
    return MultiplayerPhase.waiting;
  }
}

class MultiplayerPlayer {
  const MultiplayerPlayer({
    required this.id,
    required this.name,
    required this.emoji,
    required this.colorIndex,
    this.photoBase64,
  });

  final String id;
  final String name;
  final String emoji;
  final int colorIndex;
  final String? photoBase64;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'emoji': emoji,
        'colorIndex': colorIndex,
        if (photoBase64 != null) 'photoBase64': photoBase64,
      };

  factory MultiplayerPlayer.fromJson(Map<String, dynamic> json) =>
      MultiplayerPlayer(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Joueur',
        emoji: json['emoji'] as String? ?? '🎉',
        colorIndex: (json['colorIndex'] as num?)?.toInt() ?? 0,
        photoBase64: json['photoBase64'] as String?,
      );
}

class MultiplayerCard {
  const MultiplayerCard({
    required this.id,
    required this.text,
    required this.kind,
    required this.categoryName,
    this.options = const <String>[],
  });

  final String id;
  final String text;
  final String kind;
  final String categoryName;
  final List<String> options;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'text': text,
        'kind': kind,
        'categoryName': categoryName,
        if (options.isNotEmpty) 'options': options,
      };

  factory MultiplayerCard.fromJson(Map<String, dynamic> json) {
    final Object? rawOptions = json['options'];
    return MultiplayerCard(
      id: json['id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      kind: json['kind'] as String? ?? 'statement',
      categoryName: json['categoryName'] as String? ?? 'general',
      options: rawOptions is List
          ? rawOptions.map((Object? e) => e.toString()).toList()
          : const <String>[],
    );
  }
}

class MultiplayerVerdict {
  const MultiplayerVerdict({
    required this.loserIds,
    required this.summary,
    this.extraJson = const <String, dynamic>{},
  });

  final List<String> loserIds;
  final String summary;
  final Map<String, dynamic> extraJson;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'loserIds': loserIds,
        'summary': summary,
        if (extraJson.isNotEmpty) 'extra': extraJson,
      };

  factory MultiplayerVerdict.fromJson(Map<String, dynamic> json) {
    final Object? rawIds = json['loserIds'];
    final Object? rawExtra = json['extra'];
    return MultiplayerVerdict(
      loserIds: rawIds is List
          ? rawIds.map((Object? e) => e.toString()).toList()
          : const <String>[],
      summary: json['summary'] as String? ?? '',
      extraJson: rawExtra is Map<String, dynamic>
          ? rawExtra
          : const <String, dynamic>{},
    );
  }
}

class MultiplayerEndData {
  const MultiplayerEndData({
    required this.ranking,
    required this.sips,
    required this.badges,
  });

  final List<MultiplayerPlayer> ranking;
  final Map<String, int> sips;
  final List<MultiplayerBadgeData> badges;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'ranking': ranking.map((p) => p.toJson()).toList(),
        'sips': sips,
        'badges': badges.map((b) => b.toJson()).toList(),
      };

  factory MultiplayerEndData.fromJson(Map<String, dynamic> json) {
    final Object? rawRanking = json['ranking'];
    final Object? rawSips = json['sips'];
    final Object? rawBadges = json['badges'];

    return MultiplayerEndData(
      ranking: rawRanking is List
          ? rawRanking
              .whereType<Map<String, dynamic>>()
              .map(MultiplayerPlayer.fromJson)
              .toList()
          : const <MultiplayerPlayer>[],
      sips: rawSips is Map
          ? <String, int>{
              for (final MapEntry<dynamic, dynamic> e in rawSips.entries)
                e.key.toString(): (e.value as num).toInt(),
            }
          : const <String, int>{},
      badges: rawBadges is List
          ? rawBadges
              .whereType<Map<String, dynamic>>()
              .map(MultiplayerBadgeData.fromJson)
              .toList()
          : const <MultiplayerBadgeData>[],
    );
  }
}

class MultiplayerBadgeData {
  const MultiplayerBadgeData({
    required this.emoji,
    required this.title,
    required this.detail,
    required this.playerId,
    required this.playerName,
    required this.colorValue,
  });

  final String emoji;
  final String title;
  final String detail;
  final String playerId;
  final String playerName;
  final int colorValue;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'emoji': emoji,
        'title': title,
        'detail': detail,
        'playerId': playerId,
        'playerName': playerName,
        'colorValue': colorValue,
      };

  factory MultiplayerBadgeData.fromJson(Map<String, dynamic> json) =>
      MultiplayerBadgeData(
        emoji: json['emoji'] as String? ?? '🏅',
        title: json['title'] as String? ?? '',
        detail: json['detail'] as String? ?? '',
        playerId: json['playerId'] as String? ?? '',
        playerName: json['playerName'] as String? ?? '',
        colorValue: (json['colorValue'] as num?)?.toInt() ?? 0,
      );
}