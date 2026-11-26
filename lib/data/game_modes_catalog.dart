import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../models/game_mode.dart';
import '../theme/app_theme.dart';

/// Catalogue des modes de jeu.
/// Ordre = ordre d'affichage sur l'accueil.
const List<GameMode> kGameModes = <GameMode>[
  GameMode(
    id: GameModeId.actionOuVerite,
    title: 'Action ou Vérité',
    tagline: 'Choisis ton camp',
    rules:
        'Le joueur désigné choisit son camp : une action à exécuter, ou une '
        'vérité à avouer. Se dégonfler coûte une sanction — mais passer une '
        'carte est toujours gratuit.',
    howTo: <String>[
      'Le joueur désigné choisit Action ou Vérité',
      'La carte se retourne et révèle son contenu',
      'Le groupe valide, ou le joueur se dégonfle et boit',
    ],
    icon: Icons.theater_comedy_rounded,
    color: AppColors.modeAction,
    colorAlt: AppColors.modeActionAlt,
  ),
  GameMode(
    id: GameModeId.jeNaiJamais,
    title: "Je n'ai jamais",
    tagline: 'Les confessions tombent',
    rules:
        "Une affirmation s'affiche. Tous ceux qui l'ont déjà fait boivent, et "
        "se dénoncent au passage. Personne n'est obligé de se justifier… mais "
        "tout le monde le fera.",
    howTo: <String>[
      "Lisez l'affirmation à voix haute",
      'Ceux que ça concerne se dénoncent et boivent',
      'Touchez leurs prénoms, puis passez à la suite',
    ],
    icon: Icons.visibility_off_rounded,
    color: AppColors.modeJamais,
    colorAlt: AppColors.modeJamaisAlt,
  ),
  GameMode(
    id: GameModeId.tuPreferes,
    title: 'Tu préfères',
    tagline: 'Deux options, zéro échappatoire',
    rules:
        'Un dilemme, deux réponses, aucune sortie de secours. Chacun vote, et '
        'les joueurs dans la minorité boivent. En cas d’égalité parfaite, '
        'tout le monde trinque.',
    howTo: <String>[
      'Le dilemme apparaît en deux moitiés',
      'Chaque joueur touche le camp qu’il choisit',
      'La minorité boit — la majorité savoure',
    ],
    icon: Icons.alt_route_rounded,
    color: AppColors.modePrefere,
    colorAlt: AppColors.modePrefereAlt,
  ),
  GameMode(
    id: GameModeId.quiPourrait,
    title: 'Qui pourrait…',
    tagline: 'Le groupe désigne, tu assumes',
    rules:
        'Une question tombe : « Qui pourrait… ? ». À trois, tout le monde '
        'pointe du doigt le joueur qui correspond le mieux. Le plus désigné '
        'boit — en cas d’égalité, tous les ex æquo trinquent.',
    howTo: <String>[
      'Lisez la question à voix haute',
      'À trois, chacun pointe un joueur du doigt',
      'Comptez les votes : le plus désigné boit',
    ],
    icon: Icons.person_search_rounded,
    // Couleurs définies ici : aucune modification de app_theme.dart requise.
    color: Color(0xFFF472B6),
    colorAlt: Color(0xFFE879F9),
    // À deux, le vote se résume à se désigner l'un l'autre.
    minPlayers: 3,
  ),
];

GameMode gameModeById(GameModeId id) =>
    kGameModes.firstWhere((GameMode m) => m.id == id);
