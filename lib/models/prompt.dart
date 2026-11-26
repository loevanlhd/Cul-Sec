import 'enums.dart';

/// Une carte de contenu, quel que soit le mode.
///
/// Modèle volontairement large plutôt que trois sous-classes : les modes
/// partagent le même moteur de tirage, les champs spécifiques restent
/// optionnels. Ajouter du contenu ne demande qu'une entrée JSON.
class Prompt {
  const Prompt({
    required this.id,
    required this.text,
    required this.kind,
    required this.intensity,
    this.category = GameCategory.general,
    this.gorgees = 1,
    this.options = const <String>[],
  });

  /// Préfixe des identifiants de cartes écrites par le groupe. Il garantit
  /// qu'une carte perso ne collisionne jamais avec une carte du JSON.
  static const String customPrefix = 'perso_';

  final String id;
  final String text;
  final PromptKind kind;
  final Intensity intensity;
  final GameCategory category;

  /// Toujours plafonné par `maxGorgeesParTour` (voir [PromptPack]).
  final int gorgees;

  /// Les deux options d'un dilemme.
  final List<String> options;

  bool get isDilemme => kind == PromptKind.dilemme && options.length > 1;

  /// Carte écrite par le groupe, et non livrée avec l'application.
  bool get isCustom => id.startsWith(customPrefix);

  factory Prompt.fromJson(Map<String, dynamic> json) {
    final Object? rawOptions = json['options'];
    return Prompt(
      id: json['id'] as String? ?? '',
      text: json['texte'] as String? ?? '',
      kind: PromptKind.fromJson(json['type'] as String?),
      intensity: Intensity.fromJson(json['intensite'] as String?),
      category: GameCategory.fromJson(json['categorie'] as String?),
      gorgees: (json['gorgees'] as num?)?.toInt() ?? 1,
      options: rawOptions is List
          ? rawOptions.map((Object? e) => e.toString()).toList()
          : const <String>[],
    );
  }

  /// Format identique à celui des fichiers JSON : une carte perso exportée
  /// pourrait être collée telle quelle dans `assets/data/`.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'texte': text,
        'type': kind.name,
        'intensite': intensity.name,
        'categorie': category.name,
        'gorgees': gorgees,
        if (options.isNotEmpty) 'options': options,
      };
}

/// Contenu complet d'un mode, tel que stocké dans `assets/data/<slug>.json`.
class PromptPack {
  const PromptPack({
    required this.modeSlug,
    required this.version,
    required this.maxGorgeesParTour,
    required this.prompts,
  });

  final String modeSlug;
  final int version;

  /// Garde-fou porté par le contenu, pas par le code.
  final int maxGorgeesParTour;

  final List<Prompt> prompts;

  factory PromptPack.fromJson(Map<String, dynamic> json) {
    final Object? raw = json['entrees'];
    final List<Prompt> parsed = raw is List
        ? raw
            .whereType<Map<String, dynamic>>()
            .map(Prompt.fromJson)
            .where((Prompt p) => p.id.isNotEmpty && p.text.isNotEmpty)
            .toList(growable: false)
        : <Prompt>[];

    return PromptPack(
      modeSlug: json['mode'] as String? ?? '',
      version: (json['version'] as num?)?.toInt() ?? 1,
      maxGorgeesParTour: (json['maxGorgeesParTour'] as num?)?.toInt() ?? 3,
      prompts: parsed,
    );
  }

  /// Sous-ensemble compatible avec le niveau d'intensité et les thèmes
  /// retenus. Un ensemble de thèmes vide signifie « tous ».
  ///
  /// La liste renvoyée est **non-growable** : les appelants n'ont aucune
  /// raison d'y ajouter quoi que ce soit, et Flutter évite ainsi une
  /// réallocation lors du premier `add`.
  List<Prompt> filtered(Intensity max, {Set<GameCategory>? categories}) {
    final bool allCategories =
        categories == null || categories.isEmpty;
    return prompts
        .where((Prompt p) {
          if (!max.allows(p.intensity)) return false;
          if (allCategories) return true;
          return categories.contains(p.category);
        })
        .toList(growable: false);
  }

  /// Thèmes réellement présents dans ce pack, pour n'afficher que des
  /// filtres utiles.
  List<GameCategory> get availableCategories {
    final Set<GameCategory> found =
        prompts.map((Prompt p) => p.category).toSet();
    return GameCategory.values.where(found.contains).toList(growable: false);
  }

  /// Nombre de cartes disponibles à un niveau donné.
  int countAt(Intensity max) =>
      prompts.where((Prompt p) => max.allows(p.intensity)).length;
}