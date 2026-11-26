import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/game_mode.dart';
import '../screens/multi_jeu_screen.dart';
import '../services/game_session.dart';
import '../services/haptics.dart';
import '../theme/app_theme.dart';
import 'ambient_background.dart';
import 'avatar_view.dart';
import 'common.dart';
import 'intensity_selector.dart';

class GameScaffold extends StatelessWidget {
  const GameScaffold({
    super.key,
    required this.mode,
    required this.child,
    this.accent,
    this.bottom,
    this.onQuit,
    this.showTurnCounter = true,
    this.turn,
  });

  final GameMode mode;
  final Widget child;
  final Color? accent;
  final Widget? bottom;
  final VoidCallback? onQuit;
  final bool showTurnCounter;
  final int? turn;

  Future<void> _confirmQuit(BuildContext context) async {
    Haptics.light();
    final bool? quit = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Terminer la partie ?', style: context.text.titleLarge),
        content: Text(
          'Le récapitulatif de fin de soirée sera affiché.',
          style: context.text.bodyMedium,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continuer'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Terminer'),
          ),
        ],
      ),
    );

    if (quit == true && context.mounted) {
      (onQuit ?? () => Navigator.of(context).pop()).call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final GameSession? session = context.watch<GameSession?>();
    final int? currentTurn = turn ?? session?.turn;

    final Color tint = accent ?? mode.color;
    final bool multi =
        Provider.of<MultiJeuController?>(context, listen: false) != null;
    final colors = context.culColors;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _confirmQuit(context);
      },
      child: Scaffold(
        body: AmbientBackground(
          primary: tint,
          secondary: mode.colorAlt,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              SafeArea(
                child: Column(
                  children: <Widget>[
                    Padding(
                      padding: AppSpacing.screen.copyWith(
                        top: AppSpacing.sm,
                        bottom: AppSpacing.sm,
                      ),
                      child: Row(
                        children: <Widget>[
                          AppPill(
                            padding: const EdgeInsets.all(12),
                            onTap: () => _confirmQuit(context),
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: Icon(
                                Icons.close_rounded,
                                size: 22,
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm + 4),
                          Expanded(
                            child: Row(
                              children: <Widget>[
                                Icon(
                                  multi ? Icons.shuffle_rounded : mode.icon,
                                  size: 14,
                                  color: tint,
                                ),
                                const SizedBox(width: 7),
                                Flexible(
                                  child: Text(
                                    multi
                                        ? 'Multi-jeu · ${mode.title}'
                                        : mode.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.text.titleMedium?.copyWith(
                                      fontSize: 14,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IntensityChip(
                            onTap: () => showIntensitySheet(
                              context,
                              onChanged: (Intensity _) {
                                ScaffoldMessenger.of(context)
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Appliqué à la prochaine partie.',
                                      ),
                                      duration: Duration(seconds: 3),
                                    ),
                                  );
                              },
                            ),
                          ),
                          if (showTurnCounter && currentTurn != null) ...<Widget>[
                            const SizedBox(width: AppSpacing.sm),
                            AppPill(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              child: Text(
                                '$currentTurn',
                                style: context.text.titleMedium?.copyWith(
                                  fontSize: 12,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    Expanded(child: child),

                    if (bottom != null)
                      Padding(
                        padding: AppSpacing.screen.copyWith(
                          top: AppSpacing.sm,
                          bottom: AppSpacing.md,
                        ),
                        child: bottom,
                      ),
                  ],
                ),
              ),
              if (session != null)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: SafeArea(
                    bottom: false,
                    child: GageOverlay(session: session),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class GageOverlay extends StatelessWidget {
  const GageOverlay({super.key, required this.session});

  final GameSession session;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    return ValueListenableBuilder<List<GageNotice>?>(
      valueListenable: session.gages,
      builder: (BuildContext context, List<GageNotice>? notices, _) {
        if (notices == null || notices.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: AppSpacing.screen.copyWith(top: 58),
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.surfaceTop,
                borderRadius: AppRadii.bigCard,
                border: Border.all(color: AppColors.modePrefere, width: 1.6),
                boxShadow:
                    AppShadows.glow(AppColors.modePrefere, opacity: 0.35),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.fitness_center_rounded,
                        size: 16,
                        color: AppColors.modePrefere,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'GAGE À LA PLACE DES GORGÉES',
                        style: context.text.labelMedium?.copyWith(
                          fontSize: 10.5,
                          color: AppColors.modePrefere,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final GageNotice n in notices)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          AvatarView.fromPlayer(
                            n.player,
                            size: 30,
                            showRing: false,
                          ),
                          const SizedBox(width: AppSpacing.sm + 2),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  n.player.name,
                                  style: context.text.titleMedium?.copyWith(
                                    fontSize: 14,
                                    color: n.player.color,
                                  ),
                                ),
                                Text(
                                  n.gage,
                                  style: context.text.bodyMedium?.copyWith(
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        Haptics.success();
                        session.gages.value = null;
                      },
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text(
                        notices.length > 1 ? 'Gages faits !' : 'Gage fait !',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}