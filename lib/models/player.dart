import 'dart:convert';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Un joueur du répertoire.
///
/// Le répertoire est permanent : il survit aux parties et aux redémarrages.
/// [isSelected] indique la participation à la partie en cours — on ne supprime
/// donc plus quelqu'un parce qu'il manque un soir.
class Player {
  Player({
    required this.id,
    required this.name,
    required this.emoji,
    required this.colorIndex,
    this.photoBase64,
    this.isSelected = true,
    this.gamesPlayed = 0,
    this.totalSips = 0,
    this.noDrink = false,
  });

  final String id;
  String name;
  String emoji;

  /// Photo d'avatar encodée en base64, `null` si le joueur utilise un emoji.
  /// Encodée plutôt que référencée par chemin : voir AvatarPhotoService.
  String? photoBase64;

  /// Le joueur a choisi une photo plutôt qu'un emoji.
  bool get hasPhoto => photoBase64 != null && photoBase64!.isNotEmpty;

  /// Index dans [AppColors.playerPalette] — on stocke un index plutôt qu'une
  /// couleur brute pour rester cohérent si la palette évolue.
  int colorIndex;

  /// Participe à la partie en cours.
  bool isSelected;

  /// Mode « Je ne bois pas » : ses gorgées sont remplacées par des gages.
  bool noDrink;

  /// Statistiques cumulées.
  int gamesPlayed;
  int totalSips;

  Color get color =>
      AppColors.playerPalette[colorIndex % AppColors.playerPalette.length];

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'emoji': emoji,
        'colorIndex': colorIndex,
        'photoBase64': photoBase64,
        'isSelected': isSelected,
        'gamesPlayed': gamesPlayed,
        'totalSips': totalSips,
        'noDrink': noDrink,
      };

  factory Player.fromJson(Map<String, dynamic> json) => Player(
        id: json['id'] as String? ?? UniqueKey().toString(),
        name: json['name'] as String? ?? 'Joueur',
        emoji: json['emoji'] as String? ?? '🎉',
        colorIndex: (json['colorIndex'] as num?)?.toInt() ?? 0,
        // Absent des sauvegardes antérieures : `null` est la bonne valeur
        // par défaut, le joueur conserve simplement son emoji.
        photoBase64: json['photoBase64'] as String?,
        isSelected: json['isSelected'] as bool? ?? true,
        gamesPlayed: (json['gamesPlayed'] as num?)?.toInt() ?? 0,
        totalSips: (json['totalSips'] as num?)?.toInt() ?? 0,
        noDrink: json['noDrink'] as bool? ?? false,
      );

  static String encodeList(List<Player> players) =>
      jsonEncode(players.map((Player p) => p.toJson()).toList());

  static List<Player> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return <Player>[];
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return <Player>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(Player.fromJson)
          .toList();
    } on FormatException {
      // Données corrompues : on repart d'une liste vide plutôt que de planter.
      return <Player>[];
    }
  }
}