import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../models/game_mode.dart';
import '../../models/player.dart';
import '../../models/prompt.dart';
import '../../services/game_session.dart';
import '../../services/haptics.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar_view.dart';
import '../../widgets/common.dart';
import '../../widgets/game_scaffold.dart';
import '../../widgets/intensity_selector.dart';
import 'game_finish.dart';

enum _Phase { voting, revealed }

class QuiPourraitScreen extends StatefulWidget {
  const QuiPourraitScreen({super.key, required this.mode});

  final GameMode mode;

  @override
  State<QuiPourraitScreen> createState() => _QuiPourraitScreenState();
}

class _QuiPourraitScreenState extends State<QuiPourraitScreen>
    with GameFinishMixin<QuiPourraitScreen> {
  @override
  GameMode get gameMode => widget.mode;

  _Phase _phase = _Phase.voting;
  int _voterIndex = 0;
  final Map<String, int> _votes = <String, int>{};
  final List<String> _voteHistory = <String>[];
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

  int _votesOf(Player p) => _votes[p.id] ?? 0;

  Player? _voterAt(List<Player> players) =>
      players.isEmpty ? null : players[_voterIndex % players.length];

  List<Player> _designated(List<Player> players) {
    int best = 0;
    for (final Player p in players) {
      if (_votesOf(p) > best) best = _votesOf(p);
    }
    if (best == 0) return const <Player>[];
    return players.where((Player p) => _votesOf(p) == best).toList();
  }

  void _castVoteFor(Player target) {
    if (_phase != _Phase.voting) return;
    final GameSession session = context.read<GameSession>();
    final Player? voter = _voterAt(session.players);
    if (voter == null || voter.id == target.id) return;

    Haptics.medium();
    setState(() {
      _votes[target.id] = _votesOf(target) + 1;
      _voteHistory.add(target.id);
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
    if (_phase != _Phase.voting || _voteHistory.isEmpty) return;
    Haptics.tick();
    setState(() {
      final String lastTargetId = _voteHistory.removeLast();
      final int current = _votes[lastTargetId] ?? 0;
      if (current <= 1) {
        _votes.remove(lastTargetId);
      } else {
        _votes[lastTargetId] = current - 1;
      }
      _voterIndex--;
    });
  }

  Future<void> _revealVerdict() async {
    if (_revealing) return;
    _revealing = true;
    try {
      final GameSession session = context.read<GameSession>();
      await Haptics.roll();
      if (!mounted) return;

      final List<Player> designated = _designated(session.players);
      session.bumpAll(designated, Stat.designe);
      session.recordSipsForAll(designated, session.rules.quiDesigne);
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
      _voteHistory.clear();
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

    return GameScaffold(
      mode: widget.mode,
      onQuit: finishGame,
      bottom: _phase == _Phase.revealed
          ? AppButton(
              label: 'Question suivante',
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
                prompt: prompt,
                players: players,
                votes: _votes,
                onVote: _castVoteFor,
                onUndo:
                    _voteHistory.isNotEmpty ? _undoLastVote : null,
              )
            : _RevealStage(
                key: const ValueKey<String>('reveal'),
                prompt: prompt,
                players: players,
                votes: _votes,
                designated: _designated(players),
                sanction: session.sanctionLabel(session.rules.quiDesigne),
                noSips: session.rules.quiDesigne == 0,
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
    required this.prompt,
    required this.players,
    required this.votes,
    required this.onVote,
    required this.onUndo,
  });

  final Player? voter;
  final int voterIndex;
  final int totalVoters;
  final Prompt prompt;
  final List<Player> players;
  final Map<String, int> votes;
  final ValueChanged<Player> onVote;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    if (voter == null) {
      return const _EmptyPack();
    }

    final List<Player> targets =
        players.where((Player p) => p.id != voter!.id).toList(growable: false);

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
            flex: 3,
            child: _QuestionCard(prompt: prompt),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'TOUCHE TA RÉPONSE',
            style: context.text.labelMedium?.copyWith(
              color: AppColors.modeJamais,
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
                  for (final Player p in targets)
                    _TargetTile(
                      player: p,
                      currentVotes: votes[p.id] ?? 0,
                      onTap: () => onVote(p),
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

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.prompt});

  final Prompt prompt;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    final bool isAdult = prompt.intensity == Intensity.adulte;
    final int len = prompt.text.length;
    final double size = switch (len) {
      < 45 => 26,
      < 80 => 22,
      < 120 => 19,
      _ => 17,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'QUI POURRAIT…',
                style: context.text.labelMedium?.copyWith(
                  letterSpacing: 4,
                  color: AppColors.modeJamais,
                ),
              ),
              if (isAdult) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                const AdultBadge(),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            prompt.text,
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
    required this.currentVotes,
    required this.onTap,
  });

  final Player player;
  final int currentVotes;
  final VoidCallback onTap;

  @override
  State<_TargetTile> createState() => _TargetTileState();
}

class _TargetTileState extends State<_TargetTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    final Player p = widget.player;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1,
        duration: AppMotion.fast,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _pressed
                ? p.color.withValues(alpha: 0.24)
                : colors.surfaceHigh,
            borderRadius: AppRadii.button,
            border: Border.all(
              color: _pressed
                  ? p.color
                  : colors.borderSoft,
              width: _pressed ? 2 : 1,
            ),
            boxShadow: _pressed
                ? AppShadows.glow(p.color, opacity: 0.30)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AvatarView.fromPlayer(p, size: 34, showRing: false),
              const SizedBox(width: AppSpacing.sm),
              Text(
                p.name,
                style: context.text.titleMedium?.copyWith(
                  fontSize: 16,
                  color: p.color,
                ),
              ),
              if (widget.currentVotes > 0) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: p.color.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    '${widget.currentVotes}',
                    style: context.text.labelMedium?.copyWith(
                      fontSize: 11,
                      letterSpacing: 0,
                      color: p.color,
                    ),
                  ),
                ),
              ],
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
    required this.prompt,
    required this.players,
    required this.votes,
    required this.designated,
    required this.sanction,
    required this.noSips,
  });

  final Prompt prompt;
  final List<Player> players;
  final Map<String, int> votes;
  final List<Player> designated;
  final String sanction;
  final bool noSips;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    final bool tie = designated.length > 1;
    final int maxVotes = designated.isEmpty
        ? 0
        : votes[designated.first.id] ?? 0;

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
          if (designated.isNotEmpty) ...<Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                for (final Player p in designated.take(3))
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    child: _WinnerTile(player: p, votes: votes[p.id] ?? 0),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              tie ? 'Tous concernés' : designated.first.name,
              style: context.text.headlineLarge?.copyWith(
                color: designated.first.color,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              noSips ? 'Désigné par le groupe' : sanction,
              style: context.text.bodyMedium?.copyWith(
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
              itemCount: players.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.xs),
              itemBuilder: (BuildContext context, int index) {
                final Player p = players[index];
                final int count = votes[p.id] ?? 0;
                final bool isDesignated =
                    designated.any((Player d) => d.id == p.id);
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
    ).animate().fadeIn(duration: 380.ms);
  }
}

class _WinnerTile extends StatelessWidget {
  const _WinnerTile({required this.player, required this.votes});

  final Player player;
  final int votes;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: player.color.withValues(alpha: 0.20),
            border: Border.all(color: player.color, width: 2.5),
            boxShadow: AppShadows.glow(player.color, opacity: 0.35),
          ),
          child: AvatarView.fromPlayer(player, size: 66, showRing: false),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          player.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.titleMedium?.copyWith(
            fontSize: 14,
            color: player.color,
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

  final Player player;
  final int votes;
  final int maxVotes;
  final bool isDesignated;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
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
          AvatarView.fromPlayer(player, size: 28, showRing: false),
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
                    isDesignated ? AppColors.warning : player.color,
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
                color: votes > 0 ? player.color : colors.textMuted,
              ),
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