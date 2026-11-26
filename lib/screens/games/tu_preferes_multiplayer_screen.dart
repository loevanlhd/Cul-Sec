import 'package:flutter/material.dart';

import '../../models/game_mode.dart';
import '../../multiplayer/client_game_controller.dart';
import '../../multiplayer/host_game_controller.dart';
import '../../multiplayer/multiplayer_session.dart';
import '../../services/haptics.dart';
import '../../services/sounds.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar_view.dart';
import '../../widgets/common.dart';
import '../../widgets/game_scaffold.dart';

class TuPreferesMultiplayerScreen extends StatelessWidget {
  const TuPreferesMultiplayerScreen({
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
      label: 'Manche suivante',
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

class _VotingStage extends StatefulWidget {
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

  @override
  State<_VotingStage> createState() => _VotingStageState();
}

class _VotingStageState extends State<_VotingStage> {
  MultiplayerCard? get _card => widget.snapshot.currentCard;

  MultiplayerPlayer? get _voter {
    if (widget.snapshot.voterIndex >= widget.snapshot.players.length) {
      return null;
    }
    return widget.snapshot.players[widget.snapshot.voterIndex];
  }

  bool get _amIVoter {
    final MultiplayerPlayer? voter = _voter;
    if (voter == null) return false;
    if (widget.isHost) {
      return widget.hostController!.currentVoterIsLocal;
    } else {
      final String? assignedId = widget.clientController!.assignedPlayerId;
      return assignedId != null && voter.id == assignedId;
    }
  }

  @override
  void initState() {
    super.initState();
    if (_amIVoter) {
      Haptics.medium();
      Sounds.play(Sfx.pop);
    }
  }

  @override
  void didUpdateWidget(covariant _VotingStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool wasIVoter = oldWidget.snapshot.voterIndex == widget.snapshot.voterIndex && 
      (oldWidget.hostController?.currentVoterIsLocal == widget.hostController?.currentVoterIsLocal);
      
    if (!wasIVoter && _amIVoter) {
      Haptics.medium();
      Sounds.play(Sfx.pop);
    }
  }

  void _vote(String choice) {
    if (widget.isHost) {
      widget.hostController!.castVoteLocally(choice);
    } else {
      widget.clientController!.castVote(choice);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    final MultiplayerCard? card = _card;
    if (card == null || card.options.length < 2) {
      return const _WaitingForStart();
    }

    return Padding(
      padding: AppSpacing.screen,
      child: Column(
        children: <Widget>[
          _VoterBanner(
            voter: _voter,
            amIVoter: _amIVoter,
            totalVoters: widget.snapshot.players.length,
            voterIndex: widget.snapshot.voterIndex,
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: _VoteZone(
              side: 'A',
              label: card.options[0],
              color: AppColors.modePrefere,
              enabled: _amIVoter,
              onTap: () => _vote('0'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Text(
              'OU',
              style: context.text.labelMedium?.copyWith(
                letterSpacing: 3,
                color: colors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: _VoteZone(
              side: 'B',
              label: card.options[1],
              color: AppColors.modePrefereAlt,
              enabled: _amIVoter,
              onTap: () => _vote('1'),
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

  final MultiplayerPlayer? voter;
  final bool amIVoter;
  final int totalVoters;
  final int voterIndex;

  static Color _colorFor(int index) =>
      AppColors.playerPalette[index % AppColors.playerPalette.length];

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors; // <-- Restauré pour éviter l'erreur
    if (voter == null) {
      return Text(
        'Tout le monde a voté',
        style: context.text.titleMedium,
      );
    }

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
            _AvatarFromMultiplayer(player: voter!, size: 44),
            const SizedBox(width: AppSpacing.sm + 2),
            Flexible(
              child: Text(
                voter!.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.displaySmall?.copyWith(
                  color: _colorFor(voter!.colorIndex),
                  fontSize: 28,
                ),
              ),
            ),
          ],
        ),
        if (waiting) ...<Widget>[
          const SizedBox(height: AppSpacing.xs + 2),
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
                          ? _colorFor(voter!.colorIndex)
                          : colors.fillStrong,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _VoteZone extends StatefulWidget {
  const _VoteZone({
    required this.side,
    required this.label,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  final String side;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_VoteZone> createState() => _VoteZoneState();
}

class _VoteZoneState extends State<_VoteZone> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    final double opacity = widget.enabled ? 1 : 0.35;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:
          widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp:
          widget.enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel:
          widget.enabled ? () => setState(() => _pressed = false) : null,
      onTap: widget.enabled ? widget.onTap : null,
      child: AnimatedOpacity(
        duration: AppMotion.base,
        opacity: opacity,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1,
          duration: AppMotion.fast,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color.lerp(colors.surface, widget.color, 0.22)!,
                  Color.lerp(colors.surface, widget.color, 0.06)!,
                ],
              ),
              borderRadius: AppRadii.bigCard,
              border: Border.all(
                color: _pressed
                    ? widget.color
                    : widget.color.withValues(alpha: 0.35),
                width: _pressed ? 2.2 : 1.2,
              ),
              boxShadow: _pressed
                  ? AppShadows.glow(widget.color, opacity: 0.35)
                  : AppShadows.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Text(
                      'CHOIX ${widget.side}',
                      style: context.text.labelMedium?.copyWith(
                        fontSize: 10,
                        color: widget.color,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: context.text.headlineLarge?.copyWith(
                    fontSize: 22,
                    height: 1.25,
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RevealedStage extends StatelessWidget {
  const _RevealedStage({
    super.key,
    required this.snapshot,
  });

  final MultiplayerSnapshot snapshot;

  MultiplayerCard? get _card => snapshot.currentCard;

  MultiplayerPlayer? _playerById(String id) {
    for (final MultiplayerPlayer p in snapshot.players) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final MultiplayerCard? card = _card;
    final MultiplayerVerdict? verdict = snapshot.verdict;
    if (card == null || verdict == null) {
      return const _WaitingForStart();
    }

    final Object? votesA = verdict.extraJson['votesA'];
    final Object? votesB = verdict.extraJson['votesB'];
    final Object? losingSide = verdict.extraJson['losingSide'];

    return Padding(
      padding: AppSpacing.screen,
      child: Column(
        children: <Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(
            losingSide == -1 ? 'ÉGALITÉ PARFAITE' : 'LA MINORITÉ BOIT',
            textAlign: TextAlign.center,
            style: context.text.labelMedium?.copyWith(
              letterSpacing: 3,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: _TallyCard(
                  side: 'A',
                  label: card.options.isNotEmpty ? card.options[0] : '',
                  votes: (votesA as num?)?.toInt() ?? 0,
                  total: snapshot.players.length,
                  color: AppColors.modePrefere,
                  losing: losingSide == -1 || losingSide == 0,
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: _TallyCard(
                  side: 'B',
                  label: card.options.length > 1 ? card.options[1] : '',
                  votes: (votesB as num?)?.toInt() ?? 0,
                  total: snapshot.players.length,
                  color: AppColors.modePrefereAlt,
                  losing: losingSide == -1 || losingSide == 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          if (verdict.summary.isNotEmpty) ...<Widget>[
            Text(
              verdict.summary,
              textAlign: TextAlign.center,
              style: context.text.titleLarge?.copyWith(
                color: AppColors.warning,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (verdict.loserIds.isNotEmpty) ...<Widget>[
            Text('CONCERNÉS', style: context.text.labelMedium),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                for (final String id in verdict.loserIds)
                  if (_playerById(id) != null)
                    _PlayerChip(player: _playerById(id)!),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TallyCard extends StatelessWidget {
  const _TallyCard({
    required this.side,
    required this.label,
    required this.votes,
    required this.total,
    required this.color,
    required this.losing,
  });

  final String side;
  final String label;
  final int votes;
  final int total;
  final Color color;
  final bool losing;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    final double ratio = total == 0 ? 0 : votes / total;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: losing
            ? AppColors.warning.withValues(alpha: 0.10)
            : colors.surfaceHigh,
        borderRadius: AppRadii.bigCard,
        border: Border.all(
          color: losing
              ? AppColors.warning.withValues(alpha: 0.7)
              : color.withValues(alpha: 0.35),
          width: losing ? 1.8 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(
                  side,
                  style: context.text.labelMedium?.copyWith(
                    fontSize: 10,
                    letterSpacing: 1,
                    color: color,
                  ),
                ),
              ),
              const Spacer(),
              if (losing)
                const Icon(
                  Icons.local_bar_rounded,
                  size: 16,
                  color: AppColors.warning,
                ),
              const SizedBox(width: 6),
              Text(
                '$votes',
                style: context.text.titleLarge?.copyWith(
                  color: color,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: context.text.titleMedium?.copyWith(fontSize: 13.5),
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: ratio),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (BuildContext context, double v, Widget? _) =>
                  LinearProgressIndicator(
                value: v,
                minHeight: 5,
                backgroundColor: colors.fill,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
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
    // <-- Suppression de "final colors = context.culColors;" inutilisé
    final Color c = AppColors
        .playerPalette[player.colorIndex % AppColors.playerPalette.length];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
          _AvatarFromMultiplayer(player: player, size: 22),
          const SizedBox(width: 6),
          Text(
            player.name,
            style: context.text.titleMedium?.copyWith(
              fontSize: 13,
              color: c,
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