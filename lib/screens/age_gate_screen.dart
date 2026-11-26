import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import '../services/haptics.dart';
import '../theme/app_theme.dart';
import '../widgets/ambient_background.dart';
import '../widgets/common.dart';
import 'home_screen.dart';

/// Confirmation d'âge au premier lancement.
///
/// C'est le seul garde-fou de l'application, et il est donc explicite :
/// tout le contenu, palier Adulte compris, est disponible juste après.
class AgeGateScreen extends StatelessWidget {
  const AgeGateScreen({super.key});

  Future<void> _confirm(BuildContext context) async {
    await Haptics.double();
    if (!context.mounted) return;

    await context.read<AppState>().confirmAge();
    if (!context.mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AmbientBackground(
        primary: AppColors.intensityAdulte,
        secondary: AppColors.accent,
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Expanded(
                child: SingleChildScrollView(
                  padding: AppSpacing.screen.copyWith(top: AppSpacing.xxl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('BIENVENUE', style: context.text.labelMedium),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Avant de\ncommencer',
                        style: context.text.displayMedium,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Cul Sec est réservé aux personnes majeures. '
                        'L’application contient des questions et des gages à '
                        'caractère sexuel explicite, accessibles via le palier '
                        '« Adulte ».',
                        style: context.text.bodyLarge,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const _Principle(
                        number: '01',
                        title: 'Personne n’est obligé',
                        text: 'Passer une carte est toujours gratuit, sur '
                            'tous les modes. Aucune question ne mérite qu’on '
                            'se force.',
                      ),
                      const _Principle(
                        number: '02',
                        title: 'Les gorgées sont plafonnées',
                        text: 'Trois au maximum par tour, quoi qu’il arrive. '
                            'Le contenu lui-même porte cette limite.',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: AppSpacing.screen.copyWith(
                  top: AppSpacing.sm,
                  bottom: AppSpacing.lg,
                ),
                child: Column(
                  children: <Widget>[
                    AppButton(
                      label: 'J’ai 18 ans ou plus',
                      icon: Icons.check_rounded,
                      onPressed: () => _confirm(context),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Si ce n’est pas le cas, fermez l’application.',
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Un principe, en liste numérotée : hiérarchie portée par la typographie.
class _Principle extends StatelessWidget {
  const _Principle({
    required this.number,
    required this.title,
    required this.text,
  });

  final String number;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 36,
            child: Text(
              number,
              style: context.text.labelMedium?.copyWith(
                color: AppColors.accentSoft,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: context.text.titleLarge),
                const SizedBox(height: AppSpacing.xs + 2),
                Text(text, style: context.text.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideX(begin: 0.06, curve: Curves.easeOutCubic);
  }
}