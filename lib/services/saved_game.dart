import '../models/enums.dart';
import '../models/player.dart';
import 'app_state.dart';
import 'game_session.dart';

/// Instantané d'une partie en cours, sauvegardé à chaque action de jeu.
///
/// Si l'application est fermée (appel, verrouillage, plantage), la partie
/// peut être reprise au lancement suivant avec ses gorgées, ses tours et
/// ses statistiques de badges.
class SavedGame {
  const SavedGame({
    required this.multi,
    required this.modes,
    required this.playerIds,
    required this.savedAt,
    required this.score,
  });

  final bool multi;
  final List<GameModeId> modes;
  final List<String> playerIds;
  final DateTime savedAt;
  final Map<String, dynamic> score;

  /// Au-delà, la soirée est finie : on ne propose plus la reprise.
  static const Duration maxAge = Duration(hours: 24);

  int get turn => (score['turn'] as num?)?.toInt() ?? 0;

  bool get isFresh => DateTime.now().difference(savedAt) < maxAge;

  SessionScore restoreScore() => SessionScore.fromJson(score);

  /// Joueurs de la partie, retrouvés dans le répertoire (dans l'ordre).
  List<Player> playersFrom(List<Player> roster) => <Player>[
        for (final String id in playerIds)
          ...roster.where((Player p) => p.id == id),
      ];

  Map<String, dynamic> toJson() => <String, dynamic>{
        'v': 1,
        'multi': multi,
        'modes': modes.map((GameModeId m) => m.slug).toList(),
        'players': playerIds,
        'savedAt': savedAt.millisecondsSinceEpoch,
        'score': score,
      };

  static SavedGame? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    try {
      final List<GameModeId> modes = <GameModeId>[
        for (final Object? slug in (json['modes'] as List<dynamic>? ?? const <dynamic>[]))
          ...GameModeId.values.where((GameModeId m) => m.slug == slug),
      ];
      final Object? score = json['score'];
      if (modes.isEmpty || score is! Map<String, dynamic>) return null;
      return SavedGame(
        multi: json['multi'] as bool? ?? false,
        modes: modes,
        playerIds: (json['players'] as List<dynamic>? ?? const <dynamic>[])
            .map((Object? e) => e.toString())
            .toList(),
        savedAt: DateTime.fromMillisecondsSinceEpoch(
          (json['savedAt'] as num?)?.toInt() ?? 0,
        ),
        score: score,
      );
    } on Object {
      return null;
    }
  }

  /// Branche la sauvegarde automatique sur le score d'une partie.
  static void attach(
    AppState state,
    SessionScore score, {
    required bool multi,
    required List<GameModeId> modes,
    required List<Player> players,
  }) {
    final List<String> ids = players.map((Player p) => p.id).toList();
    score.onChanged = () => state.saveGame(
          SavedGame(
            multi: multi,
            modes: modes,
            playerIds: ids,
            savedAt: DateTime.now(),
            score: score.toJson(),
          ).toJson(),
        );
    score.touch();
  }
}
