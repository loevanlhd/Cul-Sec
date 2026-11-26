import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AmbientBackground extends StatefulWidget {
  const AmbientBackground({
    super.key,
    required this.child,
    this.primary = AppColors.accent,
    this.secondary,
    this.intensity = 1.0,
    this.animate = true,
  });

  final Widget child;
  final Color primary;
  final Color? secondary;
  final double intensity;
  final bool animate;

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant AmbientBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(gradient: colors.gradientBackground),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (BuildContext context, Widget? child) {
                return CustomPaint(
                  painter: _GlowPainter(
                    progress: _controller.value,
                    primary: widget.primary,
                    secondary: widget.secondary ?? widget.primary,
                    // En mode clair, on réduit l'intensité des lueurs pour éviter de "baver"
                    intensity: widget.intensity * (isDark ? 1.0 : 0.35),
                  ),
                );
              },
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: _GrainOverlay(isDark: isDark),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  _GlowPainter({
    required this.progress,
    required this.primary,
    required this.secondary,
    required this.intensity,
  });

  final double progress;
  final Color primary;
  final Color secondary;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final double t = progress * 2 * math.pi;

    _glow(
      canvas,
      size,
      color: primary,
      cx: 0.5 + 0.13 * math.sin(t),
      cy: -0.02 + 0.05 * math.cos(t * 0.7),
      radius: 1.1,
      opacity: 0.22,
    );

    _glow(
      canvas,
      size,
      color: secondary,
      cx: 0.5 - 0.18 * math.sin(t * 0.8),
      cy: 1.02,
      radius: 0.85,
      opacity: 0.12,
    );
  }

  void _glow(
    Canvas canvas,
    Size size, {
    required Color color,
    required double cx,
    required double cy,
    required double radius,
    required double opacity,
  }) {
    final Offset center = Offset(size.width * cx, size.height * cy);
    final double r = size.shortestSide * radius;
    final double alpha = (opacity * intensity).clamp(0.0, 1.0);

    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
  }

  @override
  bool shouldRepaint(covariant _GlowPainter old) =>
      old.progress != progress ||
      old.intensity != intensity ||
      old.primary != primary ||
      old.secondary != secondary;
}

class _GrainOverlay extends StatelessWidget {
  const _GrainOverlay({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(painter: _GrainPainter(isDark: isDark)),
    );
  }
}

class _GrainPainter extends CustomPainter {
  const _GrainPainter({required this.isDark});

  final bool isDark;

  static final math.Random _random = math.Random(42);
  static const int _dotCount = 700;

  @override
  void paint(Canvas canvas, Size size) {
    final List<Offset> points = <Offset>[
      for (int i = 0; i < _dotCount; i++)
        Offset(
          _random.nextDouble() * size.width,
          _random.nextDouble() * size.height,
        ),
    ];

    canvas.drawPoints(
      PointMode.points,
      points,
      Paint()
        ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.018)
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant _GrainPainter oldDelegate) => oldDelegate.isDark != isDark;
}