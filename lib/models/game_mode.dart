import 'package:flutter/material.dart';

import 'enums.dart';

/// Métadonnées d'affichage d'un mode de jeu.
/// Aucune logique ici : uniquement ce qu'il faut pour peindre la carte
/// et présenter les règles.
class GameMode {
  const GameMode({
    required this.id,
    required this.title,
    required this.tagline,
    required this.rules,
    required this.howTo,
    required this.icon,
    required this.color,
    required this.colorAlt,
    this.minPlayers = 2,
  });

  final GameModeId id;
  final String title;

  /// Phrase courte affichée sous le titre.
  final String tagline;

  /// Règle du jeu, affichée avant la partie.
  final String rules;

  /// Déroulé en trois étapes, affiché dans la feuille de présentation.
  final List<String> howTo;

  final IconData icon;

  /// Teinte principale du mode, reprise partout dans son parcours.
  final Color color;

  /// Teinte secondaire, pour les dégradés.
  final Color colorAlt;

  final int minPlayers;

  String get slug => id.slug;
}
