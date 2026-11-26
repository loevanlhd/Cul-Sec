import 'package:flutter/material.dart';

import '../models/player.dart';
import 'game_session.dart';

/// Badge de soirée attribué à un joueur à la fin de la partie.
///
/// Nommé `EveningBadge` : `Badge` existe déjà dans `material.dart`.
class EveningBadge {
  const EveningBadge({
    required this.emoji,
    required this.title,
    required this.detail,
    required this.player,
    required this.color,
  });

  final String emoji;
  final String title;
  final String detail;
  final Player player;
  final Color color;
}

class _Rule {
  const _Rule(this.stat, this.emoji, this.title, this.min, this.color,
      this.detail,);

  final String stat;
  final String emoji;
  final String title;
  final int min;
  final Color color;
  final String Function(int n) detail;
}

String _fois(int n) => n > 1 ? '$n fois' : '1 fois';

final List<_Rule> _rules = <_Rule>[
  _Rule(Stat.refus, '🐔', 'Le Dégonflé', 1, const Color(0xFFFFB547),
      (int n) => n > 1 ? '$n refus' : '1 refus',),
  _Rule(Stat.gage, '🦁', 'Le Téméraire', 2, const Color(0xFFFF5C7A),
      (int n) => '$n gages relevés',),
  _Rule(Stat.verite, '😇', 'Le Sincère', 2, const Color(0xFF5CC8FF),
      (int n) => '$n vérités avouées',),
  _Rule(Stat.redraw, '🙈', 'Le Difficile', 1, const Color(0xFFB3A8FF),
      (int n) => n > 1 ? '$n cartes passées' : '1 carte passée',),
  _Rule(Stat.jamais, '📖', 'Le Vécu', 2, const Color(0xFFFF7AB6),
      (int n) => 'S’est dénoncé ${_fois(n)}',),
  _Rule(Stat.designe, '🎯', 'La Cible', 2, const Color(0xFFFF8A4C),
      (int n) => 'Désigné ${_fois(n)} par le groupe',),
  _Rule(Stat.minorite, '🐑', 'Le Mouton noir', 2, const Color(0xFF9AA0B4),
      (int n) => '${_fois(n)} dans la minorité',),
  _Rule(Stat.majorite, '🐏', 'Le Suiveur', 3, const Color(0xFFE6E1D3),
      (int n) => 'Avec la majorité ${_fois(n)}',),
  _Rule(Stat.sportif, '💪', 'Le Sportif', 2, const Color(0xFF2DD4BF),
      (int n) => '$n gages au lieu de boire',),
  _Rule(Stat.evenement, '🎲', 'Le Maudit', 2, const Color(0xFF4ADE80),
      (int n) => '$n gorgées d’Événements',),
];

/// Calcule les badges : pour chaque statistique, le joueur en tête (au-delà
/// d'un seuil). En cas d'égalité, celui qui a le plus bu l'emporte.
List<EveningBadge> computeBadges(GameSession session) {
  final List<Player> players = session.players;
  final List<EveningBadge> badges = <EveningBadge>[];
  if (players.isEmpty) return badges;

  for (final _Rule rule in _rules) {
    Player? best;
    int bestValue = 0;
    for (final Player p in players) {
      final int v = session.statOf(p, rule.stat);
      if (v > bestValue ||
          (v == bestValue &&
              v > 0 &&
              best != null &&
              session.sipsOf(p) > session.sipsOf(best))) {
        best = p;
        bestValue = v;
      }
    }
    if (best != null && bestValue >= rule.min) {
      badges.add(EveningBadge(
        emoji: rule.emoji,
        title: rule.title,
        detail: rule.detail(bestValue),
        player: best,
        color: rule.color,
      ),);
    }
  }

  // Le plus sobre : seulement si la soirée a vraiment eu lieu.
  final Player? sober = session.soberest;
  final Player? leader = session.thirstiest;
  if (sober != null &&
      leader != null &&
      players.length >= 3 &&
      session.turn >= 5 &&
      session.sipsOf(sober) < session.sipsOf(leader)) {
    final int n = session.sipsOf(sober);
    badges.add(EveningBadge(
      emoji: '🧊',
      title: 'Le Sobre',
      detail: n <= 1 ? '$n gorgée seulement' : '$n gorgées seulement',
      player: sober,
      color: const Color(0xFF5CC8FF),
    ),);
  }
  return badges;
}

