import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../models/game_mode.dart';
import '../../models/player.dart';
import '../../models/prompt.dart';
import '../../services/game_session.dart';
import '../../services/haptics.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar_view.dart';
import '../../widgets/common.dart';
import '../../widgets/game_scaffold.dart';
import 'game_finish.dart';

enum _Phase { voting, revealed }

class TuPreferesScreen extends StatefulWidget {
  const TuPreferesScreen({super.key, required this.mode});

  final GameMode mode;

  @override
  State<TuPreferesScreen> createState() => _TuPreferesScreenState();
}

class _TuPreferesScreenState extends State<TuPreferesScreen>
    with GameFinishMixin<TuPreferesScreen> {
  @override
  GameMode get gameMode => widget.mode;

  _Phase _phase = _Phase.voting;
  int _voterIndex = 0;
  final Map<String, int> _votes = <String, int>{};
  bool _revealing = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_initialized) {
        _initialized = true;
        context.read<GameSession>().next();
      }
    });
  }

  int get _votesA => _votes.values.where((int s) => s == 0).length;
  int get _votesB => _votes.values.where((int s) => s == 1).length;

  int get _losingSide {
    if (_votesA == _votesB) return -1;
    return _votesA < _votesB ? 0 : 1;
  }

  Player? _voterAt(List<Player> players) =>
      players.isEmpty ? null : players[_voterIndex % players.length];

  void _castVote(int side) {
    if (_phase != _Phase.voting) return;
    final GameSession session = context.read<GameSession>();
    final Player? voter = _voterAt(session.players);
    if (voter == null) return;

    Haptics.medium();
    setState(() {
      _votes[voter.id] = side;
      _voterIndex++;
      if (_voterIndex >= session.players.length) {
        _phase = _Phase.revealed;
      }
    });

    if (_phase == _Phase.revealed) {
      unawaited(_revealVerdict());
    }
  }

  void _undoLastVote() {
    if (_phase != _Phase.voting || _voterIndex == 0) return;
    final GameSession session = context.read<GameSession>();
    final int previousIndex = _voterIndex - 1;
    final Player previous =
        session.players[previousIndex % session.players.length];
    Haptics.tick();
    setState(() {
      _votes.remove(previous.id);
      _voterIndex = previousIndex;
    });
  }

  Future<void> _revealVerdict() async {
    if (_revealing) return;
    _revealing = true;
    try {
      final GameSession session = context.read<GameSession>();
      await Haptics.roll();
      if (!mounted) return;

      final int losing = _losingSide;
      final List<Player> punished = session.players.where((Player p) {
        final int? side = _votes[p.id];
        return side != null && (losing == -1 || side == losing);
      }).toList();

      if (losing != -1) {
        session.bumpAll(punished, Stat.minorite);
        session.bumpAll(
          session.players.where(
            (Player p) => _votes[p.id] != null && _votes[p.id] != losing,
          ),
          Stat.majorite,
        );
      }
      session.recordSipsForAll(punished, session.rules.prefereMinority);
      await Haptics.triple();
    } finally {
      _revealing = false;
    }
  }

  void _next() {
    if (_revealing) return;
    Haptics.light();
    setState(() {
      _votes.clear();
      _voterIndex = 0;
      _phase = _Phase.voting;
    });
    context.read<GameSession>().next();
  }

  @override
  Widget build(BuildContext context) {
    final GameSession session = context.watch<GameSession>();
    final Prompt? prompt = session.current;
    final List<Player> players = session.players;

    if (prompt == null) {
      return GameScaffold(
        mode: widget.mode,
        onQuit: finishGame,
        child: const _EmptyPack(),
      );
    }

    final String optionA =
        prompt.options.isNotEmpty ? prompt.options[0] : '…';
    final String optionB =
        prompt.options.length > 1 ? prompt.options[1] : '…';

    return GameScaffold(
      mode: widget.mode,
      onQuit: finishGame,
      bottom: _phase == _Phase.revealed
          ? AppButton(
              label: 'Dilemme suivant',
              icon: Icons.arrow_forward_rounded,
              color: widget.mode.color,
              onPressed: _revealing ? null : _next,
            )
          : null,
      child: AnimatedSwitcher(
        duration: AppMotion.base,
        switchInCurve: Curves.easeOutCubic,
        child: _phase == _Phase.voting
            ? _VotingStage(
                key: ValueKey<String>('vote-$_voterIndex'),
                voter: _voterAt(players),
                voterIndex: _voterIndex,
                totalVoters: players.length,
                optionA: optionA,
                optionB: optionB,
                onVote: _castVote,
                onUndo: _voterIndex > 0 ? _undoLastVote : null,
              )
            : _RevealStage(
                key: const ValueKey<String>('reveal'),
                optionA: optionA,
                optionB: optionB,
                votesA: _votesA,
                votesB: _votesB,
                losingSide: _losingSide,
                players: players,
                votes: _votes,
                sanction:
                    session.sanctionLabel(session.rules.prefereMinority),
                noSips: session.rules.prefereMinority == 0,
              ),
      ),
    );
  }
}

class _VotingStage extends StatelessWidget {
  const _VotingStage({
    super.key,
    required this.voter,
    required this.voterIndex,
    required this.totalVoters,
    required this.optionA,
    required this.optionB,
    required this.onVote,
    required this.onUndo,
  });

  final Player? voter;
  final int voterIndex;
  final int totalVoters;
  final String optionA;
  final String optionB;
  final ValueChanged<int> onVote;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    if (voter == null) {
      return const _EmptyPack();
    }

    return Padding(
      padding: AppSpacing.screen,
      child: Column(
        children: <Widget>[
          _VoterBanner(
            voter: voter!,
            voterIndex: voterIndex,
            totalVoters: totalVoters,
            onUndo: onUndo,
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: _VoteZone(
              side: 'A',
              label: optionA,
              color: AppColors.modePrefere,
              onTap: () => onVote(0),
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
              label: optionB,
              color: AppColors.modePrefereAlt,
              onTap: () => onVote(1),
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
    required this.voterIndex,
    required this.totalVoters,
    required this.onUndo,
  });

  final Player voter;
  final int voterIndex;
  final int totalVoters;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    return Column(
      children: <Widget>[
        Text(
          'AU TOUR DE',
          style: context.text.labelMedium?.copyWith(letterSpacing: 3),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (onUndo != null)
              IconButton(
                onPressed: onUndo,
                tooltip: 'Annuler le vote précédent',
                icon: const Icon(Icons.arrow_back_rounded, size: 20),
              )
            else
              const SizedBox(width: 48),
            const SizedBox(width: AppSpacing.sm),
            AvatarView.fromPlayer(voter, size: 44),
            const SizedBox(width: AppSpacing.sm + 2),
            Flexible(
              child: Text(
                voter.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.displaySmall?.copyWith(
                  color: voter.color,
                  fontSize: 28,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const SizedBox(width: 48),
          ],
        ),
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
                          ? voter.color
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
    required this.onTap,
  });

  final String side;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_VoteZone> createState() => _VoteZoneState();
}

class _VoteZoneState extends State<_VoteZone> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
    );
  }
}

class _RevealStage extends StatelessWidget {
  const _RevealStage({
    super.key,
    required this.optionA,
    required this.optionB,
    required this.votesA,
    required this.votesB,
    required this.losingSide,
    required this.players,
    required this.votes,
    required this.sanction,
    required this.noSips,
  });

  final String optionA;
  final String optionB;
  final int votesA;
  final int votesB;
  final int losingSide;
  final List<Player> players;
  final Map<String, int> votes;
  final String sanction;
  final bool noSips;

  bool _isOnLosingSide(Player p) {
    final int? side = votes[p.id];
    return side != null && (losingSide == -1 || side == losingSide);
  }

  @override
  Widget build(BuildContext context) {
    final List<Player> losers =
        players.where(_isOnLosingSide).toList(growable: false);
    final List<Player> winners =
        players.where((Player p) => votes.containsKey(p.id) && !_isOnLosingSide(p))
            .toList(growable: false);

    final bool tie = losingSide == -1;

    return Padding(
      padding: AppSpacing.screen,
      child: Column(
        children: <Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(
            tie ? 'ÉGALITÉ PARFAITE' : 'LA MINORITÉ BOIT',
            textAlign: TextAlign.center,
            style: context.text.labelMedium?.copyWith(
              letterSpacing: 3,
              color: tie ? AppColors.warning : AppColors.warning,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: _TallyCard(
                  side: 'A',
                  label: optionA,
                  votes: votesA,
                  total: votesA + votesB,
                  color: AppColors.modePrefere,
                  losing: tie || losingSide == 0,
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: _TallyCard(
                  side: 'B',
                  label: optionB,
                  votes: votesB,
                  total: votesA + votesB,
                  color: AppColors.modePrefereAlt,
                  losing: tie || losingSide == 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          if (losers.isNotEmpty) ...<Widget>[
            Text(
              tie ? 'TOUT LE MONDE BOIT' : 'CONCERNÉS',
              style: context.text.labelMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                for (final Player p in losers)
                  _PlayerChip(player: p, highlighted: true),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              noSips ? 'Désignés par le groupe' : sanction,
              style: context.text.bodyMedium?.copyWith(
                color: AppColors.warning,
              ),
            ),
          ],
          if (winners.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xl),
            Text(
              'MAJORITÉ',
              style: context.text.labelMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                for (final Player p in winners)
                  _PlayerChip(player: p, highlighted: false),
              ],
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 380.ms);
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
  const _PlayerChip({required this.player, required this.highlighted});

  final Player player;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlighted
            ? AppColors.warning.withValues(alpha: 0.16)
            : colors.fill,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(
          color: highlighted
              ? AppColors.warning.withValues(alpha: 0.7)
              : colors.borderSoft,
          width: highlighted ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AvatarView.fromPlayer(player, size: 22, showRing: false),
          const SizedBox(width: 6),
          Text(
            player.name,
            style: context.text.titleMedium?.copyWith(
              fontSize: 13,
              color: highlighted ? AppColors.warning : colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPack extends StatelessWidget {
  const _EmptyPack();

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    return Center(
      child: Padding(
        padding: AppSpacing.screen,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.inbox_outlined,
              size: 40,
              color: colors.textMuted,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Aucune carte à ce niveau',
              style: context.text.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Changez d’intensité ou réactivez des thèmes.',
              style: context.text.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}