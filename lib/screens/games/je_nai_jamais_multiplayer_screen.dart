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

/// Écran de jeu « Je n'ai jamais » en multijoueur local.
class JeNaiJamaisMultiplayerScreen extends StatelessWidget {
  const JeNaiJamaisMultiplayerScreen({
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
            child: const _WaitingForStart(),
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
    if (!isHost) return null;

    if (snapshot.phase == MultiplayerPhase.voting) {
      return AppButton(
        label: 'Terminer la manche',
        icon: Icons.check_rounded,
        color: mode.color,
        onPressed: () {
          Haptics.medium();
          hostController!.endJnimRound();
        },
      );
    }

    if (snapshot.phase == MultiplayerPhase.revealed) {
      return AppButton(
        label: 'Carte suivante',
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
    switch (snapshot.phase) {
      case MultiplayerPhase.waiting:
        return const _WaitingForStart(key: ValueKey<String>('waiting'));
      case MultiplayerPhase.voting:
        return _VotingStage(
          key: const ValueKey<String>('voting'),
          snapshot: snapshot,
          isHost: isHost,
          hostController: hostController,
          clientController: clientController,
        );
      case MultiplayerPhase.revealed:
        return _RevealedStage(
          key: const ValueKey<String>('revealed'),
          snapshot: snapshot,
        );
      case MultiplayerPhase.finished:
        return const _WaitingForStart(key: ValueKey<String>('finished'));
    }
  }
}

// ---------------------------------------------------------------------------

class _WaitingForStart extends StatelessWidget {
  const _WaitingForStart({super.key});

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
            Text(
              'Préparation de la carte…',
              textAlign: TextAlign.center,
              style: context.text.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Phase de vote : chacun se marque
// ---------------------------------------------------------------------------

class _VotingStage extends StatelessWidget {
  const _VotingStage({
    super.key,
    required this.snapshot,
    required this.isHost,
    this.hostController,
    this.clientController,
  });

  final MultiplayerSnapshot snapshot;
  final bool isHost;
  final HostGameController? hostController;
  final ClientGameController? clientController;

  MultiplayerCard? get _card => snapshot.currentCard;

  String? get _myPlayerId {
    if (isHost) {
      return snapshot.players.isEmpty ? null : snapshot.players.first.id;
    }
    return clientController!.assignedPlayerId;
  }

  bool get _amIMarked {
    final String? id = _myPlayerId;
    if (id == null) return false;
    return snapshot.votes[id] == 'marked';
  }

  int get _markedCount => snapshot.votes.values
      .where((String v) => v == 'marked')
      .length;

  void _toggleMyMark() {
    final String? id = _myPlayerId;
    if (id == null) return;

    if (isHost) {
      if (_amIMarked) {
        hostController!.unmarkJnimLocally();
      } else {
        hostController!.markJnimLocally();
      }
    } else {
      if (!_amIMarked) {
        clientController!.markJnim();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final MultiplayerCard? card = _card;
    if (card == null) return const _WaitingForStart();

    return Padding(
      padding: AppSpacing.screen,
      child: Column(
        children: <Widget>[
          Expanded(
            flex: 5,
            child: _StatementCard(
              card: card,
              markedCount: _markedCount,
              totalPlayers: snapshot.players.length,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'TE DÉNONCES-TU ?',
            style: context.text.labelMedium?.copyWith(
              color: AppColors.modeJamais,
            ),
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          _SelfMarkButton(
            marked: _amIMarked,
            onTap: _toggleMyMark,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

class _StatementCard extends StatelessWidget {
  const _StatementCard({
    required this.card,
    required this.markedCount,
    required this.totalPlayers,
  });

  final MultiplayerCard card;
  final int markedCount;
  final int totalPlayers;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    final int len = card.text.length;
    final double size = switch (len) {
      < 45 => 28,
      < 80 => 24,
      < 120 => 20,
      _ => 17,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color.lerp(colors.surface, AppColors.modeJamais, 0.16)!,
            colors.surface,
          ],
        ),
        borderRadius: AppRadii.bigCard,
        border: Border.all(
          color: AppColors.modeJamais.withValues(alpha: 0.38),
          width: 1.4,
        ),
        boxShadow: AppShadows.raised,
      ),
      child: Column(
        children: <Widget>[
          Text(
            'JE N’AI JAMAIS',
            style: context.text.labelMedium?.copyWith(
              letterSpacing: 5,
              color: AppColors.modeJamais,
            ),
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
          if (markedCount > 0)
            Text(
              '$markedCount sur $totalPlayers concerné(s)',
              style: context.text.titleMedium?.copyWith(
                color: AppColors.warning,
                fontSize: 14,
              ),
            )
          else
            Text(
              'Personne pour l’instant…',
              style: context.text.bodySmall?.copyWith(fontSize: 12),
            ),
        ],
      ),
    );
  }
}

class _SelfMarkButton extends StatelessWidget {
  const _SelfMarkButton({required this.marked, required this.onTap});

  final bool marked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.base,
        curve: AppMotion.emphasized,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: marked
              ? AppColors.warning.withValues(alpha: 0.22)
              : colors.fill,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: marked ? AppColors.warning : colors.borderSoft,
            width: marked ? 1.8 : 1,
          ),
          boxShadow:
              marked ? AppShadows.glow(AppColors.warning, opacity: 0.30) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              marked ? Icons.local_bar_rounded : Icons.local_bar_outlined,
              size: 22,
              color: marked ? AppColors.warning : colors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              marked ? 'Oui, je l’ai déjà fait' : 'Je l’ai déjà fait',
              style: context.text.titleMedium?.copyWith(
                fontSize: 15,
                color: marked ? AppColors.warning : colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Phase de révélation
// ---------------------------------------------------------------------------

class _RevealedStage extends StatelessWidget {
  const _RevealedStage({super.key, required this.snapshot});

  final MultiplayerSnapshot snapshot;

  MultiplayerPlayer? _playerById(String id) {
    for (final MultiplayerPlayer p in snapshot.players) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final MultiplayerVerdict? verdict = snapshot.verdict;
    if (verdict == null) return const _WaitingForStart();

    final List<MultiplayerPlayer> concerned = <MultiplayerPlayer>[
      for (final String id in verdict.loserIds)
        if (_playerById(id) != null) _playerById(id)!,
    ];

    return Padding(
      padding: AppSpacing.screen,
      child: Column(
        children: <Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'VERDICT',
            textAlign: TextAlign.center,
            style: context.text.labelMedium?.copyWith(
              letterSpacing: 3,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            verdict.summary,
            textAlign: TextAlign.center,
            style: context.text.headlineLarge,
          ),
          const SizedBox(height: AppSpacing.xl),
          if (concerned.isEmpty)
            Text(
              'Personne ne s’est dénoncé',
              style: context.text.bodyLarge,
            )
          else ...<Widget>[
            Text(
              'CONCERNÉS',
              style: context.text.labelMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    for (final MultiplayerPlayer p in concerned)
                      _PlayerChip(player: p),
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

class _PlayerChip extends StatelessWidget {
  const _PlayerChip({required this.player});

  final MultiplayerPlayer player;

  @override
  Widget build(BuildContext context) {
    final Color color = AppColors
        .playerPalette[player.colorIndex % AppColors.playerPalette.length];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.7),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AvatarView(
            emoji: player.emoji,
            photoBase64: player.photoBase64,
            color: color,
            size: 26,
            showRing: false,
          ),
          const SizedBox(width: 8),
          Text(
            player.name,
            style: context.text.titleMedium?.copyWith(
              fontSize: 14,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}