import 'package:cul_sec/models/enums.dart';
import 'package:cul_sec/models/prompt.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests unitaires du moteur de contenu.
///
/// On ne teste pas le rendu des écrans : ils dépendent de
/// `shared_preferences` et `google_fonts`, qui demandent un environnement
/// initialisé. On vérifie la logique métier, qui est pure.
void main() {
  group('Filtre d’intensité', () {
    test('Chaque palier inclut les précédents', () {
      expect(Intensity.normal.allows(Intensity.soft), isTrue);
      expect(Intensity.normal.allows(Intensity.hardcore), isFalse);
      expect(Intensity.hardcore.allows(Intensity.normal), isTrue);
      expect(Intensity.hardcore.allows(Intensity.adulte), isFalse);
    });

    test('Adulte inclut tout', () {
      for (final Intensity i in Intensity.values) {
        expect(Intensity.adulte.allows(i), isTrue);
      }
    });

    test('Seul Adulte est marqué explicite', () {
      expect(Intensity.adulte.isExplicit, isTrue);
      expect(Intensity.hardcore.isExplicit, isFalse);
    });
  });

  group('Désérialisation du contenu', () {
    PromptPack build() => PromptPack.fromJson(<String, dynamic>{
          'mode': 'test',
          'version': 1,
          'maxGorgeesParTour': 2,
          'entrees': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'a',
              'texte': 'Carte douce',
              'intensite': 'soft',
              'categorie': 'amis',
              'gorgees': 1,
            },
            <String, dynamic>{
              'id': 'b',
              'texte': 'Carte explicite',
              'intensite': 'adulte',
              'categorie': 'hot',
              'gorgees': 5,
            },
          ],
        });

    test('Le filtre d’intensité fonctionne', () {
      final PromptPack pack = build();
      expect(pack.prompts.length, 2);
      expect(pack.filtered(Intensity.soft).length, 1);
      expect(pack.filtered(Intensity.adulte).length, 2);
    });

    test('Le filtre de thèmes fonctionne', () {
      final PromptPack pack = build();
      expect(
        pack.filtered(
          Intensity.adulte,
          categories: <GameCategory>{GameCategory.hot},
        ).length,
        1,
      );
      // Un ensemble vide signifie « tous les thèmes ».
      expect(
        pack.filtered(Intensity.adulte, categories: <GameCategory>{}).length,
        2,
      );
    });

    test('Les thèmes disponibles sont détectés', () {
      expect(
        build().availableCategories,
        containsAll(<GameCategory>[GameCategory.amis, GameCategory.hot]),
      );
    });

    test('Le plafond de gorgées est respecté', () {
      final PromptPack pack = build();
      expect(pack.maxGorgeesParTour, 2);
    });

    test('Les entrées sans texte ni identifiant sont ignorées', () {
      final PromptPack pack = PromptPack.fromJson(<String, dynamic>{
        'mode': 'test',
        'entrees': <Map<String, dynamic>>[
          <String, dynamic>{'id': '', 'texte': 'Sans identifiant'},
          <String, dynamic>{'id': 'x', 'texte': ''},
          <String, dynamic>{'id': 'ok', 'texte': 'Valide'},
        ],
      });

      expect(pack.prompts.length, 1);
      expect(pack.prompts.first.id, 'ok');
    });
  });
}
