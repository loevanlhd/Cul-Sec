import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/enums.dart';
import '../models/game_rules.dart';
import '../models/player.dart';
import '../models/prompt.dart';
import 'sober_gages.dart';

/// Gage attribué à un joueur en mode « Je ne bois pas » à la place de ses
/// gorgées.
class GageNotice {
  const GageNotice({required this.player, required this.sips, required this.gage});

  final Player player;
  final int sips;
  final String gage;
}

/// Score partagé d'une soirée : gorgées, tours, ordre de passage et
/// chronomètre. En multi-jeu, toutes les sessions des jeux choisis
/// partagent le même score : rien n'est perdu quand le jeu change.
class SessionScore {
  SessionScore({DateTime? startedAt}) : startedAt = startedAt ?? DateTime.now();

  final DateTime startedAt;
  final Map<String, int> sips = <String, int>{};
  int turn = 0;
  int playerCursor = 0;

  /// Compteurs par joueur pour les badges de fin : refus, gages, votes…
  /// Structure : statistique → identifiant joueur → valeur.
  final Map<String, Map<String, int>> stats = <String, Map<String, int>>{};

  /// Appelé à chaque changement : sert à sauvegarder la partie en cours.
  VoidCallback? onChanged;

  void touch() => onChanged?.call();

  int statOf(String key, String playerId) => stats[key]?[playerId] ?? 0;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'startedAt': startedAt.millisecondsSinceEpoch,
        'sips': sips,
        'turn': turn,
        'playerCursor': playerCursor,
        'stats': stats,
      };

  factory SessionScore.fromJson(Map<String, dynamic> json) {
    final SessionScore score = SessionScore(
      startedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['startedAt'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      ),
    );
    Map<String, int> ints(Object? raw) => raw is Map
        ? <String, int>{
            for (final MapEntry<dynamic, dynamic> e in raw.entries)
              if (e.value is num) e.key.toString(): (e.value as num).toInt(),
          }
        : <String, int>{};
    score.sips.addAll(ints(json['sips']));
    score.turn = (json['turn'] as num?)?.toInt() ?? 0;
    score.playerCursor = (json['playerCursor'] as num?)?.toInt() ?? 0;
    final Object? rawStats = json['stats'];
    if (rawStats is Map) {
      for (final MapEntry<dynamic, dynamic> e in rawStats.entries) {
        score.stats[e.key.toString()] = ints(e.value);
      }
    }
    return score;
  }
}

/// Clés des statistiques de badges.
abstract final class Stat {
  static const String refus = 'refus';
  static const String gage = 'gage';
  static const String verite = 'verite';
  static const String redraw = 'redraw';
  static const String jamais = 'jamais';
  static const String designe = 'designe';
  static const String minorite = 'minorite';
  static const String majorite = 'majorite';
  static const String evenement = 'evenement';
  static const String sportif = 'sportif';
}

/// Moteur de partie, partagé par les quatre modes.
///
/// Responsabilités : ordre de passage des joueurs, file de cartes sans
/// répétition, comptage des gorgées et plafonnement.
///
/// **Anti-répétition entre parties** : la session reçoit les identifiants des
/// cartes déjà vues lors des parties précédentes. Les cartes inédites sont
/// tirées en priorité ; quand tout le paquet a été vu, un nouveau cycle
/// commence et l'historique de ces cartes est oublié.
///
/// Un `GameSession` naît avec l'écran de jeu et meurt avec lui : seul
/// l'historique des cartes vues est persisté, via [onSeen] et [onForget].
class GameSession extends ChangeNotifier {
  GameSession({
    required this.players,
    required this.intensity,
    required this.rules,
    required List<Prompt> prompts,
    required this.maxGorgeesParTour,
    Set<String>? seenIds,
    this.onSeen,
    this.onForget,
    SessionScore? score,
    int? seed,
  })  : _random = math.Random(seed),
        _pool = List<Prompt>.from(prompts),
        _seen = <String>{...?seenIds},
        _score = score ?? SessionScore() {
    _reshuffle();
  }

  final List<Player> players;
  final Intensity intensity;
  final GameRules rules;
  final int maxGorgeesParTour;

  /// Score de la soirée, éventuellement partagé entre plusieurs jeux.
  final SessionScore _score;
  SessionScore get score => _score;

  DateTime get startedAt => _score.startedAt;

  // --- Multi-jeu -----------------------------------------------------------

  /// Défini uniquement en multi-jeu : appelé à la fin de chaque manche pour
  /// passer à un autre jeu tiré au hasard.
  VoidCallback? onRoundEnd;

  /// Derniers gages à afficher (mode « Je ne bois pas »). L'écran de jeu
  /// les présente puis remet la valeur à `null`.
  final ValueNotifier<List<GageNotice>?> gages =
      ValueNotifier<List<GageNotice>?>(null);

  /// Convertit les gorgées des joueurs qui ne boivent pas en gages.
  void _gagesFor(Iterable<Player> targets, int sips) {
    final List<GageNotice> notices = <GageNotice>[
      for (final Player p in targets)
        if (p.noDrink)
          GageNotice(player: p, sips: sips, gage: SoberGages.forSips(sips)),
    ];
    if (notices.isEmpty) return;
    for (final GageNotice n in notices) {
      bump(n.player, Stat.sportif);
    }
    gages.value = <GageNotice>[...?gages.value, ...notices];
  }

  @override
  void dispose() {
    gages.dispose();
    super.dispose();
  }

  /// Hors multi-jeu : appelé quand une manche se termine (carte suivante,
  /// ou tour suivant pour Action ou Vérité). Sert aux cartes Événement.
  VoidCallback? onRoundComplete;

  /// Une carte a été tirée et la manche est en cours.
  bool _roundOpen = false;

  /// La carte de la manche a déjà été tirée par le multi-jeu : le premier
  /// appel à [next] de l'écran est absorbé.
  bool _absorbNext = false;

  /// Tire la carte de la manche avant l'affichage de l'écran (multi-jeu),
  /// pour qu'aucune ancienne carte n'apparaisse au changement de jeu.
  void prepareRound() {
    _roundOpen = false;
    _absorbNext = false;
    next();
    _absorbNext = true;
  }

  /// Appelé à chaque carte tirée, pour la persister comme « vue ».
  final void Function(String id)? onSeen;

  /// Appelé quand un cycle complet est terminé : ces cartes redeviennent
  /// inédites.
  final void Function(Iterable<String> ids)? onForget;

  final math.Random _random;

  /// Réserve complète de cartes disponibles pour cette partie.
  final List<Prompt> _pool;

  /// Cartes déjà vues, cette partie comprise.
  final Set<String> _seen;

  /// File courante. Régénérée quand elle est épuisée : aucune carte
  /// ne se répète tant que toutes n'ont pas été vues.
  List<Prompt> _queue = <Prompt>[];

  Prompt? _current;

  /// Cartes tirées par cette session (hors cartes absorbées).
  int _draws = 0;

  int get _turn => _score.turn;
  set _turn(int value) => _score.turn = value;

  int get _playerCursor => _score.playerCursor;
  set _playerCursor(int value) => _score.playerCursor = value;

  /// Gorgées annoncées par joueur, pour le récapitulatif de fin.
  Map<String, int> get _sips => _score.sips;

  // --- Lecture -------------------------------------------------------------

  Prompt? get current => _current;
  int get turn => _turn;
  bool get isEmpty => _pool.isEmpty;
  int get poolSize => _pool.length;

  /// Nombre de cartes déjà vues dans le cycle en cours.
  int get seenInCycle => _pool.length - _queue.length;

  Player? get currentPlayer =>
      players.isEmpty ? null : players[_playerCursor % players.length];

  Player? get nextPlayer =>
      players.isEmpty ? null : players[(_playerCursor + 1) % players.length];

  Duration get elapsed => DateTime.now().difference(startedAt);

  Map<String, int> get sips => Map<String, int>.unmodifiable(_sips);

  int sipsOf(Player player) => _sips[player.id] ?? 0;

  int get totalSips =>
      _sips.values.fold<int>(0, (int sum, int value) => sum + value);

  // --- Cartes --------------------------------------------------------------

  /// Construit la file : cartes déjà vues au début, inédites à la fin.
  /// `removeLast` tirant depuis la fin, les inédites passent toujours
  /// d'abord.
  void _reshuffle() {
    List<Prompt> fresh =
        _pool.where((Prompt p) => !_seen.contains(p.id)).toList();

    if (fresh.isEmpty && _pool.isNotEmpty) {
      // Tout le paquet a déjà été vu : nouveau cycle.
      _forget(_pool);
      fresh = List<Prompt>.from(_pool);
    }

    final List<Prompt> stale = _pool
        .where((Prompt p) => _seen.contains(p.id))
        .toList()
      ..shuffle(_random);
    fresh.shuffle(_random);

    _queue = <Prompt>[...stale, ...fresh];
  }

  void _markSeen(Prompt prompt) {
    _seen.add(prompt.id);
    onSeen?.call(prompt.id);
  }

  void _forget(Iterable<Prompt> cards) {
    final List<String> ids = cards.map((Prompt p) => p.id).toList();
    if (ids.isEmpty) return;
    _seen.removeAll(ids);
    onForget?.call(ids);
  }

  /// Tire la carte suivante et passe au joueur suivant.
  Prompt? next() {
    // Multi-jeu : carte déjà tirée avant l'affichage de l'écran.
    if (_absorbNext) {
      _absorbNext = false;
      return _current;
    }
    // Multi-jeu : fin de manche, le jeu change.
    if (onRoundEnd != null && _roundOpen) {
      _roundOpen = false;
      onRoundEnd!.call();
      return null;
    }
    if (_pool.isEmpty) return null;
    if (_queue.isEmpty) _reshuffle();
    final Prompt picked = _queue.removeLast();
    _current = picked;
    _markSeen(picked);
    _turn++;
    _playerCursor++;
    _roundOpen = true;
    notifyListeners();
    _score.touch();
    // Une carte suivante clôt la manche précédente.
    _draws++;
    if (_draws > 1) onRoundComplete?.call();
    return picked;
  }

  /// Tire une carte parmi un sous-ensemble, **sans** changer de joueur.
  /// Utilisé par « Action ou Vérité » où le tirage suit le choix du joueur.
  Prompt? drawWhere(bool Function(Prompt) test) {
    List<Prompt> matching = _queue.where(test).toList();

    // Si la file courante n'a plus ce type de carte, on la régénère pour
    // éviter de bloquer la partie.
    if (matching.isEmpty) {
      _reshuffle();
      matching = _queue.where(test).toList();
    }
    if (matching.isEmpty) return null;

    // Priorité aux cartes inédites de ce type.
    List<Prompt> candidates =
        matching.where((Prompt p) => !_seen.contains(p.id)).toList();
    if (candidates.isEmpty) {
      // Toutes les cartes de ce type ont été vues : nouveau cycle pour ce
      // type uniquement, l'autre type garde son historique.
      _forget(_pool.where(test));
      candidates = matching;
    }

    final Prompt picked = candidates[_random.nextInt(candidates.length)];
    _queue.remove(picked);
    _current = picked;
    _markSeen(picked);
    notifyListeners();
    return picked;
  }

  /// Passe au joueur suivant sans tirer de carte.
  void advancePlayer() {
    _playerCursor++;
    _turn++;
    notifyListeners();
    _score.touch();
    // Multi-jeu : un tour d'Action ou Vérité termine la manche.
    if (onRoundEnd != null) {
      onRoundEnd!.call();
    } else {
      onRoundComplete?.call();
    }
  }

  // --- Statistiques de badges ----------------------------------------------

  void bump(Player? player, String stat, [int amount = 1]) {
    if (player == null || amount == 0) return;
    final Map<String, int> map =
        _score.stats.putIfAbsent(stat, () => <String, int>{});
    map[player.id] = (map[player.id] ?? 0) + amount;
    _score.touch();
  }

  void bumpAll(Iterable<Player> targets, String stat, [int amount = 1]) {
    for (final Player p in targets) {
      bump(p, stat, amount);
    }
  }

  int statOf(Player player, String stat) => _score.statOf(stat, player.id);

  // --- Joueurs -------------------------------------------------------------

  Player? randomPlayer() {
    if (players.isEmpty) return null;
    return players[_random.nextInt(players.length)];
  }

  // --- Sanctions -----------------------------------------------------------

  /// Nombre de gorgées effectivement annonçable, toujours plafonné.
  int cappedSips(int requested) =>
      requested.clamp(0, math.max(0, maxGorgeesParTour)).toInt();

  void recordSips(Player? player, int amount) {
    final int sips = cappedSips(amount);
    if (player == null || sips == 0) return;
    _sips[player.id] = (_sips[player.id] ?? 0) + sips;
    _gagesFor(<Player>[player], sips);
    notifyListeners();
    _score.touch();
  }

  /// Répartit une sanction sur plusieurs joueurs à la fois.
  void recordSipsForAll(Iterable<Player> targets, int amount) {
    final int sips = cappedSips(amount);
    if (sips == 0) return;
    bool changed = false;
    for (final Player p in targets) {
      _sips[p.id] = (_sips[p.id] ?? 0) + sips;
      changed = true;
    }
    if (changed) {
      _gagesFor(targets, sips);
      notifyListeners();
      _score.touch();
    }
  }

  /// Formule la sanction affichée, toujours plafonnée.
  String sanctionLabel(int gorgees) {
    final int capped = cappedSips(gorgees);
    return capped == 1 ? '1 gorgée' : '$capped gorgées';
  }

  // --- Statistiques de fin -------------------------------------------------

  /// Joueur ayant le plus bu. `null` si personne n'a été sanctionné.
  Player? get thirstiest {
    if (_sips.isEmpty) return null;
    Player? best;
    int bestValue = 0;
    for (final Player p in players) {
      final int value = sipsOf(p);
      if (value > bestValue) {
        bestValue = value;
        best = p;
      }
    }
    return best;
  }

  /// Joueur le plus épargné.
  Player? get soberest {
    if (players.isEmpty) return null;
    final List<Player> sorted = List<Player>.from(players)
      ..sort((Player a, Player b) => sipsOf(a).compareTo(sipsOf(b)));
    return sorted.first;
  }
}



