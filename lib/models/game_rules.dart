/// Barème local des quatre jeux, figé au démarrage de chaque partie.
/// Valeurs entre 0 et 5 : 0 permet de jouer sans gorgées.
class GameRules {
  const GameRules({
    this.actionRefusal = 2,
    this.actionRedraw = 1,
    this.jamaisConcerned = 1,
    this.prefereMinority = 2,
    this.quiDesigne = 2,
  });

  static const int limit = 5;

  final int actionRefusal;
  final int actionRedraw;
  final int jamaisConcerned;
  final int prefereMinority;

  /// « Qui pourrait… » : gorgées du joueur le plus désigné.
  final int quiDesigne;

  int get highest => <int>[
        actionRefusal,
        actionRedraw,
        jamaisConcerned,
        prefereMinority,
        quiDesigne,
      ].reduce((int a, int b) => a > b ? a : b);

  GameRules copyWith({
    int? actionRefusal,
    int? actionRedraw,
    int? jamaisConcerned,
    int? prefereMinority,
    int? quiDesigne,
  }) =>
      GameRules(
        actionRefusal: actionRefusal ?? this.actionRefusal,
        actionRedraw: actionRedraw ?? this.actionRedraw,
        jamaisConcerned: jamaisConcerned ?? this.jamaisConcerned,
        prefereMinority: prefereMinority ?? this.prefereMinority,
        quiDesigne: quiDesigne ?? this.quiDesigne,
      );

  Map<String, int> toJson() => <String, int>{
        'actionRefusal': actionRefusal,
        'actionRedraw': actionRedraw,
        'jamaisConcerned': jamaisConcerned,
        'prefereMinority': prefereMinority,
        'quiDesigne': quiDesigne,
      };

  factory GameRules.fromJson(Map<String, dynamic> json) {
    int read(String key, int fallback) {
      final Object? value = json[key];
      return value is int ? value.clamp(0, limit).toInt() : fallback;
    }

    return GameRules(
      actionRefusal: read('actionRefusal', 2),
      actionRedraw: read('actionRedraw', 1),
      jamaisConcerned: read('jamaisConcerned', 1),
      prefereMinority: read('prefereMinority', 2),
      // Absent des sauvegardes antérieures : valeur par défaut.
      quiDesigne: read('quiDesigne', 2),
    );
  }
}
