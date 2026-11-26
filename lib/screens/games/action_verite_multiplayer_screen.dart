import 'package:flutter/material.dart';

import '../../models/game_mode.dart';
import '../../multiplayer/client_game_controller.dart';
import '../../multiplayer/host_game_controller.dart';
import '../../multiplayer/multiplayer_session.dart';
import '../../services/haptics.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar_view.dart';
import '../../widgets/common.dart';
import '../../widgets/game_scaffold.dart';

/// Écran de jeu « Action ou Vérité » en multijoueur local.
class ActionVeriteMultiplayerScreen extends StatelessWidget {
  const ActionVeriteMultiplayerScreen({
    super.key,
    required this.mode,
    this.hostController,
    this.clientController,
    this.onQuit,
  }) : assert(
          hostController != null || clientController != null,
          'Il faut au moins un contrôleur (hôte ou client).',
        );

  final GameMode mode;
  final HostGameController? hostController;
  final ClientGameController? clientController;
  final VoidCallback? onQuit;

  bool get isHost => hostController != null;

  Listenable get _listenables =>
      Listenable.merge(<Listenable?>[hostController, clientController]);

  MultiplayerSnapshot? get _snapshot =>
      hostController?.snapshot ?? clientController?.snapshot;

  bool get _iAmActivePlayer {
    final MultiplayerSnapshot? snap = _snapshot;
    if (snap == null) return false;
    final String? activeId = snap.activePlayerId;
    if (activeId == null) return false;
    if (isHost) {
      if (snap.players.isEmpty) return false;
      return activeId == snap.players.first.id;
    }
    return activeId == clientController!.assignedPlayerId;
  }

  MultiplayerCard? get _privateCard =>
      isHost ? hostController!.localPrivateCard : clientController!.privateCard;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _listenables,
      builder: (BuildContext context, Widget? _) {
        final MultiplayerSnapshot? snapshot = _snapshot;
        if (snapshot == null) {
          return GameScaffold(
            mode: mode,
            onQuit: onQuit,
            child: const _Waiting(),
          );
        }

        return GameScaffold(
          mode: mode,
          onQuit: onQuit,
          turn: snapshot.turn,
          bottom: _buildBottom(snapshot),
          child: AnimatedSwitcher(
            duration: AppMotion.base,
            switchInCurve: Curves.easeOutCubic,
            child: _buildStage(snapshot),
          ),
        );
      },
    );
  }

  Widget? _buildBottom(MultiplayerSnapshot snapshot) {
    if (_iAmActivePlayer && snapshot.phase == MultiplayerPhase.voting) {
      final MultiplayerCard? card = _privateCard;
      if (card != null) {
        void refuse() {
          if (isHost) {
            hostController!.refuseAvLocally();
          } else {
            clientController!.refuseAv();
          }
        }

        void redraw() {
          if (isHost) {
            hostController!.redrawAvLocally();
          } else {
            clientController!.redrawAv();
          }
        }

        void done() {
          if (isHost) {
            hostController!.doneAvLocally();
          } else {
            clientController!.doneAv();
          }
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: refuse,
                    icon: const Icon(Icons.local_bar_outlined, size: 17),
                    label: const Text('Je bois'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm + 2),
                Expanded(
                  child: AppButton(
                    label: 'Fait !',
                    icon: Icons.check_rounded,
                    color: AppColors.modeAction,
                    onPressed: done,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton.icon(
              onPressed: redraw,
              icon: const Icon(Icons.refresh_rounded, size: 15),
              label: const Text('Autre carte'),
            ),
          ],
        );
      }
      return null;
    }

    if (isHost && snapshot.phase == MultiplayerPhase.revealed) {
      return AppButton(
        label: 'Manche suivante',
        icon: Icons.arrow_forward_rounded,
        color: mode.color,
        onPressed: () {
          Haptics.light();
          hostController!.nextRound();
        },
      );
    }

    return null;
  }

  Widget _buildStage(MultiplayerSnapshot snapshot) {
    if (snapshot.phase == MultiplayerPhase.waiting) {
      return _ChoosingStage(
        key: const ValueKey<String>('choosing'),
        snapshot: snapshot,
        iAmActivePlayer: _iAmActivePlayer,
        isHost: isHost,
        hostController: hostController,
        clientController: clientController,
      );
    }

    if (snapshot.phase == MultiplayerPhase.voting) {
      return _PlayingStage(
        key: const ValueKey<String>('playing'),
        snapshot: snapshot,
        iAmActivePlayer: _iAmActivePlayer,
        privateCard: _privateCard,
      );
    }

    if (snapshot.phase == MultiplayerPhase.revealed) {
      return _ResolvedStage(
        key: const ValueKey<String>('resolved'),
        snapshot: snapshot,
      );
    }

    return const _Waiting(key: ValueKey<String>('finished'));
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.screen,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(color: AppColors.accent),
            const SizedBox(height: AppSpacing.lg),
            Text('Préparation…', style: context.text.bodyLarge),
          ],
        ),
      ),
    );
  }
}

class _ChoosingStage extends StatelessWidget {
  const _ChoosingStage({
    super.key,
    required this.snapshot,
    required this.iAmActivePlayer,
    required this.isHost,
    this.hostController,
    this.clientController,
  });

  final MultiplayerSnapshot snapshot;
  final bool iAmActivePlayer;
  final bool isHost;
  final HostGameController? hostController;
  final ClientGameController? clientController;

  MultiplayerPlayer? get _activePlayer {
    final String? id = snapshot.activePlayerId;
    if (id == null) return null;
    for (final MultiplayerPlayer p in snapshot.players) {
      if (p.id == id) return p;
    }
    return null;
  }

  void _choose(String kind) {
    if (isHost) {
      hostController!.chooseAvLocally(kind);
    } else {
      clientController!.chooseAv(kind);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    final MultiplayerPlayer? player = _activePlayer;
    if (player == null) return const _Waiting();

    return Padding(
      padding: AppSpacing.screen,
      child: Column(
        children: <Widget>[
          _PlayerBanner(player: player, iAmActivePlayer: iAmActivePlayer),
          const SizedBox(height: AppSpacing.lg),
          if (iAmActivePlayer) ...<Widget>[
            Text(
              'CHOISIS TON CAMP',
              style: context.text.labelMedium?.copyWith(letterSpacing: 3),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: _HalfChoice(
                icon: Icons.bolt_rounded,
                title: 'ACTION',
                subtitle: 'Un gage à exécuter',
                color: AppColors.modeAction,
                onTap: () => _choose('action'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: _HalfChoice(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'VÉRITÉ',
                subtitle: 'Une question honnête',
                color: AppColors.modePrefereAlt,
                onTap: () => _choose('verite'),
              ),
            ),
          ] else ...<Widget>[
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.hourglass_top_rounded,
                      size: 48,
                      color: colors.textMuted,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      '${player.name} choisit son camp…',
                      textAlign: TextAlign.center,
                      style: context.text.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Action ou Vérité, il faut trancher.',
                      textAlign: TextAlign.center,
                      style: context.text.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlayerBanner extends StatelessWidget {
  const _PlayerBanner({
    required this.player,
    required this.iAmActivePlayer,
  });

  final MultiplayerPlayer player;
  final bool iAmActivePlayer;

  @override
  Widget build(BuildContext context) {
    final Color color = AppColors
        .playerPalette[player.colorIndex % AppColors.playerPalette.length];

    return Column(
      children: <Widget>[
        Text(
          iAmActivePlayer ? 'À TOI DE JOUER' : 'AU TOUR DE',
          style: context.text.labelMedium?.copyWith(letterSpacing: 3),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            AvatarView(
              emoji: player.emoji,
              photoBase64: player.photoBase64,
              color: color,
              size: 44,
              showRing: false,
            ),
            const SizedBox(width: AppSpacing.sm + 2),
            Flexible(
              child: Text(
                player.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.displaySmall?.copyWith(
                  color: color,
                  fontSize: 28,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HalfChoice extends StatelessWidget {
  const _HalfChoice({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color.lerp(colors.surface, color, 0.22)!,
              Color.lerp(colors.surface, color, 0.06)!,
            ],
          ),
          borderRadius: AppRadii.bigCard,
          border: Border.all(color: color.withValues(alpha: 0.4)),
          boxShadow: AppShadows.card,
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 30, color: color),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: context.text.displaySmall?.copyWith(
                letterSpacing: 1.5,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle, style: context.text.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _PlayingStage extends StatelessWidget {
  const _PlayingStage({
    super.key,
    required this.snapshot,
    required this.iAmActivePlayer,
    required this.privateCard,
  });

  final MultiplayerSnapshot snapshot;
  final bool iAmActivePlayer;
  final MultiplayerCard? privateCard;

  MultiplayerPlayer? get _activePlayer {
    final String? id = snapshot.activePlayerId;
    if (id == null) return null;
    for (final MultiplayerPlayer p in snapshot.players) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    final MultiplayerPlayer? player = _activePlayer;
    if (player == null) return const _Waiting();

    if (iAmActivePlayer && privateCard != null) {
      return _PrivateCardView(card: privateCard!);
    }

    return Center(
      child: Padding(
        padding: AppSpacing.screen,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.visibility_off_rounded,
              size: 48,
              color: colors.textMuted,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              '${player.name} a pris une carte',
              textAlign: TextAlign.center,
              style: context.text.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              snapshot.activeKind == 'verite'
                  ? 'Une vérité à avouer.'
                  : 'Une action à exécuter.',
              textAlign: TextAlign.center,
              style: context.text.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivateCardView extends StatelessWidget {
  const _PrivateCardView({required this.card});

  final MultiplayerCard card;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    final bool isAction = card.kind == 'action';
    final Color color =
        isAction ? AppColors.modeAction : AppColors.modePrefereAlt;
    final int len = card.text.length;
    final double size = switch (len) {
      < 50 => 28,
      < 95 => 24,
      < 150 => 20,
      _ => 17,
    };

    return Padding(
      padding: AppSpacing.screen.copyWith(bottom: AppSpacing.sm),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color.lerp(colors.surface, color, 0.16)!,
              colors.surface,
            ],
          ),
          borderRadius: AppRadii.bigCard,
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.4),
          boxShadow: AppShadows.raised,
        ),
        child: Column(
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  isAction
                      ? Icons.bolt_rounded
                      : Icons.chat_bubble_outline_rounded,
                  size: 15,
                  color: color,
                ),
                const SizedBox(width: 7),
                Text(
                  isAction ? 'ACTION' : 'VÉRITÉ',
                  style: context.text.labelMedium?.copyWith(
                    letterSpacing: 4,
                    color: color,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              card.text,
              textAlign: TextAlign.center,
              style: context.text.headlineMedium?.copyWith(
                fontSize: size,
                height: 1.25,
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _ResolvedStage extends StatelessWidget {
  const _ResolvedStage({super.key, required this.snapshot});

  final MultiplayerSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final MultiplayerVerdict? verdict = snapshot.verdict;
    if (verdict == null) return const _Waiting();

    return Center(
      child: Padding(
        padding: AppSpacing.screen,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.celebration_rounded,
              size: 56,
              color: AppColors.warning,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              verdict.summary,
              textAlign: TextAlign.center,
              style: context.text.headlineLarge,
            ),
          ],
        ),
      ),
    );
  }
}