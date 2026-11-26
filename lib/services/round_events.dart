import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/player.dart';
import 'game_session.dart';

/// Carte Événement prête à afficher : texte personnalisé avec les prénoms et
/// effet sur le score déjà calculé.
class RoundEvent {
  const RoundEvent({
    required this.emoji,
    required this.title,
    required this.text,
    required this.color,
    this.drinkers = const <Player>[],
    this.sips = 0,
    this.loserCandidates = const <Player>[],
    this.loserQuestion,
  });

  final String emoji;
  final String title;
  final String text;
  final Color color;

  /// Joueurs qui boivent automatiquement [sips] gorgées.
  final List<Player> drinkers;
  final int sips;

  /// Mini-jeu : le groupe désigne le perdant parmi ces joueurs, qui boit
  /// [sips] gorgées. Vide si l'événement n'a pas de perdant à désigner.
  final List<Player> loserCandidates;
  final String? loserQuestion;

  bool get needsLoser => loserCandidates.isNotEmpty;

  /// Événement purement informatif (règle, pause eau…).
  bool get isInfo => drinkers.isEmpty && !needsLoser;

  /// Enregistre l'effet de l'événement dans la partie.
  void apply(GameSession session, {Player? loser}) {
    if (drinkers.isNotEmpty && sips > 0) {
      session.recordSipsForAll(drinkers, sips);
      session.bumpAll(drinkers, Stat.evenement, session.cappedSips(sips));
    }
    if (loser != null && sips > 0) {
      session.recordSips(loser, sips);
      session.bump(loser, Stat.evenement, session.cappedSips(sips));
    }
  }
}

/// Paquet de cartes Événement : décide quand une carte tombe entre deux
/// manches et la tire au hasard, sans répéter la précédente.
class EventDeck {
  EventDeck({int? seed}) : _random = math.Random(seed);

  final math.Random _random;

  int _sinceLast = 0;
  int? _lastIndex;

  static const Color _party = Color(0xFFFFB547);
  static const Color _danger = Color(0xFFFF5C7A);
  static const Color _rule = Color(0xFF8B7BFF);
  static const Color _water = Color(0xFF5CC8FF);
  static const Color _game = Color(0xFF4ADE80);

  /// À appeler à chaque fin de manche. Jamais deux événements rapprochés :
  /// au moins 4 manches d'écart, puis une chance sur quatre, et forcément
  /// un événement au bout de 9 manches.
  bool shouldTrigger() {
    _sinceLast++;
    final bool go =
        _sinceLast >= 9 || (_sinceLast >= 4 && _random.nextInt(4) == 0);
    if (go) _sinceLast = 0;
    return go;
  }

  RoundEvent? draw(GameSession session) {
    final List<Player> players = session.players;
    if (players.length < 2) return null;

    final List<RoundEvent? Function()> builders = <RoundEvent? Function()>[
      () => RoundEvent(
            emoji: '🥂',
            title: 'Santé générale',
            text: 'Tout le monde lève son verre : 1 gorgée pour chacun !',
            color: _party,
            drinkers: players,
            sips: 1,
          ),
      () {
        final Player victim = _any(players);
        return RoundEvent(
          emoji: '🎯',
          title: 'Roulette russe',
          text: 'Le sort a parlé : ${victim.name} boit 2 gorgées.',
          color: _danger,
          drinkers: <Player>[victim],
          sips: 2,
        );
      },
      () {
        final Player? leader = session.thirstiest;
        final Player? sober = session.soberest;
        if (leader == null || sober == null || leader.id == sober.id) {
          return null;
        }
        return RoundEvent(
          emoji: '🐢',
          title: 'Rattrapage',
          text: '${sober.name} est bien trop sobre : 2 gorgées pour '
              'rattraper le retard.',
          color: _danger,
          drinkers: <Player>[sober],
          sips: 2,
        );
      },
      () {
        final Player? leader = session.thirstiest;
        if (leader == null) return null;
        return RoundEvent(
          emoji: '👑',
          title: 'Pause du leader',
          text: '${leader.name} a déjà assez donné : tous les autres '
              'boivent 1 gorgée.',
          color: _party,
          drinkers:
              players.where((Player p) => p.id != leader.id).toList(),
          sips: 1,
        );
      },
      () {
        final Player? current = session.currentPlayer;
        if (current == null || players.length < 3) return null;
        final int i = players.indexWhere((Player p) => p.id == current.id);
        if (i < 0) return null;
        final Player left = players[(i - 1 + players.length) % players.length];
        final Player right = players[(i + 1) % players.length];
        return RoundEvent(
          emoji: '🔄',
          title: 'Les voisins',
          text: '${current.name}, ${left.name} et ${right.name} trinquent '
              'ensemble : 1 gorgée chacun.',
          color: _party,
          drinkers: <Player>[current, left, right],
          sips: 1,
        );
      },
      () {
        final List<Player> duo = (List<Player>.from(players)..shuffle(_random))
            .take(2)
            .toList();
        return RoundEvent(
          emoji: '✊',
          title: 'Duel',
          text: '${duo[0].name} contre ${duo[1].name} : pierre-feuille-'
              'ciseaux en deux manches gagnantes. Le perdant boit 2 gorgées.',
          color: _game,
          sips: 2,
          loserCandidates: duo,
          loserQuestion: 'Qui a perdu le duel ?',
        );
      },
      () => RoundEvent(
            emoji: '👃',
            title: 'Le nez !',
            text: 'Le dernier à toucher son nez boit 2 gorgées. '
                'Attention… maintenant !',
            color: _game,
            sips: 2,
            loserCandidates: players,
            loserQuestion: 'Qui a été le plus lent ?',
          ),
      () {
        final Player chooser = _any(players);
        return RoundEvent(
          emoji: '🎤',
          title: 'Catégorie',
          text: '${chooser.name} choisit une catégorie (marques de bière, '
              'pays, chanteurs…). Tour de table : le premier qui sèche ou '
              'répète boit 2 gorgées.',
          color: _game,
          sips: 2,
          loserCandidates: players,
          loserQuestion: 'Qui a séché ?',
        );
      },
      () => const RoundEvent(
            emoji: '🤫',
            title: 'Nouvelle règle',
            text: 'Interdit de dire « boire » jusqu’à la prochaine carte '
                'Événement. Chaque erreur : 1 gorgée.',
            color: _rule,
          ),
      () => const RoundEvent(
            emoji: '🫵',
            title: 'Nouvelle règle',
            text: 'Interdit de pointer du doigt jusqu’à la prochaine carte '
                'Événement. Chaque erreur : 1 gorgée.',
            color: _rule,
          ),
      () => const RoundEvent(
            emoji: '🤚',
            title: 'Nouvelle règle',
            text: 'On ne boit plus que de la main gauche jusqu’à la '
                'prochaine carte Événement. Chaque erreur : 1 gorgée.',
            color: _rule,
          ),
      () => const RoundEvent(
            emoji: '💧',
            title: 'Pause hydratation',
            text: 'Tout le monde boit un grand verre d’eau. Votre lendemain '
                'vous remerciera.',
            color: _water,
          ),
    ];

    // Tirage sans répéter le précédent ; certains événements ne sont pas
    // toujours possibles (pas encore de leader, trop peu de joueurs…).
    final List<int> order = List<int>.generate(builders.length, (int i) => i)
      ..shuffle(_random);
    for (final int index in order) {
      if (index == _lastIndex) continue;
      final RoundEvent? event = builders[index]();
      if (event != null) {
        _lastIndex = index;
        return event;
      }
    }
    return null;
  }

  Player _any(List<Player> players) =>
      players[_random.nextInt(players.length)];
}
