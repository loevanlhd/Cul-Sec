import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/game_mode.dart';
import '../../services/game_session.dart';
import '../../theme/app_theme.dart';
import '../end_screen.dart';
import '../game_launcher.dart';
import '../multi_jeu_screen.dart';

/// Mixin partagé par les écrans de jeu.
///
/// Factorise la sortie de partie : afficher le récapitulatif, puis relancer
/// une manche propre ou revenir à l'accueil.
mixin GameFinishMixin<T extends StatefulWidget> on State<T> {
  /// Le mode joué — à exposer dans chaque écran.
  GameMode get gameMode;

  /// Bascule vers l'écran de fin, en remplaçant l'écran de jeu dans la pile
  /// pour qu'un retour arrière ne ramène pas sur une partie terminée.
  void finishGame() {
    // Multi-jeu : récapitulatif global et relance du même mélange.
    final MultiJeuController? multi = context.read<MultiJeuController?>();
    if (multi != null) {
      multi.finish(context);
      return;
    }

    final GameSession session = context.read<GameSession>();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: AppMotion.slow,
        pageBuilder: (_, __, ___) => EndScreen(
          mode: gameMode,
          session: session,
          onReplay: () => _replay(context),
        ),
        transitionsBuilder: (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondary,
          Widget child,
        ) {
          final Animation<double> curved = CurvedAnimation(
            parent: animation,
            curve: AppMotion.enter,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  void _replay(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => GameLauncher(mode: gameMode)),
    );
  }
}

