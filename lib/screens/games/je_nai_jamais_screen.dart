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

class JeNaiJamaisScreen extends StatefulWidget {
  const JeNaiJamaisScreen({super.key, required this.mode});

  final GameMode mode;

  @override
  State<JeNaiJamaisScreen> createState() => _JeNaiJamaisScreenState();
}

class _JeNaiJamaisScreenState extends State<JeNaiJamaisScreen>
    with GameFinishMixin<JeNaiJamaisScreen> {
  @override
  GameMode get gameMode => widget.mode;

  final Set<String> _guilty = <String>{};
  int _cardKey = 0;
  bool _advancing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<GameSession>().next();
    });
  }

  void _toggleGuilty(Player player) {
    if (_advancing) return;
    setState(() {
      if (_guilty.contains(player.id)) {
        _guilty.remove(player.id);
        Haptics.tick();
      } else {
        _guilty.add(player.id);
        Haptics.medium();
      }
    });
  }

  Future<void> _next() async {
    if (_advancing) return;
    setState(() => _advancing = true);
    try {
      final GameSession session = context.read<GameSession>();
      final List<Player> targets = session.players
          .where((Player p) => _guilty.contains(p.id))
          .toList();

      if (targets.isNotEmpty) {
        session.bumpAll(targets, Stat.jamais);
        session.recordSipsForAll(targets, session.rules.jamaisConcerned);
        await Haptics.triple();
      } else {
        Haptics.light();
      }
      if (!mounted) return;

      setState(() {
        _guilty.clear();
        _cardKey++;
      });
      session.next();
    } finally {
      if (mounted) setState(() => _advancing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final GameSession session = context.watch<GameSession>();
    final Prompt? prompt = session.current;
    final List<Player> players = session.players;

    return GameScaffold(
      mode: widget.mode,
      onQuit: finishGame,
      bottom: AppButton(
        label: _guilty.isEmpty
            ? 'Personne ? Carte suivante'
            : session.rules.jamaisConcerned == 0
                ? '${_guilty.length} concernés · suivante'
                : '${_guilty.length} ${_guilty.length > 1 ? "boivent" : "boit"} '
                    '${session.sanctionLabel(session.rules.jamaisConcerned)} · suivante',
        icon: Icons.arrow_forward_rounded,
        color: widget.mode.color,
        onPressed: _advancing ? null : _next,
      ),
      child: prompt == null
          ? const _EmptyPack()
          : Padding(
              padding: AppSpacing.screen,
              child: Column(
                children: <Widget>[
                  Expanded(
                    flex: 5,
                    child: _StatementCard(
                      key: ValueKey<int>(_cardKey),
                      prompt: prompt,
                      mode: widget.mode,
                      guiltyCount: _guilty.length,
                      totalPlayers: players.length,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'COCHEZ CEUX QUI L’ONT DÉJÀ FAIT',
                    textAlign: TextAlign.center,
                    style: context.text.labelMedium?.copyWith(
                      color: widget.mode.color,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Touchez un prénom pour cocher ou décocher.',
                    textAlign: TextAlign.center,
                    style: context.text.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.sm + 2),
                  Expanded(
                    flex: 3,
                    child: SingleChildScrollView(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: <Widget>[
                          for (int i = 0; i < players.length; i++)
                            _GuiltyChip(
                              key: ValueKey<String>(players[i].id),
                              player: players[i],
                              guilty: _guilty.contains(players[i].id),
                              onTap: () => _toggleGuilty(players[i]),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _StatementCard extends StatelessWidget {
  const _StatementCard({
    super.key,
    required this.prompt,
    required this.mode,
    required this.guiltyCount,
    required this.totalPlayers,
  });

  final Prompt prompt;
  final GameMode mode;
  final int guiltyCount;
  final int totalPlayers;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    final bool isAdult = prompt.intensity == Intensity.adulte;

    final int len = prompt.text.length;
    final double size = switch (len) {
      < 45 => 33,
      < 80 => 28,
      < 120 => 23,
      _ => 20,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color.lerp(colors.surface, mode.color, 0.16)!,
            colors.surface,
          ],
        ),
        borderRadius: AppRadii.bigCard,
        border: Border.all(
          color: mode.color.withValues(alpha: 0.38),
          width: 1.4,
        ),
        boxShadow: AppShadows.raised,
      ),
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                prompt.category.icon,
                size: 13,
                color: mode.color.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 6),
              Text(
                prompt.category.label.toUpperCase(),
                style: context.text.labelMedium?.copyWith(
                  fontSize: 10,
                  color: mode.color.withValues(alpha: 0.8),
                ),
              ),
              if (isAdult) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                const AdultBadge(),
              ],
            ],
          ),

          const Spacer(),

          Text(
            'JE N’AI JAMAIS',
            style: context.text.labelMedium?.copyWith(
              letterSpacing: 5,
              color: colors.textSecondary, // <-- Modifié
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          Text(
            prompt.text,
            textAlign: TextAlign.center,
            style: context.text.displayMedium?.copyWith(
              fontSize: size,
              height: 1.25,
              color: colors.textPrimary, // <-- Modifié
            ),
          )
              .animate()
              .fadeIn(duration: 340.ms)
              .slideY(begin: 0.1, curve: Curves.easeOutCubic),

          const Spacer(),

          AnimatedSwitcher(
            duration: AppMotion.base,
            child: guiltyCount == 0
                ? Text(
                    'personne pour l’instant…',
                    key: const ValueKey<String>('none'),
                    style: context.text.bodySmall?.copyWith(fontSize: 12),
                  )
                : Row(
                    key: ValueKey<int>(guiltyCount),
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(
                        Icons.local_bar_rounded,
                        size: 16,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        '$guiltyCount sur $totalPlayers',
                        style: context.text.titleLarge?.copyWith(
                          color: AppColors.warning,
                          fontSize: 17,
                        ),
                      ),
                    ],
                  ).animate().scaleXY(begin: 0.8, curve: Curves.easeOutBack),
          ),
        ],
      ),
    );
  }
}

class _GuiltyChip extends StatelessWidget {
  const _GuiltyChip({
    super.key,
    required this.player,
    required this.guilty,
    required this.onTap,
  });

  final Player player;
  final bool guilty;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    return Pressable(
      onTap: onTap,
      scale: 0.93,
      child: AnimatedContainer(
        duration: AppMotion.base,
        curve: AppMotion.emphasized,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color:
              guilty ? player.color.withValues(alpha: 0.22) : colors.fill,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: guilty ? player.color : colors.borderSoft,
            width: guilty ? 1.8 : 1,
          ),
          boxShadow:
              guilty ? AppShadows.glow(player.color, opacity: 0.30) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AnimatedScale(
              duration: AppMotion.base,
              curve: AppMotion.overshoot,
              scale: guilty ? 1.15 : 1,
              child: AvatarView.fromPlayer(
                player,
                size: 22,
                showRing: false,
              ),
            ),
            const SizedBox(width: 7),
            AnimatedDefaultTextStyle(
              duration: AppMotion.base,
              style: context.text.titleMedium!.copyWith(
                fontSize: 14,
                color: guilty ? player.color : colors.textSecondary,
                fontWeight: guilty ? FontWeight.w700 : FontWeight.w500,
              ),
              child: Text(player.name),
            ),
            if (guilty) ...<Widget>[
              const SizedBox(width: 6),
              Icon(Icons.local_bar_rounded, size: 13, color: player.color),
            ],
          ],
        ),
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