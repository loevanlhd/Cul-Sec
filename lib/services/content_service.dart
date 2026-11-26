import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;

import '../models/enums.dart';
import '../models/prompt.dart';

/// Charge et met en cache le contenu des jeux.
///
/// Les fichiers vivent dans `assets/data/<slug>.json` et ne sont jamais
/// référencés en dur ailleurs : enrichir le contenu ne demande aucune
/// modification du code Dart.
///
/// Les cartes personnalisées sont injectées par `AppState` via
/// [setCustomCards] et fusionnées ici : tous les écrans (compteurs, filtres,
/// tirage) les voient sans connaître leur existence.
///
/// **Parsing hors thread UI** : `action_ou_verite.json` contient ~500 entrées.
/// Le désérialiser sur le thread principal bloque le premier rendu pendant
/// plusieurs centaines de millisecondes sur un appareil de milieu de gamme.
/// On délègue donc à un isolate via `compute`.
class ContentService {
  ContentService._();

  static final ContentService instance = ContentService._();

  /// Packs livrés avec l'application, lus une fois.
  final Map<String, PromptPack> _base = <String, PromptPack>{};

  /// Packs fusionnés (livrés + perso), recalculés quand les cartes perso
  /// changent.
  final Map<String, PromptPack> _merged = <String, PromptPack>{};

  Map<String, List<Prompt>> _custom = <String, List<Prompt>>{};

  /// Charge le pack d'un mode, cartes perso incluses. Le fichier n'est lu
  /// qu'une fois par session.
  Future<PromptPack> load(GameModeId id) async {
    final String slug = id.slug;
    if (!_base.containsKey(slug)) {
      final String raw = await rootBundle.loadString('assets/data/$slug.json');
      // Le parsing se fait hors thread UI. Pour ~500 entrées, c'est la
      // différence entre un démarrage instantané et un à-coup visible.
      _base[slug] = await compute(_parsePack, raw);
    }
    return _mergedFor(slug)!;
  }

  /// Pack déjà chargé, s'il existe. Permet d'afficher un compteur de cartes
  /// sans repayer la lecture du fichier.
  PromptPack? cached(GameModeId id) => _mergedFor(id.slug);

  PromptPack? _mergedFor(String slug) {
    final PromptPack? base = _base[slug];
    if (base == null) return null;

    final List<Prompt> extra = _custom[slug] ?? const <Prompt>[];
    if (extra.isEmpty) return base;

    return _merged.putIfAbsent(
      slug,
      () => PromptPack(
        modeSlug: base.modeSlug,
        version: base.version,
        maxGorgeesParTour: base.maxGorgeesParTour,
        prompts: List<Prompt>.unmodifiable(
          <Prompt>[...base.prompts, ...extra],
        ),
      ),
    );
  }

  /// Remplace l'ensemble des cartes perso, indexées par slug de mode.
  void setCustomCards(Map<String, List<Prompt>> cards) {
    _custom = <String, List<Prompt>>{
      for (final MapEntry<String, List<Prompt>> e in cards.entries)
        e.key: List<Prompt>.unmodifiable(e.value),
    };
    _merged.clear();
  }

  /// Précharge tous les modes — appelé au démarrage pour que les compteurs
  /// de l'accueil soient disponibles immédiatement.
  Future<void> preloadAll() async {
    // En parallèle : chaque JSON est parsé dans son propre isolate, on ne
    // paie pas la somme des temps de chargement.
    await Future.wait<void>(<Future<void>>[
      for (final GameModeId id in GameModeId.values) _tryLoad(id),
    ]);
  }

  Future<void> _tryLoad(GameModeId id) async {
    try {
      await load(id);
    } on Exception {
      // Un pack manquant ne doit pas empêcher l'application de démarrer :
      // l'écran de jeu affichera son propre message d'erreur.
    }
  }

  void clearCache() {
    _base.clear();
    _merged.clear();
  }
}

/// Point d'entrée de l'isolate : top-level pour être transmissible à `compute`.
PromptPack _parsePack(String raw) {
  final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
  return PromptPack.fromJson(json);
}