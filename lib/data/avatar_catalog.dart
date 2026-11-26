import 'dart:math' as math;

/// Catalogue des avatars : mascottes maison Cul Sec par famille, puis emojis.
///
/// **Stockage** : une mascotte est enregistrée dans le champ `emoji` du
/// joueur sous la forme `cs:<id>` (ex. `cs:mousse`). Aucun changement du
/// modèle `Player` ni des sauvegardes.
///
/// **Images** : fichiers WebP `assets/avatars/avatar_<id>.webp` (même
/// identifiant), déclarés dans `pubspec.yaml` via `assets/avatars/`.
///
/// **Unicité** : un avatar ne peut appartenir qu'à un seul joueur. Le
/// sélecteur verrouille ceux déjà pris, et le tirage au hasard les évite.
class AvatarCatalog {
  const AvatarCatalog._();

  /// Préfixe d'une mascotte dans le champ `emoji`.
  static const String mascotPrefix = 'cs:';

  /// Mascottes maison, par famille : identifiant → nom affiché.
  static const Map<String, Map<String, String>> mascotGroups =
      <String, Map<String, String>>{
    'ALCOOLS': <String, String>{
      'mousse': 'Blonde',
      'biere_brune': 'Brune',
      'biere_blanche': 'Bière blanche',
      'ipa': 'IPA',
      'panache': 'Panaché',
      'monaco': 'Monaco',
      'picon': 'Picon bière',
      'desperados': 'Desperados',
      'vin': 'Vin rouge',
      'vin_blanc': 'Vin blanc',
      'rose': 'Rosé',
      'bulle': 'Champagne',
      'kir': 'Kir',
      'lillet': 'Lillet',
      'cidre': 'Cidre',
      'chouchen': 'Chouchen',
      'porto': 'Porto',
      'ricard': 'Ricard',
      'pastis': 'Pastis',
      'suze': 'Suze',
      'vodka': 'Vodka',
      'whisky': 'Whisky',
      'rhum': 'Rhum',
      'malibu': 'Malibu',
      'gin': 'Gin tonic',
      'tequila': 'Tequila',
      'shooter': 'Shooter',
      'cognac': 'Cognac',
      'calvados': 'Calva',
      'poire': 'Poire',
      'absinthe': 'Absinthe',
      'limoncello': 'Limoncello',
      'sake': 'Saké',
      'soju': 'Soju',
      'liqueur_herbes': 'Jäger', // Compatibilité avec les anciennes sauvegardes.
      'jagermeister': 'Jägermeister',
      'creme_whisky': 'Baileys',
      'kahlua': 'Kahlúa',
      'amaretto': 'Disaronno',
      'triple_sec': 'Cointreau',
      'curacao': 'Curaçao',
      'liqueur_menthe': 'Get 27',
      'grappa': 'Grappa',
      'ouzo': 'Ouzo',
      'campari': 'Campari',
      'vermouth': 'Martini',
      'cerise': 'Cocktail',
      'cosmo': 'Cosmo',
      'margarita': 'Margarita',
      'mojito': 'Mojito',
      'spritz': 'Spritz',
      'sangria': 'Sangria',
      'blue_lagoon': 'Blue Lagoon',
      'pina_colada': 'Piña colada',
      'caipirinha': 'Caïpi',
      'bloody_mary': 'Bloody Mary',
      'punch': 'Punch',
    },
    'SOFTS': <String, String>{
      'cola': 'Coca',
      'cola_zero': 'Coca Zéro',
      'cola_cerise': 'Coca Cherry',
      'fanta': 'Fanta',
      'sprite': 'Sprite',
      'orange_pulpe': 'Orangina',
      'oasis': 'Oasis',
      'the_peche': 'Fuze Tea',
      'the_citron': 'Lipton',
      'energy': 'Red Bull',
      'monster': 'Monster',
      'tonic': 'Schweppes',
      'perrier': 'Perrier',
      'limonade': 'Limonade',
      'jus_orange': 'Jus d\'orange',
      'jus_pomme': 'Jus de pomme',
      'canette': 'Canette',
      'menthe_eau': 'Menthe à l\'eau',
      'diabolo': 'Diabolo',
      'grenadine': 'Grenadine',
      'eau_gazeuse': 'Eau pétillante',
      'ginger': 'Ginger beer',
      'milkshake': 'Milkshake',
      'smoothie': 'Smoothie',
    },
    'SOIRÉE': <String, String>{
      'citron': 'Citron',
      'glacon': 'Glaçon',
      'olive': 'Olive',
      'disco': 'Disco',
      'fetard': 'Fêtard',
      'de': 'Le Dé',
      'joker': 'Joker',
      'bouchon': 'Bouchon',
      'capsule': 'Capsule',
      'vinyle': 'Vinyle',
      'ballon': 'Ballon',
      'roi': 'Le Roi',
      'flamme': 'Flamme',
      'diablotin': 'Diablotin',
      'fantome': 'Fantôme',
      'micro': 'Micro',
      'casque': 'DJ',
      'ananas': 'Ananas',
      'pasteque': 'Pastèque',
      'pizza': 'Pizza',
      'donut': 'Donut',
      'frites': 'Frites',
      'taco': 'Taco',
      'cupcake': 'Cupcake',
      'popcorn': 'Popcorn',
      'etoile': 'Star',
      'eclair': 'Éclair',
      'coeur': 'Crush',
      'lune': 'Lune',
      'bombe': 'Bombe',
      'champignon': 'Champi',
      'cactus': 'Cactus',
      'confettis': 'Confettis',
    },
  };

  /// Toutes les mascottes, à plat : identifiant → nom affiché.
  static final Map<String, String> mascots = <String, String>{
    for (final Map<String, String> group in mascotGroups.values) ...group,
  };

  /// Valeurs à stocker dans `Player.emoji`, dans l'ordre d'affichage.
  static final List<String> mascotValues = mascots.keys
      .map((String id) => '$mascotPrefix$id')
      .toList(growable: false);

  /// Vrai si la valeur désigne une mascotte connue.
  static bool isMascot(String value) =>
      value.startsWith(mascotPrefix) && mascots.containsKey(idOf(value));

  /// Identifiant d'une mascotte (`cs:mousse` → `mousse`).
  static String idOf(String value) => value.substring(mascotPrefix.length);

  /// Valeurs `cs:<id>` d'une famille, dans l'ordre d'affichage.
  static List<String> valuesOf(Map<String, String> group) => group.keys
      .map((String id) => '$mascotPrefix$id')
      .toList(growable: false);

  /// Nom affiché d'une mascotte.
  static String nameFor(String value) => mascots[idOf(value)] ?? '';

  static final math.Random _random = math.Random();

  /// Mascotte tirée au hasard, **uniquement parmi les mascottes maison** et
  /// jamais parmi celles déjà prises ([taken]). [current] est évitée pour
  /// qu'un appui change toujours l'avatar affiché.
  static String randomMascot({
    Set<String> taken = const <String>{},
    String? current,
  }) {
    List<String> pool = mascotValues
        .where((String v) => !taken.contains(v) && v != current)
        .toList();
    // Cas extrême : toutes les mascottes sont prises.
    if (pool.isEmpty) {
      pool = mascotValues.where((String v) => !taken.contains(v)).toList();
    }
    if (pool.isEmpty) return current ?? mascotValues.first;
    return pool[_random.nextInt(pool.length)];
  }

  static const Map<String, List<String>> groups = {
    'Fete': [
      '🍻', '🥂', '🍸', '🍹', '🍾', '🎉', '🎊', '🪩', '🕺', '💃',
      '🎤', '🎧', '🎸', '🥳', '🔥', '⚡', '💥', '✨', '🌟', '🎯',
    ],
    'Animaux': [
      '🦊', '🐺', '🐻', '🐼', '🐨', '🐯', '🦁', '🐮', '🐷', '🐸',
      '🐵', '🐔', '🐧', '🦉', '🦇', '🐝', '🦋', '🐙', '🦈', '🦄',
      '🐲', '🦖', '🦔', '🐢', '🦩', '🦥', '🐿️', '🦝', '🐴', '🐳',
    ],
    'Visages': [
      '😎', '🤠', '🥸', '🤡', '👻', '👽', '🤖', '💀', '🎃', '😈',
      '🤓', '🧐', '🤪', '😜', '🥴', '🫠', '🙃', '😴', '🤯', '🫡',
      '😇', '🥶', '🥵', '🤫', '🤭', '😏', '🙈', '🙉', '🙊', '💩',
    ],
    'Personnages': [
      '🦸', '🦹', '🧙', '🧛', '🧜', '🧚', '🧞', '🥷', '👮', '👷',
      '🕵️', '👨‍🍳', '🧑‍🚀', '🧑‍🎤', '🧑‍🎨', '🤴', '👸', '🎅', '🧟', '🧌',
    ],
    'Sport & Jeux': [
      '⚽', '🏀', '🏈', '🎾', '🏐', '🥊', '🎿', '🏂', '🏄', '🚴',
      '🎮', '🕹️', '🎲', '🃏', '♠️', '♥️', '♦️', '♣️', '🎰', '🏆',
    ],
    'Objets': [
      '🚀', '🛸', '🏴‍☠️', '💣', '🧨', '🔮', '💎', '👑', '🗝️', '🧲',
      '🪄', '🎁', '🧊', '🌶️', '🍕', '🍔', '🌮', '🍩', '🧃', '☕',
    ],
    'Nature': [
      '🌵', '🌴', '🍀', '🌻', '🌹', '🌙', '☀️', '🌈', '🌊', '🌋',
      '❄️', '🍄', '🌸', '🪐', '☄️', '🪸', '🌪️', '🌞', '🍁', '🌾',
    ],
  };

  /// Liste à plat de tous les emojis disponibles.
  static List<String> get all =>
      groups.values.expand((list) => list).toList(growable: false);

  /// Avatar par défaut du n-ième joueur : toujours une mascotte maison.
  static String defaultFor(int index) =>
      mascotValues[index % mascotValues.length];
}


