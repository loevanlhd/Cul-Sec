import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../data/game_modes_catalog.dart';
import '../models/enums.dart';
import '../models/game_mode.dart';
import '../models/prompt.dart';
import '../services/app_state.dart';
import '../services/content_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ambient_background.dart';
import 'age_gate_screen.dart';
import 'home_screen.dart';
import 'multi_jeu_screen.dart';

const Duration _splashDuration = Duration(milliseconds: 3600);

const List<String> _tips = <String>[
  'Le Multi-jeu change de jeu à chaque manche, avec la roulette.',
  'Les cartes Événement tombent par surprise entre deux manches.',
  'Fin de partie : découvrez les badges de chacun.',
  'Partagez le récap de la soirée dans le groupe, en image.',
  'Une partie interrompue ? Elle vous attend au prochain lancement.',
  'Écrivez vos propres cartes dans les réglages, rubrique Mes cartes.',
  'Touchez l’intensité en pleine partie pour monter d’un cran.',
  'Les sanctions se règlent dans les réglages, de 0 à 5 gorgées.',
  'Les cartes déjà vues reviennent chaque jour à midi.',
  'Pensez à l’eau entre deux verres : le lendemain vous dira merci.',
];

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _navigating = false;

  late final String _tip = _tips[math.Random().nextInt(_tips.length)];

  late final Future<void> _content = ContentService.instance.preloadAll();

  @override
  void initState() {
    super.initState();
    _scheduleNavigation();
  }

  Future<void> _scheduleNavigation() async {
    await Future.wait<void>(<Future<void>>[
      _content,
      Future<void>.delayed(_splashDuration),
    ]);
    if (mounted) _navigate();
  }

  void _navigate() {
    if (!mounted || _navigating) return;
    _navigating = true;
    final bool confirmed = context.read<AppState>().isAgeConfirmed;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: AppMotion.slow,
        pageBuilder: (_, __, ___) =>
            confirmed ? const HomeScreen() : const AgeGateScreen(),
        transitionsBuilder: (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondary,
          Widget child,
        ) =>
            FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: AppMotion.enter),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _navigate,
        child: AmbientBackground(
          primary: AppColors.accent,
          secondary: AppColors.modePrefere,
          intensity: 1.35,
          child: SafeArea(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double width =
                    constraints.maxWidth - AppSpacing.lg * 2;
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  child: Column(
                    children: <Widget>[
                      _SplashHeader(onSkip: _navigate),
                      const Expanded(
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: _SplashHero(),
                          ),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: constraints.maxHeight * 0.68,
                        ),
                        child: IgnorePointer(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.bottomCenter,
                            child: SizedBox(
                              width: width,
                              child: _SplashFooter(
                                tip: _tip,
                                content: _content,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SplashHeader extends StatelessWidget {
  const _SplashHeader({required this.onSkip});

  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colors.surfaceHigh.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.accentSoft,
                size: 15,
              ),
              const SizedBox(width: 7),
              Text(
                'LA SOIRÉE COMMENCE',
                style: context.text.labelMedium?.copyWith(
                  color: colors.textPrimary,
                  fontSize: 10,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 350.ms).slideX(begin: -0.1),
        const Spacer(),
        TextButton(
          onPressed: onSkip,
          child: const Text('Passer'),
        ),
      ],
    );
  }
}

class _SplashHero extends StatelessWidget {
  const _SplashHero();

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: 240,
          height: 230,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Container(
                width: 215,
                height: 215,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.16),
                  ),
                ),
              ).animate().fadeIn(duration: 550.ms).scaleXY(begin: 0.7),
              Container(
                width: 184,
                height: 184,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: 0.08),
                  border: Border.all(
                    color: AppColors.accentSoft.withValues(alpha: 0.26),
                  ),
                  boxShadow: AppShadows.glow(AppColors.accent, opacity: 0.20),
                ),
              )
                  .animate()
                  .fadeIn(delay: 90.ms, duration: 500.ms)
                  .scaleXY(begin: 0.8, curve: Curves.easeOutBack),
              Image.asset(
                'assets/images/logo_cul_sec.png',
                width: 148,
                height: 148,
                fit: BoxFit.contain,
                semanticLabel: 'Logo Cul Sec',
              )
                  .animate()
                  .fadeIn(delay: 160.ms, duration: 500.ms)
                  .scaleXY(begin: 0.76, curve: Curves.easeOutBack),
              const Positioned(
                top: 15,
                right: 22,
                child: _Sparkle(
                  icon: Icons.star_rounded,
                  color: AppColors.warning,
                  size: 22,
                ),
              ),
              const Positioned(
                bottom: 29,
                left: 17,
                child: _Sparkle(
                  icon: Icons.auto_awesome_rounded,
                  color: AppColors.modePrefere,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Cul Sec',
          textAlign: TextAlign.center,
          style: context.text.displayLarge?.copyWith(
            color: colors.textPrimary,
            fontSize: 50,
          ),
        )
            .animate()
            .fadeIn(delay: 260.ms, duration: 460.ms)
            .slideY(begin: 0.15, curve: Curves.easeOutCubic),
        const SizedBox(height: AppSpacing.sm),
        Container(
          height: 2,
          width: 118,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[
                AppColors.accent.withValues(alpha: 0),
                AppColors.accentSoft,
                AppColors.modePrefere.withValues(alpha: 0),
              ],
            ),
          ),
        ).animate().scaleX(delay: 400.ms, duration: 460.ms),
        const SizedBox(height: AppSpacing.md),
        Text(
          'JEUX DE SOIRÉE',
          textAlign: TextAlign.center,
          style: context.text.labelMedium?.copyWith(
            color: colors.textSecondary,
            letterSpacing: 4,
          ),
        ).animate().fadeIn(delay: 480.ms, duration: 430.ms),
      ],
    );
  }
}

class _Sparkle extends StatelessWidget {
  const _Sparkle({required this.icon, required this.color, required this.size});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Icon(icon, size: size, color: color)
          .animate()
          .fadeIn(delay: 540.ms, duration: 350.ms)
          .scaleXY(begin: 0.4, curve: Curves.easeOutBack),
    );
  }
}

class _SplashFooter extends StatelessWidget {
  const _SplashFooter({required this.tip, required this.content});

  final String tip;
  final Future<void> content;

  static int _cardCount() {
    int total = 0;
    for (final GameMode mode in kGameModes) {
      final PromptPack? pack = ContentService.instance.cached(mode.id);
      if (pack != null) total += pack.countAt(Intensity.adulte);
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    final AppState state = context.watch<AppState>();
    final int players = state.selectedCount;

    // <-- Correction de l'avertissement prefer_const_constructors
    const Wrap features = Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 6,
      children: <Widget>[
        _Feature(icon: Icons.bolt_rounded, label: 'Événements'),
        _Feature(icon: Icons.military_tech_rounded, label: 'Badges'),
        _Feature(icon: Icons.ios_share_rounded, label: 'Récap à partager'),
        _Feature(icon: Icons.wifi_off_rounded, label: 'Hors-ligne'),
        _Feature(icon: Icons.block_rounded, label: 'Sans pub'),
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          '${kGameModes.length} JEUX + LE MULTI-JEU',
          style: context.text.labelMedium?.copyWith(
            color: colors.textMuted,
            letterSpacing: 2,
          ),
        ).animate().fadeIn(delay: 580.ms, duration: 300.ms),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 7,
          runSpacing: 8,
          children: <Widget>[
            for (int i = 0; i < kGameModes.length; i++)
              _ModeTag(
                icon: kGameModes[i].icon,
                label: kGameModes[i].title,
                color: kGameModes[i].color,
              )
                  .animate()
                  .fadeIn(delay: (640 + i * 90).ms, duration: 360.ms)
                  .slideY(begin: 0.3, curve: Curves.easeOutBack),
            _ModeTag(
              icon: kMultiJeuMode.icon,
              label: kMultiJeuMode.title,
              color: kMultiJeuMode.color,
              highlight: true,
            )
                .animate()
                .fadeIn(
                  delay: (640 + kGameModes.length * 90).ms,
                  duration: 360.ms,
                )
                .slideY(begin: 0.3, curve: Curves.easeOutBack)
                .then(delay: 200.ms)
                .shimmer(duration: 900.ms, color: Colors.white24),
          ],
        ),

        const SizedBox(height: AppSpacing.md),

        FutureBuilder<void>(
          future: content,
          builder: (BuildContext context, AsyncSnapshot<void> snap) {
            final int cards = _cardCount();
            return Row(
              children: <Widget>[
                _InfoBox(
                  icon: Icons.style_rounded,
                  value: cards == 0 ? '…' : '$cards',
                  label: 'cartes',
                  color: AppColors.accentSoft,
                ),
                const SizedBox(width: AppSpacing.sm),
                _InfoBox(
                  icon: Icons.groups_rounded,
                  value: '$players',
                  label: players > 1 ? 'joueurs prêts' : 'joueur prêt',
                  color: AppColors.modePrefere,
                ),
                const SizedBox(width: AppSpacing.sm),
                _InfoBox(
                  icon: Icons.emoji_events_rounded,
                  value: '${state.gamesPlayed}',
                  label: state.gamesPlayed > 1
                      ? 'parties jouées'
                      : 'partie jouée',
                  color: AppColors.warning,
                ),
              ],
            );
          },
        )
            .animate()
            .fadeIn(delay: 1050.ms, duration: 380.ms)
            .slideY(begin: 0.15),

        const SizedBox(height: AppSpacing.md),

        features.animate().fadeIn(delay: 1200.ms, duration: 380.ms),

        const SizedBox(height: AppSpacing.md),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
          decoration: BoxDecoration(
            color: colors.surfaceHigh.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.lightbulb_rounded,
                size: 18,
                color: AppColors.warning,
              ),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Text(
                  tip,
                  style: context.text.bodySmall?.copyWith(
                    color: colors.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(delay: 1350.ms, duration: 400.ms)
            .slideY(begin: 0.2),

        const SizedBox(height: AppSpacing.md),

        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: _splashDuration,
            builder: (BuildContext context, double v, Widget? _) =>
                LinearProgressIndicator(
              value: v,
              minHeight: 3,
              backgroundColor: colors.fill,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.accentSoft),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Touchez pour commencer · À consommer avec modération',
          textAlign: TextAlign.center,
          style: context.text.bodySmall?.copyWith(
            fontSize: 10.5,
            color: colors.textMuted,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
        decoration: BoxDecoration(
          color: Color.lerp(colors.surfaceHigh, color, 0.08),
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Column(
          children: <Widget>[
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 3),
            Text(
              value,
              style: context.text.headlineMedium?.copyWith(
                fontSize: 19,
                color: colors.textPrimary,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall?.copyWith(fontSize: 10.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 13, color: colors.textMuted),
        const SizedBox(width: 4),
        Text(
          label,
          style: context.text.bodySmall?.copyWith(
            fontSize: 11,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ModeTag extends StatelessWidget {
  const _ModeTag({
    required this.icon,
    required this.label,
    required this.color,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Color.lerp(
          colors.surfaceHigh,
          color,
          highlight ? 0.22 : 0.09,
        ),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(
          color: color.withValues(alpha: highlight ? 0.7 : 0.32),
          width: highlight ? 1.4 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: context.text.labelMedium?.copyWith(
              fontSize: 10.5,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}