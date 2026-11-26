import 'dart:async';
import 'dart:math' as math;

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

enum _Phase { handoff, choosing, flipping, revealed }

class ActionVeriteScreen extends StatefulWidget {
  const ActionVeriteScreen({super.key, required this.mode});

  final GameMode mode;

  @override
  State<ActionVeriteScreen> createState() => _ActionVeriteScreenState();
}

class _ActionVeriteScreenState extends State<ActionVeriteScreen>
    with TickerProviderStateMixin, GameFinishMixin<ActionVeriteScreen> {
  @override
  GameMode get gameMode => widget.mode;

  _Phase _phase = _Phase.handoff;
  PromptKind _kind = PromptKind.action;

  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
  );

  int _streak = 0;
  int _bestStreak = 0;
  int _shake = 0;

  bool _resolving = false;

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  Color get _kindColor => _kind == PromptKind.action
      ? AppColors.modeAction
      : AppColors.modePrefereAlt;

  void _ready() {
    if (_phase != _Phase.handoff) return;
    Haptics.tick();
    setState(() => _phase = _Phase.choosing);
  }

  Future<void> _choose(PromptKind kind) async {
    if (_phase != _Phase.choosing) return;

    Haptics.medium();
    context.read<GameSession>().drawWhere((Prompt p) => p.kind == kind);

    setState(() {
      _kind = kind;
      _phase = _Phase.flipping;
    });

    await _flip.forward(from: 0);
    if (!mounted) return;

    unawaited(Haptics.double());
    setState(() => _phase = _Phase.revealed);
  }

  void _accomplish() {
    if (_phase != _Phase.revealed || _resolving) return;
    final GameSession done = context.read<GameSession>();
    done.bump(
      done.currentPlayer,
      _kind == PromptKind.action ? Stat.gage : Stat.verite,
    );
    Haptics.success();
    setState(() {
      _streak++;
      _bestStreak = math.max(_bestStreak, _streak);
      _phase = _Phase.handoff;
    });
    context.read<GameSession>().advancePlayer();
  }

  void _refuse() {
    if (_phase != _Phase.revealed || _resolving) return;
    final GameSession session = context.read<GameSession>();
    session.recordSips(
      session.currentPlayer,
      session.cappedSips(session.rules.actionRefusal),
    );
    session.bump(session.currentPlayer, Stat.refus);
    Haptics.failure();
    setState(() {
      _streak = 0;
      _shake++;
      _phase = _Phase.handoff;
    });
    session.advancePlayer();
  }

  Future<void> _skip() async {
    if (_phase != _Phase.revealed || _resolving) return;
    _resolving = true;
    try {
      final GameSession session = context.read<GameSession>();
      final bool? drink = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: Text(
            'Une autre carte ?',
            style: dialogContext.text.titleLarge,
          ),
          content: Text(
            'Nouvelle carte : '
            '${session.sanctionLabel(session.rules.actionRedraw)}.',
            style: dialogContext.text.bodyMedium,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                'Tirer · '
                '${session.sanctionLabel(session.rules.actionRedraw)}',
              ),
            ),
          ],
        ),
      );
      if (!mounted || drink != true) return;
      session.recordSips(
        session.currentPlayer,
        session.cappedSips(session.rules.actionRedraw),
      );
      session.bump(session.currentPlayer, Stat.redraw);
      Haptics.tick();
      session.drawWhere((Prompt p) => p.kind == _kind);
      await _flip.forward(from: 0.5);
    } finally {
      _resolving = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final GameSession session = context.watch<GameSession>();
    final Player? player = session.currentPlayer;

    return GameScaffold(
      mode: widget.mode,
      accent: _phase == _Phase.flipping || _phase == _Phase.revealed
          ? _kindColor
          : widget.mode.color,
      onQuit: finishGame,
      bottom: _phase == _Phase.choosing || _phase == _Phase.handoff
          ? null
          : _ResolveBar(
              enabled: _phase == _Phase.revealed,
              color: _kindColor,
              onRefuse: _refuse,
              onSkip: _skip,
              onAccomplish: _accomplish,
              sanction: session.sanctionLabel(
                session.cappedSips(session.rules.actionRefusal),
              ),
              redrawLabel:
                  session.sanctionLabel(session.rules.actionRedraw),
            ),
      child: _phase == _Phase.handoff
          ? _HandoffStage(
              key: ValueKey<String>(
                'handoff-${player?.id ?? 'none'}-${session.turn}',
              ),
              player: player,
              reader: session.nextPlayer,
              color: widget.mode.color,
              onReady: _ready,
            )
          : AnimatedSwitcher(
              duration: AppMotion.base,
              child: _phase == _Phase.choosing
                  ? _ChoiceStage(
                      key: const ValueKey<String>('choice'),
                      player: player,
                      reader: session.nextPlayer,
                      streak: _streak,
                      bestStreak: _bestStreak,
                      shake: _shake,
                      onChoose: _choose,
                    )
                  : _RevealStage(
                      key: const ValueKey<String>('reveal'),
                      flip: _flip,
                      kind: _kind,
                      color: _kindColor,
                      prompt: session.current,
                      player: player,
                    ),
            ),
    );
  }
}

class _HandoffStage extends StatelessWidget {
  const _HandoffStage({
    super.key,
    required this.player,
    required this.reader,
    required this.color,
    required this.onReady,
  });

  final Player? player;
  final Player? reader;
  final Color color;
  final VoidCallback onReady;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.screen,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.phone_android_rounded, size: 54, color: color),
            const SizedBox(height: AppSpacing.lg),
            Text(
              reader == null ? 'À TON TOUR' : 'PASSE LE TÉLÉPHONE À',
              textAlign: TextAlign.center,
              style: context.text.labelMedium?.copyWith(letterSpacing: 2),
            ),
            const SizedBox(height: AppSpacing.md),
            if (reader != null) ...<Widget>[
              AvatarView.fromPlayer(reader!, size: 76),
              const SizedBox(height: AppSpacing.sm),
              Text(
                reader!.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.displaySmall?.copyWith(
                  color: reader!.color,
                ),
              ),
            ],
            if (player != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Pour ${player!.name} : lis la carte à voix haute.',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyMedium,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text(
              'La carte reste cachée jusqu’à ce que le lecteur soit prêt.',
              textAlign: TextAlign.center,
              style: context.text.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Je suis prêt à lire',
              icon: Icons.arrow_forward_rounded,
              color: color,
              onPressed: onReady,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceStage extends StatelessWidget {
  const _ChoiceStage({
    super.key,
    required this.player,
    required this.reader,
    required this.streak,
    required this.bestStreak,
    required this.shake,
    required this.onChoose,
  });

  final Player? player;
  final Player? reader;
  final int streak;
  final int bestStreak;
  final int shake;
  final ValueChanged<PromptKind> onChoose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.screen,
      child: Column(
        children: <Widget>[
          const SizedBox(height: AppSpacing.sm),

          _PlayerBanner(player: player, reader: reader)
              .animate(key: ValueKey<int>(shake))
              .shake(hz: 4, offset: const Offset(6, 0), duration: 420.ms),

          if (streak >= 2) ...<Widget>[
            const SizedBox(height: AppSpacing.sm + 2),
            AppPill(
              color: AppColors.warning,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.local_fire_department_rounded,
                    size: 14,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$streak d’affilée sans se dégonfler',
                    style: context.text.titleMedium?.copyWith(
                      fontSize: 12.5,
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(duration: 240.ms)
                .scaleXY(begin: 0.85, curve: Curves.easeOutBack),
          ],

          const SizedBox(height: AppSpacing.lg),

          Expanded(
            child: _HalfChoice(
              icon: Icons.bolt_rounded,
              title: 'ACTION',
              subtitle: 'Un gage à exécuter, maintenant',
              color: AppColors.modeAction,
              colorAlt: AppColors.modeActionAlt,
              onTap: () => onChoose(PromptKind.action),
            )
                .animate()
                .fadeIn(duration: 320.ms)
                .slideX(begin: -0.12, curve: Curves.easeOutCubic),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: _HalfChoice(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'VÉRITÉ',
              subtitle: 'Une question, une réponse honnête',
              color: AppColors.modePrefereAlt,
              colorAlt: AppColors.modePrefere,
              onTap: () => onChoose(PromptKind.verite),
            )
                .animate()
                .fadeIn(delay: 90.ms, duration: 320.ms)
                .slideX(begin: 0.12, curve: Curves.easeOutCubic),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

class _PlayerBanner extends StatelessWidget {
  const _PlayerBanner({required this.player, required this.reader});

  final Player? player;
  final Player? reader;

  @override
  Widget build(BuildContext context) {
    if (player == null) return const SizedBox.shrink();

    return Column(
      children: <Widget>[
        Text(
          'À ${player!.name.toUpperCase()} DE CHOISIR',
          textAlign: TextAlign.center,
          style: context.text.labelMedium,
        ),
        const SizedBox(height: AppSpacing.sm + 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: AppShadows.glow(player!.color, opacity: 0.22),
              ),
              child: AvatarView.fromPlayer(player!, size: 40),
            ),
            const SizedBox(width: AppSpacing.sm + 4),
            Flexible(
              child: Text(
                player!.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.displaySmall?.copyWith(
                  color: player!.color,
                  fontSize: 30,
                ),
              ),
            ),
          ],
        ),
        if (reader != null && reader!.id != player!.id) ...<Widget>[
          const SizedBox(height: AppSpacing.xs + 2),
          Text(
            '${reader!.name} lit la carte à voix haute',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodySmall?.copyWith(fontSize: 11.5),
          ),
        ],
      ],
    );
  }
}

class _HalfChoice extends StatefulWidget {
  const _HalfChoice({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.colorAlt,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color colorAlt;
  final VoidCallback onTap;

  @override
  State<_HalfChoice> createState() => _HalfChoiceState();
}

class _HalfChoiceState extends State<_HalfChoice>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ripple = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 540),
  );

  Offset _origin = Offset.zero;
  bool _pressed = false;

  @override
  void dispose() {
    _ripple.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails d) {
    setState(() {
      _origin = d.localPosition;
      _pressed = true;
    });
    Haptics.light();
    _ripple.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapDown,
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1,
        duration: AppMotion.fast,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: AppRadii.bigCard,
            boxShadow: _pressed
                ? AppShadows.glow(widget.color, opacity: 0.35)
                : AppShadows.card,
          ),
          child: ClipRRect(
            borderRadius: AppRadii.bigCard,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        Color.lerp(colors.surface, widget.color, 0.22)!,
                        Color.lerp(colors.surface, widget.colorAlt, 0.08)!,
                      ],
                    ),
                  ),
                ),

                AnimatedBuilder(
                  animation: _ripple,
                  builder: (BuildContext context, Widget? child) {
                    if (_ripple.value == 0) return const SizedBox.shrink();
                    return CustomPaint(
                      painter: _RipplePainter(
                        origin: _origin,
                        progress: _ripple.value,
                        color: widget.color,
                      ),
                    );
                  },
                ),

                Positioned(
                  right: -18,
                  bottom: -22,
                  child: Icon(
                    widget.icon,
                    size: 118,
                    color: widget.color.withValues(alpha: 0.12),
                  ),
                ),

                AnimatedContainer(
                  duration: AppMotion.fast,
                  decoration: BoxDecoration(
                    borderRadius: AppRadii.bigCard,
                    border: Border.all(
                      color: _pressed
                          ? widget.color
                          : widget.color.withValues(alpha: 0.32),
                      width: _pressed ? 2 : 1.2,
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: widget.color.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(AppRadii.sm + 2),
                        ),
                        child:
                            Icon(widget.icon, size: 21, color: widget.color),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        widget.title,
                        style: context.text.displaySmall?.copyWith(
                          letterSpacing: 1.5,
                          color: colors.textOnAccent, // <-- Modifié (était Colors.white)
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        widget.subtitle,
                        style: context.text.bodyMedium?.copyWith(
                          color: colors.textOnAccent.withValues(alpha: 0.8), // <-- Modifié
                        ),
                      ),
                    ],
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

class _RipplePainter extends CustomPainter {
  _RipplePainter({
    required this.origin,
    required this.progress,
    required this.color,
  });

  final Offset origin;
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double t = Curves.easeOut.transform(progress);
    final double radius = size.longestSide * 1.15 * t;
    final double alpha = (1 - t) * 0.30;

    canvas.drawCircle(
      origin,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: origin, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(covariant _RipplePainter old) =>
      old.progress != progress || old.origin != origin;
}

class _RevealStage extends StatelessWidget {
  const _RevealStage({
    super.key,
    required this.flip,
    required this.kind,
    required this.color,
    required this.prompt,
    required this.player,
  });

  final AnimationController flip;
  final PromptKind kind;
  final Color color;
  final Prompt? prompt;
  final Player? player;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    if (prompt == null) {
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
              const SizedBox(height: AppSpacing.md),
              Text(
                'Aucune carte de ce type à ce niveau d’intensité.',
                textAlign: TextAlign.center,
                style: context.text.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: AppSpacing.screen.copyWith(bottom: AppSpacing.sm),
      child: AnimatedBuilder(
        animation: flip,
        builder: (BuildContext context, Widget? child) {
          final double t = Curves.easeInOutCubic.transform(flip.value);
          final double angle = t * math.pi;
          final bool showBack = angle < math.pi / 2;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0013)
              ..rotateY(angle),
            child: showBack
                ? _CardBack(kind: kind, color: color)
                : Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: _CardFace(
                      kind: kind,
                      color: color,
                      prompt: prompt!,
                      player: player,
                    ),
                  ),
          );
        },
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack({required this.kind, required this.color});

  final PromptKind kind;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color.lerp(colors.surface, color, 0.26)!,
            colors.surface,
          ],
        ),
        borderRadius: AppRadii.bigCard,
        border: Border.all(color: color.withValues(alpha: 0.45), width: 1.4),
        boxShadow: AppShadows.raised,
      ),
      child: Center(
        child: Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withValues(alpha: 0.45),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Icon(
              kind == PromptKind.action
                  ? Icons.bolt_rounded
                  : Icons.chat_bubble_outline_rounded,
              size: 40,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({
    required this.kind,
    required this.color,
    required this.prompt,
    required this.player,
  });

  final PromptKind kind;
  final Color color;
  final Prompt prompt;
  final Player? player;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    final bool isAction = kind == PromptKind.action;
    final bool isAdult = prompt.intensity == Intensity.adulte;

    final int len = prompt.text.length;
    final double size = switch (len) {
      < 50 => 34,
      < 95 => 28,
      < 150 => 23,
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
            Color.lerp(colors.surface, color, 0.14)!,
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
              if (isAdult) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                const AdultBadge(),
              ],
            ],
          ),

          const Spacer(),

          Text(
            prompt.text,
            textAlign: TextAlign.center,
            style: context.text.displayMedium?.copyWith(
              fontSize: size,
              height: 1.25,
              color: colors.textPrimary, // <-- Modifié (sur fond de carte)
            ),
          )
              .animate()
              .fadeIn(delay: 60.ms, duration: 340.ms)
              .slideY(begin: 0.12, curve: Curves.easeOutCubic),

          const Spacer(),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.fill,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      prompt.category.icon,
                      size: 12,
                      color: colors.textMuted,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      prompt.category.label,
                      style: context.text.bodySmall?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (player != null) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                AvatarView.fromPlayer(
                  player!,
                  size: 18,
                  showRing: false,
                ),
                const SizedBox(width: 5),
                Text(
                  player!.name.toUpperCase(),
                  style: context.text.labelMedium?.copyWith(
                    fontSize: 10,
                    color: player!.color,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ResolveBar extends StatelessWidget {
  const _ResolveBar({
    required this.enabled,
    required this.color,
    required this.onRefuse,
    required this.onSkip,
    required this.onAccomplish,
    required this.sanction,
    required this.redrawLabel,
  });

  final bool enabled;
  final Color color;
  final VoidCallback onRefuse;
  final VoidCallback onSkip;
  final VoidCallback onAccomplish;
  final String sanction;
  final String redrawLabel;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: AppMotion.base,
      opacity: enabled ? 1 : 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: enabled ? onRefuse : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.warning,
                    backgroundColor: AppColors.warning.withValues(alpha: 0.12),
                    side: BorderSide(
                      color: AppColors.warning.withValues(alpha: 0.65),
                    ),
                    minimumSize: const Size.fromHeight(56),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadii.button,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Icon(Icons.local_bar_outlined, size: 17),
                      const SizedBox(width: 5),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            sanction == '0 gorgées'
                                ? 'Refuser · 0 gorgée'
                                : 'Je bois · $sanction',
                            maxLines: 1,
                            style: context.text.titleMedium?.copyWith(
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: AppButton(
                  label: 'Fait !',
                  icon: Icons.check_rounded,
                  color: color,
                  onPressed: enabled ? onAccomplish : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton.icon(
            onPressed: enabled ? onSkip : null,
            icon: const Icon(Icons.refresh_rounded, size: 15),
            label: Text('Autre carte · $redrawLabel'),
          ),
        ],
      ),
    );
  }
}