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

/// Écran de jeu « Qui pourrait… » en multijoueur local.
class QuiPourraitMultiplayerScreen extends StatelessWidget {
  const QuiPourraitMultiplayerScreen({
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
    if (snapshot.phase != MultiplayerPhase.revealed) return null;

    return AppButton(
      label: 'Question suivante',
      icon: Icons.arrow_forward_rounded,
      color: mode.color,
      onPressed: () {
        Haptics.light();
        hostController!.nextRound();
      },
    );
  }

  Widget _buildStage(MultiplayerSnapshot snapshot) {
    switch (snapshot.phase) {
      case MultiplayerPhase.waiting:
        return const _WaitingForStart(key: ValueKey<String>('waiting'));
      case MultiplayerPhase.voting:
        return _VotingStage(
          key: ValueKey<String>('voting-${snapshot.voterIndex}'),
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
// Attente
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
              'Préparation de la question…',
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
// Phase de vote
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

  MultiplayerPlayer? get _voter {
    if (snapshot.voterIndex >= snapshot.players.length) return null;
    return snapshot.players[snapshot.voterIndex];
  }

  bool get _amIVoter {
    final MultiplayerPlayer? voter = _voter;
    if (voter == null) return false;
    if (isHost) {
      return hostController!.currentVoterIsLocal;
    } else {
      return voter.id == clientController!.assignedPlayerId;
    }
  }

  void _voteFor(MultiplayerPlayer target) {
    if (isHost) {
      hostController!.castVoteLocally(target.id);
    } else {
      clientController!.castVote(target.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    final MultiplayerCard? card = _card;
    if (card == null) {
      return const _WaitingForStart();
    }

    final MultiplayerPlayer? voter = _voter;
    if (voter == null) {
      return const _WaitingForStart();
    }

    final List<MultiplayerPlayer> targets = snapshot.players
        .where((MultiplayerPlayer p) => p.id != voter.id)
        .toList(growable: false);

    return Padding(
      padding: AppSpacing.screen,
      child: Column(
        children: <Widget>[
          _VoterBanner(
            voter: voter,
            amIVoter: _amIVoter,
            totalVoters: snapshot.players.length,
            voterIndex: snapshot.voterIndex,
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            flex: 3,
            child: _QuestionCard(card: card),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            _amIVoter ? 'TOUCHE TA RÉPONSE' : 'EN ATTENTE…',
            style: context.text.labelMedium?.copyWith(
              letterSpacing: 2,
              color: _amIVoter
                  ? AppColors.modeJamais
                  : colors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  for (final MultiplayerPlayer p in targets)
                    _TargetTile(
                      player: p,
                      enabled: _amIVoter,
                      onTap: () => _voteFor(p),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoterBanner extends StatelessWidget {
  const _VoterBanner({
    required this.voter,
    required this.amIVoter,
    required this.totalVoters,
    required this.voterIndex,
  });

  final MultiplayerPlayer voter;
  final bool amIVoter;
  final int totalVoters;
  final int voterIndex;

  static Color _colorFor(int index) =>
      AppColors.playerPalette[index % AppColors.playerPalette.length];

  @override
  Widget build(BuildContext context) {
    final bool waiting = !amIVoter;
    return Column(
      children: <Widget>[
        Text(
          amIVoter ? 'À TOI DE VOTER' : 'EN ATTENTE DU VOTE DE',
          style: context.text.labelMedium?.copyWith(letterSpacing: 3),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _AvatarFromMultiplayer(player: voter, size: 40),
            const SizedBox(width: AppSpacing.sm + 2),
            Flexible(
              child: Text(
                voter.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.headlineMedium?.copyWith(
                  color: _colorFor(voter.colorIndex),
                  fontSize: 22,
                ),
              ),
            ),
          ],
        ),
        if (waiting) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Patiente quelques secondes…',
            style: context.text.bodySmall,
          ),
        ],
        const SizedBox(height: AppSpacing.xs + 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            for (int i = 0; i < totalVoters; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == voterIndex ? 18 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i < voterIndex
                      ? AppColors.success
                      : i == voterIndex
                          ? _colorFor(voter.colorIndex)
                          : context.culColors.fillStrong,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.card});

  final MultiplayerCard card;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    final int len = card.text.length;
    final double size = switch (len) {
      < 45 => 24,
      < 80 => 21,
      < 120 => 18,
      _ => 16,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md + 2),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            'QUI POURRAIT…',
            style: context.text.labelMedium?.copyWith(
              letterSpacing: 4,
              color: AppColors.modeJamais,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            card.text,
            textAlign: TextAlign.center,
            style: context.text.headlineMedium?.copyWith(
              fontSize: size,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetTile extends StatefulWidget {
  const _TargetTile({
    required this.player,
    required this.enabled,
    required this.onTap,
  });

  final MultiplayerPlayer player;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_TargetTile> createState() => _TargetTileState();
}

class _TargetTileState extends State<_TargetTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    final MultiplayerPlayer p = widget.player;
    final Color color = AppColors
        .playerPalette[p.colorIndex % AppColors.playerPalette.length];
    final double opacity = widget.enabled ? 1 : 0.40;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled
          ? (_) => setState(() => _pressed = true)
          : null,
      onTapUp: widget.enabled
          ? (_) => setState(() => _pressed = false)
          : null,
      onTapCancel: widget.enabled
          ? () => setState(() => _pressed = false)
          : null,
      onTap: widget.enabled ? widget.onTap : null,
      child: AnimatedOpacity(
        duration: AppMotion.base,
        opacity: opacity,
        child: AnimatedScale(
          scale: _pressed ? 0.94 : 1,
          duration: AppMotion.fast,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _pressed
                  ? color.withValues(alpha: 0.24)
                  : colors.surfaceHigh,
              borderRadius: AppRadii.button,
              border: Border.all(
                color: _pressed ? color : colors.borderSoft,
                width: _pressed ? 2 : 1,
              ),
              boxShadow: _pressed
                  ? AppShadows.glow(color, opacity: 0.30)
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _AvatarFromMultiplayer(player: p, size: 34),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  p.name,
                  style: context.text.titleMedium?.copyWith(
                    fontSize: 16,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Phase de révélation
// ---------------------------------------------------------------------------

class _RevealedStage extends StatelessWidget {
  const _RevealedStage({
    super.key,
    required this.snapshot,
  });

  final MultiplayerSnapshot snapshot;

  MultiplayerPlayer? _playerById(String id) {
    for (final MultiplayerPlayer p in snapshot.players) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    final MultiplayerVerdict? verdict = snapshot.verdict;
    if (verdict == null) {
      return const _WaitingForStart();
    }

    final bool tie = verdict.loserIds.length > 1;
    final Map<String, dynamic> extra = verdict.extraJson;
    final Object? rawTally = extra['tally'];
    final Map<String, int> tally = rawTally is Map
        ? <String, int>{
            for (final MapEntry<dynamic, dynamic> e in rawTally.entries)
              e.key.toString(): (e.value as num).toInt(),
          }
        : <String, int>{};

    final List<MultiplayerPlayer> designated = <MultiplayerPlayer>[
      for (final String id in verdict.loserIds)
        if (_playerById(id) != null) _playerById(id)!,
    ];

    final List<MultiplayerPlayer> losers = snapshot.players
        .where((MultiplayerPlayer p) => verdict.loserIds.contains(p.id))
        .toList(growable: false);

    final int maxVotes = designated.isEmpty
        ? 0
        : tally[designated.first.id] ?? 0;

    return Padding(
      padding: AppSpacing.screen,
      child: Column(
        children: <Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(
            designated.isEmpty
                ? 'PERSONNE N’A ÉTÉ DÉSIGNÉ'
                : tie
                    ? 'EX ÆQUO'
                    : 'VERDICT DU GROUPE',
            textAlign: TextAlign.center,
            style: context.text.labelMedium?.copyWith(
              letterSpacing: 3,
              color: designated.isEmpty
                  ? colors.textMuted
                  : AppColors.warning,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (losers.isNotEmpty) ...<Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                for (final MultiplayerPlayer p in losers.take(3))
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: _WinnerTile(
                      player: p,
                      votes: tally[p.id] ?? 0,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (verdict.summary.isNotEmpty)
              Text(
                verdict.summary,
                textAlign: TextAlign.center,
                style: context.text.titleLarge?.copyWith(
                  color: AppColors.warning,
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.xl),
          Text(
            'RÉPARTITION DES VOTES',
            style: context.text.labelMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: ListView.separated(
              itemCount: snapshot.players.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.xs),
              itemBuilder: (BuildContext context, int index) {
                final MultiplayerPlayer p = snapshot.players[index];
                final int count = tally[p.id] ?? 0;
                final bool isDesignated = verdict.loserIds.contains(p.id);
                return _VoteRow(
                  player: p,
                  votes: count,
                  maxVotes: maxVotes,
                  isDesignated: isDesignated,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WinnerTile extends StatelessWidget {
  const _WinnerTile({required this.player, required this.votes});

  final MultiplayerPlayer player;
  final int votes;

  @override
  Widget build(BuildContext context) {
    final Color color = AppColors
        .playerPalette[player.colorIndex % AppColors.playerPalette.length];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.20),
            border: Border.all(color: color, width: 2.5),
            boxShadow: AppShadows.glow(color, opacity: 0.35),
          ),
          child: _AvatarFromMultiplayer(player: player, size: 66),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          player.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.titleMedium?.copyWith(
            fontSize: 14,
            color: color,
          ),
        ),
        Text(
          '$votes ${votes > 1 ? 'votes' : 'vote'}',
          style: context.text.bodySmall?.copyWith(fontSize: 11.5),
        ),
      ],
    );
  }
}

class _VoteRow extends StatelessWidget {
  const _VoteRow({
    required this.player,
    required this.votes,
    required this.maxVotes,
    required this.isDesignated,
  });

  final MultiplayerPlayer player;
  final int votes;
  final int maxVotes;
  final bool isDesignated;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    final Color color = AppColors
        .playerPalette[player.colorIndex % AppColors.playerPalette.length];
    final double ratio = maxVotes == 0 ? 0 : votes / maxVotes;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDesignated
            ? AppColors.warning.withValues(alpha: 0.10)
            : colors.surfaceHigh,
        borderRadius: AppRadii.button,
        border: Border.all(
          color: isDesignated
              ? AppColors.warning.withValues(alpha: 0.6)
              : colors.borderSoft,
          width: isDesignated ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: <Widget>[
          _AvatarFromMultiplayer(player: player, size: 28),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 82,
            child: Text(
              player.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.titleMedium?.copyWith(fontSize: 13.5),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: ratio),
                duration: const Duration(milliseconds: 650),
                curve: Curves.easeOutCubic,
                builder: (BuildContext context, double v, Widget? _) =>
                    LinearProgressIndicator(
                  value: v,
                  minHeight: 6,
                  backgroundColor: colors.fill,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDesignated ? AppColors.warning : color,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 24,
            child: Text(
              '$votes',
              textAlign: TextAlign.right,
              style: context.text.titleMedium?.copyWith(
                fontSize: 14,
                color: votes > 0 ? color : colors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarFromMultiplayer extends StatelessWidget {
  const _AvatarFromMultiplayer({
    required this.player,
    required this.size,
  });

  final MultiplayerPlayer player;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Color color = AppColors
        .playerPalette[player.colorIndex % AppColors.playerPalette.length];
    return AvatarView(
      emoji: player.emoji,
      photoBase64: player.photoBase64,
      color: color,
      size: size,
      showRing: false,
    );
  }
}