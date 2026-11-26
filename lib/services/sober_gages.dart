import 'dart:math' as math;

/// Gages des joueurs en mode « Je ne bois pas ».
///
/// Chaque gorgée due est convertie en gage, d'autant plus costaud que la
/// sanction est lourde. Les gages restent faisables autour d'une table, sans
/// matériel ni danger.
class SoberGages {
  SoberGages._();

  static final math.Random _random = math.Random();

  /// Gages par niveau : 1 gorgée, 2 gorgées, 3 gorgées et plus.
  static const List<List<String>> _byLevel = <List<String>>[
    <String>[
      'Fais 5 squats.',
      'Fais 5 pompes (sur les genoux, ça compte).',
      'Imite un animal choisi par ton voisin de droite.',
      'Parle avec un accent jusqu’au prochain tour.',
      'Fais un compliment sincère à chaque joueur.',
      'Raconte une blague. Si personne ne rit, refais-en une.',
      'Garde les bras levés pendant 20 secondes.',
      'Fais ta meilleure grimace pour une photo de groupe.',
      'Bois un verre d’eau cul sec.',
    ],
    <String>[
      'Fais 10 squats.',
      'Fais 10 pompes (sur les genoux, ça compte).',
      'Tiens la chaise (dos au mur) pendant 30 secondes.',
      'Chante le refrain d’une chanson choisie par le groupe.',
      'Danse 20 secondes sur une musique choisie par le groupe.',
      'Laisse le groupe écrire ton prochain statut… à ne pas publier.',
      'Parle en rimes jusqu’à ton prochain tour.',
      'Fais 15 jumping jacks.',
    ],
    <String>[
      'Fais 15 squats.',
      'Fais 15 pompes (sur les genoux, ça compte).',
      'Gainage : 45 secondes de planche.',
      'Fais 25 jumping jacks.',
      'Chante une chanson entière choisie par le groupe.',
      'Danse 45 secondes sans t’arrêter, avec conviction.',
      'Imite chaque joueur, un par un.',
      'Tu es le serveur officiel de la table jusqu’au prochain tour.',
    ],
  ];

  /// Gage correspondant à [sips] gorgées.
  static String forSips(int sips) {
    final int level = sips.clamp(1, 3).toInt() - 1;
    final List<String> pool = _byLevel[level];
    return pool[_random.nextInt(pool.length)];
  }
}
