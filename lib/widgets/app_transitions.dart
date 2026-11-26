import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// Transitions de navigation.
///
/// Trois routes, chacune pour une intention différente :
///
/// * [SheetRoute]      — l'écran monte depuis le bas, celui de dessous recule
///                       légèrement. Pour un écran « au-dessus » du parcours :
///                       réglages, répertoire, détail.
/// * [ForwardRoute]    — glissement latéral avec parallaxe. Pour avancer dans
///                       un parcours linéaire : configuration → partie.
/// * [FadeScaleRoute]  — fondu avec léger zoom. Pour un changement de contexte
///                       complet : splash → accueil, partie → fin de partie.
///
/// Toutes utilisent des widgets de transition au niveau RenderObject
/// (`SlideTransition`, `FadeTransition`, `ScaleTransition`) : ils animent sans
/// reconstruire l'arbre, ce qui reste tenable dans un budget de 6,9 ms.
/// ---------------------------------------------------------------------------

/// L'écran entre par le bas et pousse le précédent en arrière-plan.
///
/// Le détail qui fait la différence : la page sortante recule (échelle 0,92)
/// et s'assombrit. On perçoit une pile de cartes, pas un simple remplacement.
class SheetRoute<T> extends PageRouteBuilder<T> {
  SheetRoute({
    required this.builder,
    this.duration = const Duration(milliseconds: 420),
  }) : super(
          transitionDuration: duration,
          reverseTransitionDuration:
              Duration(milliseconds: (duration.inMilliseconds * 0.8).round()),
          opaque: false,
          barrierColor: Colors.black54,
          pageBuilder: (BuildContext context, _, __) => builder(context),
        );

  final WidgetBuilder builder;
  final Duration duration;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Courbe « emphasized » de Material 3 : démarrage vif, arrivée posée.
    final Animation<double> curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(curved),
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.6, end: 1).animate(curved),
        child: child,
      ),
    );
  }
}

/// Recul de la page sortante, à appliquer à l'écran qui reste dessous.
///
/// À envelopper autour du `Scaffold` de l'écran appelant — voir l'exemple
/// dans `home_screen.dart`. Sans cela, la page du dessous reste figée et
/// l'effet de profondeur disparaît.
class SettleBehind extends StatelessWidget {
  const SettleBehind({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // `secondaryAnimation` de la route courante : elle progresse de 0 à 1
    // quand une nouvelle page se pose par-dessus.
    final ModalRoute<Object?>? route = ModalRoute.of(context);
    if (route == null) return child;

    return AnimatedBuilder(
      animation: route.secondaryAnimation!,
      builder: (BuildContext context, Widget? inner) {
        final double t = Curves.easeOutCubic.transform(
          route.secondaryAnimation!.value,
        );

        return Transform.scale(
          scale: 1 - 0.08 * t,
          child: Opacity(
            // On ne descend pas sous 0,55 : l'écran doit rester lisible
            // derrière une feuille partiellement transparente.
            opacity: 1 - 0.45 * t,
            child: inner,
          ),
        );
      },
      child: child,
    );
  }
}

/// Glissement latéral avec parallaxe : la page entrante vient de la droite,
/// la sortante part vers la gauche à un tiers de la vitesse.
///
/// Ce décalage de vitesse est ce qui distingue une vraie transition d'un
/// simple balayage : l'œil perçoit deux plans de profondeur.
class ForwardRoute<T> extends PageRouteBuilder<T> {
  ForwardRoute({
    required this.builder,
    this.duration = const Duration(milliseconds: 380),
  }) : super(
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          pageBuilder: (BuildContext context, _, __) => builder(context),
        );

  final WidgetBuilder builder;
  final Duration duration;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final Animation<double> enter = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final Animation<double> exit = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutCubic,
    );

    return SlideTransition(
      // Page sortante : recul lent vers la gauche.
      position: Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(-0.33, 0),
      ).animate(exit),
      child: SlideTransition(
        // Page entrante : arrivée pleine vitesse depuis la droite.
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(enter),
        child: child,
      ),
    );
  }
}

/// Fondu enchaîné avec un léger zoom avant. Pour un changement de contexte
/// complet, où aucune continuité spatiale n'a de sens.
class FadeScaleRoute<T> extends PageRouteBuilder<T> {
  FadeScaleRoute({
    required this.builder,
    this.duration = const Duration(milliseconds: 460),
  }) : super(
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          pageBuilder: (BuildContext context, _, __) => builder(context),
        );

  final WidgetBuilder builder;
  final Duration duration;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final Animation<double> curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );

    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        // Zoom très léger : 1,04 suffit à donner une impression d'avancée.
        // Au-delà, l'effet devient voyant et fatigue à la longue.
        scale: Tween<double>(begin: 1.04, end: 1).animate(curved),
        child: child,
      ),
    );
  }
}
