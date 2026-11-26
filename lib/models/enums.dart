import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Niveau d'intensité du contenu. Sert de filtre sur les fichiers JSON.
///
/// La sélection est **cumulative** : « Normal » inclut le contenu « Soft »,
/// « Hardcore » inclut les deux précédents, « Adulte » inclut tout.
enum Intensity {
  soft(
    'Soft',
    'Bon enfant',
    'Rien de gênant. Parfait en début de soirée ou en groupe élargi.',
    Icons.wb_sunny_outlined,
    AppColors.intensitySoft,
  ),
  normal(
    'Normal',
    'Le bon équilibre',
    'Des confidences, quelques gages. Le réglage de référence.',
    Icons.local_fire_department_outlined,
    AppColors.intensityNormal,
  ),
  hardcore(
    'Hardcore',
    'Sans filtre',
    'Questions directes, gages engageants. Entre amis proches.',
    Icons.whatshot_outlined,
    AppColors.intensityHardcore,
  ),
  adulte(
    'Adulte',
    'Explicite',
    'Contenu à caractère sexuel explicite. Entre adultes consentants.',
    Icons.favorite_outline_rounded,
    AppColors.intensityAdulte,
  );

  const Intensity(
    this.label,
    this.tagline,
    this.description,
    this.icon,
    this.color,
  );

  final String label;

  /// Formule courte affichée sous le sélecteur.
  final String tagline;

  /// Explication complète, affichée dans la feuille de réglage.
  final String description;

  final IconData icon;
  final Color color;

  /// Vrai si ce niveau autorise l'affichage d'un contenu de niveau [other].
  bool allows(Intensity other) => other.index <= index;

  /// Vrai si ce palier affiche un avertissement « 18+ ».
  bool get isExplicit => this == Intensity.adulte;

  static Intensity fromJson(String? value) => switch (value?.toLowerCase()) {
        'soft' => Intensity.soft,
        'hardcore' => Intensity.hardcore,
        'adulte' || 'adult' => Intensity.adulte,
        _ => Intensity.normal,
      };
}

/// Identifiant stable de chaque mode de jeu.
/// La valeur [slug] sert de nom de fichier JSON.
enum GameModeId {
  actionOuVerite('action_ou_verite'),
  jeNaiJamais('je_nai_jamais'),
  tuPreferes('tu_preferes'),
  quiPourrait('qui_pourrait');

  const GameModeId(this.slug);
  final String slug;
}

/// Nature d'une carte de contenu.
enum PromptKind {
  statement, // « Je n'ai jamais… », « Qui pourrait… »
  action, // un gage à exécuter
  verite, // une question à laquelle répondre
  dilemme; // « Tu préfères… » — deux options

  static PromptKind fromJson(String? value) => switch (value?.toLowerCase()) {
        'action' => PromptKind.action,
        'verite' => PromptKind.verite,
        'dilemme' => PromptKind.dilemme,
        _ => PromptKind.statement,
      };
}

/// Thème d'une carte. Un même mode mélange plusieurs ambiances, et le joueur
/// peut n'en garder que certaines.
///
/// **Nom préfixé `Game`** : `Category` seul entrerait en collision avec la
/// classe homonyme exposée par `package:flutter/foundation.dart`, réexportée
/// par `material.dart`.
enum GameCategory {
  general('Général', Icons.casino_outlined),
  amis('Entre amis', Icons.groups_outlined),
  amour('Cœur & crush', Icons.favorite_border_rounded),
  fete('Ambiance fête', Icons.celebration_outlined),
  gene('Moments gênants', Icons.sentiment_dissatisfied_outlined),
  profond('Sans filtre', Icons.psychology_outlined),
  hot('Piquant', Icons.local_fire_department_rounded);

  const GameCategory(this.label, this.icon);

  final String label;
  final IconData icon;

  static GameCategory fromJson(String? value) =>
      switch (value?.toLowerCase()) {
        'amis' => GameCategory.amis,
        'amour' => GameCategory.amour,
        'fete' => GameCategory.fete,
        'gene' => GameCategory.gene,
        'profond' => GameCategory.profond,
        'hot' => GameCategory.hot,
        _ => GameCategory.general,
      };
}
