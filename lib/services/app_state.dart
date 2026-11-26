import 'dart:async';
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/avatar_catalog.dart';
import '../models/enums.dart';
import '../models/game_rules.dart';
import '../models/player.dart';
import '../models/prompt.dart';
import 'content_service.dart';

/// État global persistant de l'application.
class AppState extends ChangeNotifier {
  AppState._(this._prefs) {
    _roster = Player.decodeList(_prefs.getString(_kPlayers));
    final String? raw = _prefs.getString(_kGameRules);
    if (raw != null) {
      try {
        final Object? decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _gameRules = GameRules.fromJson(decoded);
        }
      } on FormatException {
        // Une sauvegarde endommagée ne doit pas bloquer le lancement.
      }
    }
    _seen = (_prefs.getStringList(_kSeenCards) ?? const <String>[]).toSet();
    _applyDailyReset();
    _loadCustomCards();
  }

  final SharedPreferences _prefs;

  // --- Clés de persistance -------------------------------------------------
  static const String _kAgeConfirmed = 'age_confirmed';
  static const String _kIntensity = 'intensity';
  static const String _kPlayers = 'players';
  static const String _kGamesPlayed = 'games_played';
  static const String _kHaptics = 'haptics_enabled';
  static const String _kSounds = 'sounds_enabled';
  static const String _kCategories = 'categories';
  static const String _kGameRules = 'game_rules';
  static const String _kCustomCards = 'custom_cards';
  static const String _kSeenCards = 'seen_cards';
  static const String _kSeenResetAt = 'seen_reset_at';
  static const String _kEvents = 'events_enabled';
  static const String _kRoulette = 'roulette_enabled';
  static const String _kSavedGame = 'saved_game';
  static const String _kThemeMode = 'theme_mode';
  static const String _kFirebaseUid = 'firebase_uid';
  
  // Multijoueur local
  static const String _kLastGameUri = 'last_game_uri';
  static const String _kLastPlayerId = 'last_player_id';

  // Multijoueur en ligne (sauvegarde de session)
  static const String _kOnlineRoomCode = 'online_room_code';
  static const String _kOnlinePlayerId = 'online_player_id';

  static const int _dailyResetHour = 12;
  static const int _seenLimit = 600;
  static const Duration _flushDelay = Duration(milliseconds: 500);

  late List<Player> _roster;
  GameRules _gameRules = const GameRules();

  final Map<GameModeId, List<Prompt>> _customCards = <GameModeId, List<Prompt>>{
    for (final GameModeId id in GameModeId.values) id: <Prompt>[],
  };

  late Set<String> _seen;

  Timer? _seenFlush;
  Timer? _gameFlush;
  Map<String, dynamic>? _pendingGame;

  @override
  void dispose() {
    _seenFlush?.cancel();
    _gameFlush?.cancel();
    _prefs.setStringList(_kSeenCards, _seen.toList());
    final Map<String, dynamic>? pending = _pendingGame;
    if (pending != null) {
      _prefs.setString(_kSavedGame, jsonEncode(pending));
    }
    super.dispose();
  }

  void _scheduleSeenFlush() {
    _seenFlush?.cancel();
    _seenFlush = Timer(_flushDelay, () {
      _prefs.setStringList(_kSeenCards, _seen.toList());
    });
  }

  void _scheduleGameFlush() {
    _gameFlush?.cancel();
    _gameFlush = Timer(_flushDelay, () {
      final Map<String, dynamic>? pending = _pendingGame;
      if (pending != null) {
        _prefs.setString(_kSavedGame, jsonEncode(pending));
        _pendingGame = null;
      }
    });
  }

  static Future<AppState> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return AppState._(prefs);
  }

  // --- Thème de l'application ----------------------------------------------
  ThemeMode get themeMode {
    final String? value = _prefs.getString(_kThemeMode);
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString(_kThemeMode, mode.name);
    notifyListeners();
  }

  // --- Identifiant Firebase ---
  String? get firebaseUid => _prefs.getString(_kFirebaseUid);

  Future<void> setFirebaseUid(String uid) async {
    await _prefs.setString(_kFirebaseUid, uid);
    notifyListeners();
  }

  // --- Confirmation d'âge --------------------------------------------------
  bool get isAgeConfirmed => _prefs.getBool(_kAgeConfirmed) ?? false;

  Future<void> confirmAge() async {
    await _prefs.setBool(_kAgeConfirmed, true);
    notifyListeners();
  }

  // --- Intensité -----------------------------------------------------------
  Intensity get intensity {
    final int index = _prefs.getInt(_kIntensity) ?? Intensity.normal.index;
    return Intensity.values[index.clamp(0, Intensity.values.length - 1)];
  }

  Future<void> setIntensity(Intensity value) async {
    if (value == intensity) return;
    await _prefs.setInt(_kIntensity, value.index);
    notifyListeners();
  }

  // --- Barème de partie ----------------------------------------------------
  GameRules get gameRules => _gameRules;

  Future<void> setGameRules(GameRules rules) async {
    _gameRules = rules;
    await _prefs.setString(_kGameRules, jsonEncode(rules.toJson()));
    notifyListeners();
  }

  Future<void> resetGameRules() async {
    _gameRules = const GameRules();
    await _prefs.remove(_kGameRules);
    notifyListeners();
  }

  // --- Thèmes --------------------------------------------------------------
  Set<GameCategory> get categories {
    final List<String>? raw = _prefs.getStringList(_kCategories);
    if (raw == null || raw.isEmpty) return <GameCategory>{};
    return raw.map(GameCategory.fromJson).toSet();
  }

  bool isCategoryOn(GameCategory c) {
    final Set<GameCategory> set = categories;
    return set.isEmpty || set.contains(c);
  }

  Future<void> toggleCategory(GameCategory c, List<GameCategory> available) async {
    Set<GameCategory> set = categories;
    if (set.isEmpty) set = available.toSet();

    if (set.contains(c)) {
      if (set.length > 1) set.remove(c);
    } else {
      set.add(c);
    }

    if (set.length == available.length) {
      await _prefs.remove(_kCategories);
    } else {
      await _prefs.setStringList(
        _kCategories,
        set.map((GameCategory e) => e.name).toList(),
      );
    }
    notifyListeners();
  }

  Future<void> resetCategories() async {
    await _prefs.remove(_kCategories);
    notifyListeners();
  }

  // --- Cartes personnalisées -----------------------------------------------
  void _loadCustomCards() {
    final String? raw = _prefs.getString(_kCustomCards);
    if (raw != null && raw.isNotEmpty) {
      try {
        final Object? decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          for (final GameModeId id in GameModeId.values) {
            final Object? list = decoded[id.slug];
            if (list is! List) continue;
            _customCards[id] = list
                .whereType<Map<String, dynamic>>()
                .map(Prompt.fromJson)
                .where((Prompt p) => p.id.isNotEmpty && p.text.isNotEmpty)
                .toList();
          }
        }
      } on FormatException {
        // Sauvegarde endommagée : on repart sans carte perso.
      }
    }
    _syncCustomCards();
  }

  void _syncCustomCards() {
    ContentService.instance.setCustomCards(<String, List<Prompt>>{
      for (final MapEntry<GameModeId, List<Prompt>> e in _customCards.entries)
        e.key.slug: e.value,
    });
  }

  Future<void> _persistCustomCards() async {
    _syncCustomCards();
    notifyListeners();
    await _prefs.setString(
      _kCustomCards,
      jsonEncode(<String, dynamic>{
        for (final MapEntry<GameModeId, List<Prompt>> e in _customCards.entries)
          e.key.slug: e.value.map((Prompt p) => p.toJson()).toList(),
      }),
    );
  }

  List<Prompt> customCardsFor(GameModeId id) =>
      List<Prompt>.unmodifiable(_customCards[id] ?? const <Prompt>[]);

  int get customCardCount => _customCards.values
      .fold<int>(0, (int sum, List<Prompt> list) => sum + list.length);

  Future<void> saveCustomCard(GameModeId mode, Prompt card) async {
    for (final MapEntry<GameModeId, List<Prompt>> e in _customCards.entries) {
      if (e.key != mode) e.value.removeWhere((Prompt p) => p.id == card.id);
    }
    final List<Prompt> target = _customCards[mode]!;
    final int index = target.indexWhere((Prompt p) => p.id == card.id);
    if (index >= 0) {
      target[index] = card;
    } else {
      target.add(card);
    }
    await _persistCustomCards();
  }

  Future<void> deleteCustomCard(String id) async {
    for (final List<Prompt> list in _customCards.values) {
      list.removeWhere((Prompt p) => p.id == id);
    }
    if (_seen.remove(id)) _scheduleSeenFlush();
    await _persistCustomCards();
  }

  // --- Partage de cartes personnalisées ------------------------------------

  String exportCustomCards() {
    final Map<String, dynamic> data = <String, dynamic>{
      for (final MapEntry<GameModeId, List<Prompt>> e in _customCards.entries)
        if (e.value.isNotEmpty)
          e.key.slug: e.value.map((Prompt p) => p.toJson()).toList(),
    };
    if (data.isEmpty) return '';
    
    final String jsonStr = jsonEncode(data);
    final List<int> gzipped = const GZipEncoder().encode(utf8.encode(jsonStr));
    return base64Url.encode(gzipped);
  }

  Future<int> importCustomCards(String code) async {
    try {
      final List<int> compressed = base64Url.decode(code.trim());
      final List<int> decompressed = const GZipDecoder().decodeBytes(compressed);
      final String jsonStr = utf8.decode(decompressed);
      final Object? decoded = jsonDecode(jsonStr);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Données corrompues.');
      }

      int importedCount = 0;
      final int timestamp = DateTime.now().microsecondsSinceEpoch;

      for (final GameModeId id in GameModeId.values) {
        final Object? list = decoded[id.slug];
        if (list is! List) continue;

        for (final Object? item in list) {
          if (item is! Map<String, dynamic>) continue;
          
          final Prompt imported = Prompt.fromJson(item);
          final Prompt newPrompt = Prompt(
            id: '${Prompt.customPrefix}${timestamp}_$importedCount',
            text: imported.text,
            kind: imported.kind,
            intensity: imported.intensity,
            category: imported.category,
            gorgees: imported.gorgees,
            options: imported.options,
          );

          final bool exists = _customCards[id]!.any((p) => p.text == newPrompt.text);
          if (!exists) {
            _customCards[id]!.add(newPrompt);
            importedCount++;
          }
        }
      }

      if (importedCount > 0) {
        await _persistCustomCards();
      }
      return importedCount;
    } catch (_) {
      throw const FormatException('Code invalide ou corrompu.');
    }
  }

  // --- Cartes déjà vues ----------------------------------------------------
  Set<String> get seenCards {
    _applyDailyReset();
    return Set<String>.unmodifiable(_seen);
  }

  int get seenCount {
    _applyDailyReset();
    return _seen.length;
  }

  static DateTime _lastResetMoment(DateTime now) {
    final DateTime todayNoon = DateTime(now.year, now.month, now.day, _dailyResetHour);
    return now.isBefore(todayNoon)
        ? DateTime(now.year, now.month, now.day - 1, _dailyResetHour)
        : todayNoon;
  }

  void _applyDailyReset() {
    final DateTime now = DateTime.now();
    final int? last = _prefs.getInt(_kSeenResetAt);

    if (last == null) {
      _prefs.setInt(_kSeenResetAt, now.millisecondsSinceEpoch);
      return;
    }

    final DateTime lastReset = DateTime.fromMillisecondsSinceEpoch(last);
    if (!lastReset.isBefore(_lastResetMoment(now))) return;

    _seen.clear();
    _prefs.remove(_kSeenCards);
    _prefs.setInt(_kSeenResetAt, now.millisecondsSinceEpoch);
  }

  void markCardSeen(String id) {
    _seen
      ..remove(id)
      ..add(id);
    while (_seen.length > _seenLimit) {
      _seen.remove(_seen.first);
    }
    _scheduleSeenFlush();
  }

  void forgetSeenCards(Iterable<String> ids) {
    _seen.removeAll(ids);
    _scheduleSeenFlush();
  }

  Future<void> resetSeenCards() async {
    _seen.clear();
    _seenFlush?.cancel();
    await _prefs.remove(_kSeenCards);
    await _prefs.setInt(_kSeenResetAt, DateTime.now().millisecondsSinceEpoch);
    notifyListeners();
  }

  // --- Cartes Événement et roulette ---------------------------------------
  bool get eventsEnabled => _prefs.getBool(_kEvents) ?? true;

  Future<void> setEventsEnabled(bool value) async {
    await _prefs.setBool(_kEvents, value);
    notifyListeners();
  }

  bool get rouletteEnabled => _prefs.getBool(_kRoulette) ?? true;

  Future<void> setRouletteEnabled(bool value) async {
    await _prefs.setBool(_kRoulette, value);
    notifyListeners();
  }

  // --- Partie en cours (reprise locale) ------------------------------------
  Map<String, dynamic>? get savedGame {
    final Map<String, dynamic>? pending = _pendingGame;
    if (pending != null) return pending;

    final String? raw = _prefs.getString(_kSavedGame);
    if (raw == null) return null;
    try {
      final Object? decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  void saveGame(Map<String, dynamic> snapshot) {
    _pendingGame = snapshot;
    _scheduleGameFlush();
  }

  Future<void> clearSavedGame() async {
    _gameFlush?.cancel();
    _pendingGame = null;
    await _prefs.remove(_kSavedGame);
  }

  // --- Multijoueur local : reconnexion -------------------------------------
  String? get lastGameUri => _prefs.getString(_kLastGameUri);
  String? get lastPlayerId => _prefs.getString(_kLastPlayerId);

  Future<void> saveMultiplayerSession(String uri, String playerId) async {
    await _prefs.setString(_kLastGameUri, uri);
    await _prefs.setString(_kLastPlayerId, playerId);
  }

  Future<void> clearMultiplayerSession() async {
    await _prefs.remove(_kLastGameUri);
    await _prefs.remove(_kLastPlayerId);
  }

  // --- Multijoueur en ligne : session et reconnexion -----------------------
  String? get onlineRoomCode => _prefs.getString(_kOnlineRoomCode);
  String? get onlinePlayerId => _prefs.getString(_kOnlinePlayerId);

  Future<void> saveOnlineSession(String roomCode, String playerId) async {
    await _prefs.setString(_kOnlineRoomCode, roomCode);
    await _prefs.setString(_kOnlinePlayerId, playerId);
  }

  Future<void> clearOnlineSession() async {
    await _prefs.remove(_kOnlineRoomCode);
    await _prefs.remove(_kOnlinePlayerId);
  }

  // --- Retour haptique -----------------------------------------------------
  bool get hapticsEnabled => _prefs.getBool(_kHaptics) ?? false;
  bool get soundsEnabled => _prefs.getBool(_kSounds) ?? true;

  Future<void> setSounds(bool value) async {
    await _prefs.setBool(_kSounds, value);
    notifyListeners();
  }

  Future<void> setHaptics(bool value) async {
    await _prefs.setBool(_kHaptics, value);
    notifyListeners();
  }

  // --- Répertoire de joueurs -----------------------------------------------
  List<Player> get roster => List<Player>.unmodifiable(_roster);

  List<Player> get players =>
      List<Player>.unmodifiable(_roster.where((Player p) => p.isSelected));

  int get selectedCount => players.length;

  bool get hasEnoughPlayers => selectedCount >= 2;

  Future<void> _persist() async {
    await _prefs.setString(_kPlayers, Player.encodeList(_roster));
    notifyListeners();
  }

  Future<void> addPlayer(String name, String emoji) async {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _roster.add(
      Player(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: trimmed,
        emoji: emoji,
        colorIndex: _roster.length,
      ),
    );
    await _persist();
  }

  Future<void> deletePlayer(String id) async {
    _roster.removeWhere((Player p) => p.id == id);
    await _persist();
  }

  Future<void> renamePlayer(String id, String name) async {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) return;
    for (final Player p in _roster) {
      if (p.id == id) p.name = trimmed;
    }
    await _persist();
  }

  Future<void> setAvatar(String id, String emoji) async {
    final Player? target = _playerById(id);
    if (target == null) return;

    final bool alreadyTaken = target.isSelected && _roster.any(
      (Player p) =>
          p.id != id && p.isSelected && !p.hasPhoto && p.emoji == emoji,
    );
    if (alreadyTaken) return;

    target
      ..emoji = emoji
      ..photoBase64 = null;
    await _persist();
  }

  Future<void> setPhoto(String id, String? base64) async {
    for (final Player p in _roster) {
      if (p.id == id) p.photoBase64 = base64;
    }
    await _persist();
  }

  Future<void> clearPhoto(String id) => setPhoto(id, null);

  Future<void> setNoDrink(String id, bool value) async {
    for (final Player p in _roster) {
      if (p.id == id) p.noDrink = value;
    }
    await _persist();
  }

  Player? _playerById(String id) {
    for (final Player player in _roster) {
      if (player.id == id) return player;
    }
    return null;
  }

  Set<String> _activeAvatars({String? exceptId}) => _roster
      .where(
        (Player p) => p.id != exceptId && p.isSelected && !p.hasPhoto,
      )
      .map((Player p) => p.emoji)
      .toSet();

  Future<void> toggleSelected(String id) async {
    final Player? player = _playerById(id);
    if (player == null) return;

    if (player.isSelected) {
      player.isSelected = false;
    } else {
      final Set<String> taken = _activeAvatars(exceptId: id);
      player.isSelected = true;
      if (!player.hasPhoto && taken.contains(player.emoji)) {
        player.emoji = AvatarCatalog.randomMascot(taken: taken);
      }
    }
    await _persist();
  }

  Future<void> selectAll(bool selected) async {
    if (!selected) {
      for (final Player p in _roster) {
        p.isSelected = false;
      }
    } else {
      final Set<String> taken = <String>{};
      for (final Player p in _roster) {
        p.isSelected = true;
        if (p.hasPhoto) continue;
        if (taken.contains(p.emoji)) {
          p.emoji = AvatarCatalog.randomMascot(taken: taken);
        }
        taken.add(p.emoji);
      }
    }
    await _persist();
  }

  Future<void> reorderPlayers(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _roster.length) return;
    final Player moved = _roster.removeAt(oldIndex);
    _roster.insert(newIndex.clamp(0, _roster.length), moved);
    await _persist();
  }

  // --- Statistiques --------------------------------------------------------
  int get gamesPlayed => _prefs.getInt(_kGamesPlayed) ?? 0;

  Future<void> incrementGamesPlayed() async {
    await _prefs.setInt(_kGamesPlayed, gamesPlayed + 1);
    for (final Player p in _roster) {
      if (p.isSelected) p.gamesPlayed++;
    }
    await _persist();
  }

  Future<void> mergeSessionStats(Map<String, int> sips) async {
    for (final Player p in _roster) {
      final int value = sips[p.id] ?? 0;
      if (value > 0) p.totalSips += value;
    }
    await _persist();
  }

  Future<void> resetStats() async {
    await _prefs.setInt(_kGamesPlayed, 0);
    for (final Player p in _roster) {
      p.gamesPlayed = 0;
      p.totalSips = 0;
    }
    await _persist();
  }
}