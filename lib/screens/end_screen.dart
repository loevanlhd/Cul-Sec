import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../models/game_mode.dart';
import '../models/player.dart';
import '../services/app_state.dart';
import '../services/badges.dart';
import '../services/game_session.dart';
import '../services/haptics.dart';
import '../services/sounds.dart';
import '../theme/app_theme.dart';
import '../widgets/ambient_background.dart';
import '../widgets/avatar_view.dart';
import '../widgets/common.dart';
import '../widgets/share_recap.dart';

class EndScreen extends StatefulWidget {
  const EndScreen({
    super.key,
    required this.mode,
    required this.session,
    required this.onReplay,
  });

  final GameMode mode;
  final GameSession session;
  final VoidCallback onReplay;

  @override
  State<EndScreen> createState() => _EndScreenState();
}

class _EndScreenState extends State<EndScreen> {
  late final List<EveningBadge> _badges = computeBadges(widget.session);

  @override
  void initState() {
    super.initState();
    widget.session.score.onChanged = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final AppState state = context.read<AppState>();
      state.clearSavedGame();
      state.mergeSessionStats(widget.session.sips);
      Haptics.triple(sound: Sfx.fanfare);
    });
  }

  @override
  Widget build(BuildContext context) {
    final GameSession session = widget.session;
    final Player? thirstiest = session.thirstiest;

    final List<Player> ranked = List<Player>.from(session.players)
      ..sort(
        (Player a, Player b) => session.sipsOf(b).compareTo(session.sipsOf(a)),
      );

    final int maxSips =
        ranked.isEmpty ? 0 : math.max(1, session.sipsOf(ranked.first));

    return Scaffold(
      body: AmbientBackground(
        primary: widget.mode.color,
        secondary: widget.mode.colorAlt,
        intensity: 1.2,
        child: Stack(
          children: <Widget>[
            const Positioned.fill(child: _ConfettiLayer()),
            SafeArea(
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: ListView(
                      padding: AppSpacing.screen.copyWith(
                        top: AppSpacing.xl,
                        bottom: AppSpacing.md,
                      ),
                      children: <Widget>[
                        Center(
                          child: Column(
                            children: <Widget>[
                              Text(
                                'FIN DE PARTIE',
                                style: context.text.labelMedium,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                widget.mode.title,
                                textAlign: TextAlign.center,
                                style: context.text.displaySmall?.copyWith(
                                  color: widget.mode.color,
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(duration: 400.ms).slideY(
                              begin: -0.1,
                            ),

                        const SizedBox(height: AppSpacing.xl),

                        Row(
                          children: <Widget>[
                            Expanded(
                              child: _StatBox(
                                value: '${session.turn}',
                                label: 'tours',
                                color: widget.mode.color,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm + 2),
                            Expanded(
                              child: _StatBox(
                                value: _formatDuration(session.elapsed),
                                label: 'de soirée',
                                color: AppColors.accentSoft,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm + 2),
                            Expanded(
                              child: _StatBox(
                                value: '${session.totalSips}',
                                label: 'gorgées',
                                color: AppColors.warning,
                              ),
                            ),
                          ],
                        )
                            .animate()
                            .fadeIn(delay: 140.ms, duration: 400.ms)
                            .slideY(begin: 0.12),

                        if (thirstiest != null) ...<Widget>[
                          const SizedBox(height: AppSpacing.lg),
                          _AwardCard(
                            player: thirstiest,
                            sips: session.sipsOf(thirstiest),
                          )
                              .animate()
                              .fadeIn(delay: 280.ms, duration: 420.ms)
                              .scaleXY(begin: 0.9, curve: Curves.easeOutBack),
                        ],

                        if (_badges.isNotEmpty) ...<Widget>[
                          const SizedBox(height: AppSpacing.xl),
                          SectionTitle(
                            'BADGES DE LA SOIRÉE',
                            trailing: '${_badges.length}',
                          ),
                          LayoutBuilder(
                            builder: (BuildContext context, BoxConstraints c) =>
                                Wrap(
                            spacing: AppSpacing.sm + 2,
                            runSpacing: AppSpacing.sm + 2,
                            children: <Widget>[
                              for (int i = 0; i < _badges.length; i++)
                                SizedBox(
                                  width: (c.maxWidth - AppSpacing.sm - 2) / 2,
                                  child: _BadgeTile(badge: _badges[i])
                                      .animate()
                                      .fadeIn(
                                        delay: (340 + i * 80).ms,
                                        duration: 360.ms,
                                      )
                                      .scaleXY(
                                        begin: 0.85,
                                        curve: Curves.easeOutBack,
                                      ),
                                ),
                            ],
                          ),
                          ),
                        ],

                        if (ranked.isNotEmpty) ...<Widget>[
                          const SizedBox(height: AppSpacing.xl),
                          const SectionTitle('CLASSEMENT'),
                          for (int i = 0; i < ranked.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.sm + 2,
                              ),
                              child: _RankRow(
                                rank: i + 1,
                                player: ranked[i],
                                sips: session.sipsOf(ranked[i]),
                                maxSips: maxSips,
                              )
                                  .animate()
                                  .fadeIn(
                                    delay: (420 + i * 70).ms,
                                    duration: 340.ms,
                                  )
                                  .slideX(begin: 0.1),
                            ),
                        ],

                        const SizedBox(height: AppSpacing.lg),
                        Center(
                          child: Text(
                            'Pensez au retour : taxi, VTC ou conducteur '
                            'désigné.',
                            textAlign: TextAlign.center,
                            style: context.text.bodySmall
                                ?.copyWith(fontSize: 11.5),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: AppSpacing.screen.copyWith(
                      top: AppSpacing.sm,
                      bottom: AppSpacing.md,
                    ),
                    child: Column(
                      children: <Widget>[
                        AppButton(
                          label: 'Une autre manche',
                          icon: Icons.replay_rounded,
                          color: widget.mode.color,
                          onPressed: () {
                            Haptics.medium();
                            widget.onReplay();
                          },
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AppButton(
                          label: 'Partager le récap',
                          icon: Icons.ios_share_rounded,
                          primary: false,
                          color: widget.mode.color,
                          onPressed: () => showShareRecap(
                            context,
                            mode: widget.mode,
                            session: widget.session,
                            badges: _badges,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context)
                              .popUntil((Route<void> r) => r.isFirst),
                          child: const Text('Retour à l’accueil'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours} h ${d.inMinutes % 60}';
    if (d.inMinutes > 0) return '${d.inMinutes} min';
    return '${d.inSeconds} s';
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        children: <Widget>[
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.headlineMedium?.copyWith(color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: context.text.bodySmall?.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _AwardCard extends StatelessWidget {
  const _AwardCard({required this.player, required this.sips});

  final Player player;
  final int sips;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      accent: player.color,
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      child: Row(
        children: <Widget>[
          AvatarView.fromPlayer(player, size: 52),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.emoji_events_rounded,
                      size: 13,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'LE PLUS ASSOIFFÉ',
                      style: context.text.labelMedium?.copyWith(
                        fontSize: 10,
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  player.name,
                  style: context.text.headlineMedium?.copyWith(
                    color: player.color,
                  ),
                ),
                Text(
                  player.noDrink
                      ? '$sips points en gages'
                      : '$sips gorgées au compteur',
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge});

  final EveningBadge badge;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      accent: badge.color,
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(badge.emoji, style: const TextStyle(fontSize: 26)),
              const Spacer(),
              AvatarView.fromPlayer(badge.player, size: 26, showRing: false),
            ],
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          Text(
            badge.title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelMedium?.copyWith(
              fontSize: 10,
              color: badge.color,
            ),
          ),
          Text(
            badge.player.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.titleMedium?.copyWith(
              color: badge.player.color,
            ),
          ),
          Text(
            badge.detail,
            maxLines: 2,
            style: context.text.bodySmall?.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.rank,
    required this.player,
    required this.sips,
    required this.maxSips,
  });

  final int rank;
  final Player player;
  final int sips;
  final int maxSips;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    return Row(
      children: <Widget>[
        SizedBox(
          width: 22,
          child: Text(
            '$rank',
            style: context.text.labelMedium?.copyWith(
              fontSize: 12,
              letterSpacing: 0,
              color: colors.textMuted,
            ),
          ),
        ),
        AvatarView.fromPlayer(player, size: 22, showRing: false),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 82,
          child: Text(
            player.noDrink ? '${player.name} 💪' : player.name,
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
              tween: Tween<double>(begin: 0, end: sips / maxSips),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (BuildContext context, double v, Widget? child) {
                return LinearProgressIndicator(
                  value: v,
                  minHeight: 7,
                  backgroundColor: colors.fill,
                  valueColor: AlwaysStoppedAnimation<Color>(player.color),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 26,
          child: Text(
            '$sips',
            textAlign: TextAlign.right,
            style: context.text.titleMedium?.copyWith(
              fontSize: 13,
              color: sips == 0 ? colors.textMuted : player.color,
            ),
          ),
        ),
      ],
    );
  }
}

class _ConfettiLayer extends StatefulWidget {
  const _ConfettiLayer();

  @override
  State<_ConfettiLayer> createState() => _ConfettiLayerState();
}

class _ConfettiLayerState extends State<_ConfettiLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? child) {
            return CustomPaint(
              painter: _ConfettiPainter(progress: _controller.value),
              size: Size.infinite,
            );
          },
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.progress});

  final double progress;

  static const int _count = 34;
  static const List<Color> _palette = <Color>[
    AppColors.accent,
    AppColors.accentSoft,
    AppColors.warning,
    AppColors.modePrefere,
    AppColors.modeAction,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint();

    for (int i = 0; i < _count; i++) {
      final double seed = (i * 7919 % 1000) / 1000;
      final double speed = 0.6 + seed * 0.8;
      final double t = (progress * speed + seed) % 1.0;

      final double x = size.width * seed + math.sin(t * math.pi * 2 + i) * 28;
      final double y = -20 + (size.height + 40) * t;

      paint.color = _palette[i % _palette.length]
          .withValues(alpha: 0.55 * (1 - t).clamp(0.0, 1.0));

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * math.pi * 6 + i);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-3, -6, 6, 12),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) =>
      old.progress != progress;
}