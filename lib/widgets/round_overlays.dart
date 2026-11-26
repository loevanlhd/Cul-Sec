import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/game_mode.dart';
import '../models/player.dart';
import '../services/game_session.dart';
import '../services/haptics.dart';
import '../services/round_events.dart';
import '../services/sounds.dart';
import '../theme/app_theme.dart';
import 'avatar_view.dart';
import 'common.dart';
import 'dart:async';

/// Transition commune aux surcouches : fondu + léger zoom.
Widget _popTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondary,
  Widget child,
) {
  final Animation<double> curved =
      CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
  return FadeTransition(
    opacity: animation,
    child: ScaleTransition(
      scale: Tween<double>(begin: 0.85, end: 1).animate(curved),
      child: child,
    ),
  );
}

// ---------------------------------------------------------------------------
// Carte Événement
// ---------------------------------------------------------------------------

Future<void> showEventDialog(
  BuildContext context,
  GameSession session,
  RoundEvent event,
) {
  Haptics.heavy();
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Événement',
    barrierColor: Colors.black.withValues(alpha: 0.72),
    transitionDuration: const Duration(milliseconds: 380),
    transitionBuilder: _popTransition,
    pageBuilder: (_, __, ___) => PopScope(
      canPop: false,
      child: _EventCard(session: session, event: event),
    ),
  );
}

class _EventCard extends StatefulWidget {
  const _EventCard({required this.session, required this.event});

  final GameSession session;
  final RoundEvent event;

  @override
  State<_EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<_EventCard> {
  Player? _loser;

  void _close() {
    final RoundEvent event = widget.event;
    event.apply(widget.session, loser: _loser);
    if (event.drinkers.isNotEmpty || _loser != null) {
      Haptics.triple();
    } else {
      Haptics.light();
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    final RoundEvent event = widget.event;
    final GameSession session = widget.session;

    final String button;
    if (event.needsLoser) {
      button = _loser == null
          ? 'Personne · continuer'
          : '${_loser!.name} boit ${session.sanctionLabel(event.sips)}';
    } else if (event.drinkers.isNotEmpty) {
      button = 'Santé !';
    } else {
      button = 'C’est noté';
    }

    return SafeArea(
      child: Center(
        child: Padding(
          padding: AppSpacing.screen,
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Color.lerp(colors.surface, event.color, 0.28)!,
                    colors.surface,
                  ],
                ),
                borderRadius: AppRadii.bigCard,
                border: Border.all(color: event.color, width: 1.6),
                boxShadow: AppShadows.glow(event.color, opacity: 0.4),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'ÉVÉNEMENT',
                    style: context.text.labelMedium?.copyWith(
                      letterSpacing: 5,
                      color: event.color,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(event.emoji, style: const TextStyle(fontSize: 64))
                      .animate(onPlay: (AnimationController c) => c.repeat())
                      .shake(hz: 2, rotation: 0.06, duration: 1200.ms)
                      .then(delay: 600.ms),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    event.title,
                    textAlign: TextAlign.center,
                    style: context.text.headlineLarge?.copyWith(
                      color: event.color,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    event.text,
                    textAlign: TextAlign.center,
                    style: context.text.bodyLarge?.copyWith(
                      color: colors.textPrimary, // <-- Correction ici
                      height: 1.35,
                    ),
                  ),
                  if (event.drinkers.isNotEmpty && event.sips > 0) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        for (final Player p in event.drinkers)
                          AvatarView.fromPlayer(p, size: 34, showRing: false),
                      ],
                    ),
                  ],
                  if (event.needsLoser) ...<Widget>[
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      (event.loserQuestion ?? 'Qui a perdu ?').toUpperCase(),
                      style: context.text.labelMedium?.copyWith(
                        color: event.color,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 180),
                      child: SingleChildScrollView(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: <Widget>[
                            for (final Player p in event.loserCandidates)
                              _LoserChip(
                                player: p,
                                selected: _loser?.id == p.id,
                                onTap: () {
                                  Haptics.tick();
                                  setState(() => _loser =
                                      _loser?.id == p.id ? null : p,);
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: button,
                    icon: Icons.arrow_forward_rounded,
                    color: event.color,
                    onPressed: _close,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoserChip extends StatelessWidget {
  const _LoserChip({
    required this.player,
    required this.selected,
    required this.onTap,
  });

  final Player player;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    return Pressable(
      onTap: onTap,
      scale: 0.93,
      child: AnimatedContainer(
        duration: AppMotion.base,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? player.color.withValues(alpha: 0.22)
              : colors.fill,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: selected ? player.color : colors.borderSoft,
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AvatarView.fromPlayer(player, size: 22, showRing: false),
            const SizedBox(width: 7),
            Text(
              player.name,
              style: context.text.titleMedium?.copyWith(
                fontSize: 14,
                color: selected ? player.color : colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Roulette du multi-jeu
// ---------------------------------------------------------------------------

Future<void> showRouletteDialog(
  BuildContext context, {
  required List<GameMode> modes,
  required GameMode target,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Roulette',
    barrierColor: Colors.black.withValues(alpha: 0.78),
    transitionDuration: const Duration(milliseconds: 300),
    transitionBuilder: _popTransition,
    pageBuilder: (_, __, ___) => PopScope(
      canPop: false,
      child: _Roulette(modes: modes, target: target),
    ),
  );
}

class _Roulette extends StatefulWidget {
  const _Roulette({required this.modes, required this.target});

  final List<GameMode> modes;
  final GameMode target;

  @override
  State<_Roulette> createState() => _RouletteState();
}

class _RouletteState extends State<_Roulette>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  late final double _endAngle;
  late final Animation<double> _angle;
  int _lastSegment = -1;
  bool _landed = false;

  int get _count => widget.modes.length;
  double get _segment => 2 * math.pi / _count;

  @override
  void initState() {
    super.initState();
    final math.Random random = math.Random();
    final int index =
        widget.modes.indexWhere((GameMode m) => m.id == widget.target.id);
    final double base = (-index * _segment) % (2 * math.pi);
    final double jitter = (random.nextDouble() - 0.5) * _segment * 0.6;
    _endAngle = 2 * math.pi * 5 + base + jitter;
    _angle = Tween<double>(begin: 0, end: _endAngle).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.addListener(_onTick);
    _spin();
  }

  void _onTick() {
    final int seg = ((_angle.value + _segment / 2) / _segment).floor();
    if (seg != _lastSegment) {
      _lastSegment = seg;
      Haptics.tick();
    }
  }

  Future<void> _spin() async {
    await _controller.forward();
    if (!mounted) return;
    unawaited(Haptics.double(sound: Sfx.land));
    setState(() => _landed = true);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    final GameMode target = widget.target;

    return SafeArea(
      child: Material(
        type: MaterialType.transparency,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'PROCHAIN JEU',
                style: context.text.labelMedium?.copyWith(letterSpacing: 5),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: 280,
                height: 300,
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: <Widget>[
                    Positioned(
                      top: 20,
                      child: AnimatedBuilder(
                        animation: _angle,
                        builder: (BuildContext context, Widget? child) =>
                            Transform.rotate(
                          angle: _angle.value,
                          child: child,
                        ),
                        child: CustomPaint(
                          size: const Size(280, 280),
                          painter: _WheelPainter(
                            modes: widget.modes,
                            borderColor: colors.ink,
                          ),
                        ),
                      ),
                    ),
                    const Positioned(
                      top: 0,
                      child: Icon(
                        Icons.arrow_drop_down_rounded,
                        size: 54,
                        color: Colors.white,
                        shadows: <Shadow>[
                          Shadow(color: Colors.black54, blurRadius: 8),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 20 + 140 - 26,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.surfaceTop,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.85),
                            width: 3,
                          ),
                        ),
                        child: Icon(
                          Icons.shuffle_rounded,
                          size: 24,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                height: 44,
                child: AnimatedSwitcher(
                  duration: AppMotion.base,
                  child: _landed
                      ? Row(
                          key: const ValueKey<String>('landed'),
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(target.icon, color: target.color, size: 26),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              target.title,
                              style: context.text.headlineMedium?.copyWith(
                                color: target.color,
                              ),
                            ),
                          ],
                        )
                          .animate()
                          .scaleXY(begin: 0.6, curve: Curves.easeOutBack)
                      : Text(
                          'Ça tourne…',
                          key: const ValueKey<String>('spin'),
                          style: context.text.titleLarge?.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({required this.modes, required this.borderColor});

  final List<GameMode> modes;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.width / 2;
    final double seg = 2 * math.pi / modes.length;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    for (int i = 0; i < modes.length; i++) {
      final GameMode mode = modes[i];
      final double start = -math.pi / 2 + i * seg - seg / 2;

      final Paint fill = Paint()
        ..shader = RadialGradient(
          colors: <Color>[mode.colorAlt, mode.color],
        ).createShader(rect);
      canvas.drawArc(rect, start, seg, true, fill);

      final Paint border = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = borderColor;
      canvas.drawArc(rect, start, seg, true, border);

      final double mid = start + seg / 2;
      final Offset at = center +
          Offset(math.cos(mid), math.sin(mid)) * (radius * 0.62);
      final TextPainter icon = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(mode.icon.codePoint),
          style: TextStyle(
            fontFamily: mode.icon.fontFamily,
            package: mode.icon.fontPackage,
            fontSize: 38,
            color: Colors.white,
            shadows: const <Shadow>[
              Shadow(color: Colors.black38, blurRadius: 6),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(mid + math.pi / 2);
      icon.paint(canvas, Offset(-icon.width / 2, -icon.height / 2));
      canvas.restore();
    }

    canvas.drawCircle(
      center,
      radius - 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = Colors.white.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(covariant _WheelPainter old) =>
      old.modes != modes || old.borderColor != borderColor;
}