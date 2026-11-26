import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/avatar_catalog.dart';
import '../models/player.dart';

/// Rend l'avatar d'un joueur : sa photo si elle existe, sinon sa mascotte
/// Cul Sec, sinon son emoji.
///
/// À utiliser partout où un joueur est affiché : un `Text(player.emoji)`
/// afficherait une mascotte sous la forme brute « cs:… ».
class AvatarView extends StatelessWidget {
  const AvatarView({
    super.key,
    required this.emoji,
    required this.color,
    this.photoBase64,
    this.size = 56,
    this.showRing = true,
  });

  /// Construit directement depuis un joueur du répertoire.
  AvatarView.fromPlayer(
    Player player, {
    super.key,
    this.size = 56,
    this.showRing = true,
  })  : emoji = player.emoji,
        color = player.color,
        photoBase64 = player.photoBase64;

  /// Emoji, ou mascotte au format `cs:<id>`.
  final String emoji;

  /// Couleur du joueur : anneau et fond.
  final Color color;

  /// Photo encodée en base64, `null` si le joueur n'en a pas.
  final String? photoBase64;

  final double size;
  final bool showRing;

  Uint8List? get _bytes {
    final String? raw = photoBase64;
    if (raw == null || raw.isEmpty) return null;
    try {
      return base64Decode(raw);
    } on FormatException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Uint8List? bytes = _bytes;
    final bool mascot = bytes == null && AvatarCatalog.isMascot(emoji);

    final Widget content;
    if (bytes != null) {
      content = Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * 3).round(),
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _EmojiLabel(emoji: emoji, size: size),
      );
    } else if (mascot) {
      content = MascotImage(value: emoji, size: size);
    } else {
      content = _EmojiLabel(emoji: emoji, size: size);
    }

    return RepaintBoundary(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // La mascotte apporte son propre fond.
          color: mascot ? null : color.withValues(alpha: 0.20),
          border: showRing ? Border.all(color: color, width: 2) : null,
        ),
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        child: content,
      ),
    );
  }
}

/// Image d'une mascotte (`cs:<id>`), avec repli sur 🍻 si elle est inconnue.
///
/// Les avatars sont des fichiers WebP déclarés comme assets
/// (`assets/avatars/avatar_<id>.webp`) : ils ne sont lus et décodés qu'au
/// moment où ils s'affichent, à la taille affichée, puis gardés dans le
/// cache d'images de Flutter.
class MascotImage extends StatelessWidget {
  const MascotImage({super.key, required this.value, required this.size});

  final String value;
  final double size;

  /// Chemin de l'asset d'une mascotte.
  static String assetFor(String value) =>
      'assets/avatars/avatar_${AvatarCatalog.idOf(value)}.webp';

  @override
  Widget build(BuildContext context) {
    // Décodage à la taille réellement affichée (écrans haute densité
    // compris) : bien moins de mémoire qu'une image 256 px pleine.
    final int cache =
        (size * MediaQuery.devicePixelRatioOf(context)).ceil().clamp(32, 256).toInt();

    return Image.asset(
      assetFor(value),
      width: size,
      height: size,
      fit: BoxFit.cover,
      cacheWidth: cache,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => _EmojiLabel(emoji: '🍻', size: size),
    );
  }
}

class _EmojiLabel extends StatelessWidget {
  const _EmojiLabel({required this.emoji, required this.size});

  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Sécurité : une valeur « cs:… » inconnue ne s'affiche jamais en brut.
    final String shown =
        emoji.startsWith(AvatarCatalog.mascotPrefix) ? '🍻' : emoji;
    return Text(
      shown,
      style: TextStyle(fontSize: size * 0.52),
      textAlign: TextAlign.center,
    );
  }
}