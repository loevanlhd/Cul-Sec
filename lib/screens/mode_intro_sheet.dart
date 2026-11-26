import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/game_mode.dart';
import '../models/prompt.dart';
import '../services/app_state.dart';
import '../services/content_service.dart';
import '../services/haptics.dart';
import '../theme/app_theme.dart';
import '../widgets/app_transitions.dart';
import '../widgets/common.dart';
import '../widgets/intensity_selector.dart';
import 'game_launcher.dart';
import 'settings_screen.dart';

/// Feuille de présentation d'un mode.
class ModeIntroSheet extends StatefulWidget {
  const ModeIntroSheet({super.key, required this.mode});

  final GameMode mode;

  @override
  State<ModeIntroSheet> createState() => _ModeIntroSheetState();
}

class _ModeIntroSheetState extends State<ModeIntroSheet> {
  PromptPack? get _pack => ContentService.instance.cached(widget.mode.id);

  Map<Intensity, int> get _counts {
    final PromptPack? pack = _pack;
    if (pack == null) return <Intensity, int>{};
    return <Intensity, int>{
      for (final Intensity level in Intensity.values)
        level: pack.countAt(level),
    };
  }

  void _start() {
    Haptics.medium();
    Navigator.of(context).pop();
    Navigator.of(context).push(
      ForwardRoute<void>(
        builder: (_) => GameLauncher(mode: widget.mode),
      ),
    );
  }

  void _openSettings() {
    Haptics.light();
    Navigator.of(context).pop();
    Navigator.of(context).push(
      ForwardRoute<void>(
        builder: (_) => const SettingsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors; // <-- Ajouté
    final AppState state = context.watch<AppState>();
    final GameMode mode = widget.mode;
    final PromptPack? pack = _pack;

    final bool enoughPlayers = state.selectedCount >= mode.minPlayers;

    final int playable = pack == null
        ? 0
        : pack.filtered(state.intensity, categories: state.categories).length;

    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (BuildContext context, ScrollController controller) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceTop, // <-- Modifié
            borderRadius: AppRadii.sheet,
            border: Border(
              top: BorderSide(
                color: mode.color.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
          ),
          child: Column(
            children: <Widget>[
              const SizedBox(height: AppSpacing.sm + 2),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border, // <-- Modifié
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),

              Expanded(
                child: ListView(
                  controller: controller,
                  padding: AppSpacing.screen.copyWith(top: AppSpacing.lg),
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: 54,
                          height: 54,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: AppGradients.pair(
                              mode.color.withValues(alpha: 0.28),
                              mode.colorAlt.withValues(alpha: 0.12),
                            ),
                            borderRadius: BorderRadius.circular(AppRadii.md),
                            border: Border.all(
                              color: mode.color.withValues(alpha: 0.45),
                            ),
                          ),
                          child:
                              Icon(mode.icon, size: 26, color: mode.color),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                mode.title,
                                style: context.text.headlineLarge,
                              ),
                              Text(
                                mode.tagline,
                                style: context.text.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.lg),
                    Text(mode.rules, style: context.text.bodyLarge),

                    const SizedBox(height: AppSpacing.lg),
                    const SectionTitle('COMMENT ON JOUE'),
                    for (int i = 0; i < mode.howTo.length; i++)
                      Padding(
                        padding:
                            const EdgeInsets.only(bottom: AppSpacing.sm + 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Container(
                              width: 22,
                              height: 22,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: mode.color.withValues(alpha: 0.18),
                              ),
                              child: Text(
                                '${i + 1}',
                                style: context.text.labelMedium?.copyWith(
                                  fontSize: 11,
                                  letterSpacing: 0,
                                  color: mode.color,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm + 4),
                            Expanded(
                              child: Text(
                                mode.howTo[i],
                                style: context.text.bodyMedium?.copyWith(
                                  color: colors.textSecondary, // <-- Modifié
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                          .animate()
                          .fadeIn(delay: (i * 70).ms, duration: 300.ms)
                          .slideX(begin: 0.08),

                    const SizedBox(height: AppSpacing.lg),
                    const SectionTitle('INTENSITÉ'),
                    IntensitySelector(cardCounts: _counts),

                    if (pack != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.lg),
                      SectionTitle(
                        'THÈMES',
                        trailing: state.categories.isEmpty
                            ? 'tous'
                            : '${state.categories.length} actifs',
                      ),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: <Widget>[
                          for (final GameCategory c
                              in pack.availableCategories)
                            _CategoryChip(
                              category: c,
                              on: state.isCategoryOn(c),
                              color: mode.color,
                              onTap: () {
                                Haptics.tick();
                                state.toggleCategory(
                                  c,
                                  pack.availableCategories,
                                );
                              },
                            ),
                        ],
                      ),
                    ],

                    const SizedBox(height: AppSpacing.lg),
                    AppCard(
                      onTap: _openSettings,
                      accent: enoughPlayers ? null : AppColors.warning,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.group_outlined,
                            size: 19,
                            color: enoughPlayers
                                ? colors.textSecondary // <-- Modifié
                                : AppColors.warning,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              enoughPlayers
                                  ? '${state.selectedCount} joueurs à table'
                                  : '${mode.minPlayers} joueurs minimum — '
                                      'touchez pour en ajouter',
                              style: context.text.titleMedium?.copyWith(
                                fontSize: 14,
                                color: enoughPlayers
                                    ? colors.textPrimary // <-- Modifié
                                    : AppColors.warning,
                              ),
                            ),
                          ),
                          Icon( // <-- Retrait du const
                            Icons.chevron_right_rounded,
                            size: 19,
                            color: colors.textMuted, // <-- Modifié
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),

              Padding(
                padding: AppSpacing.screen.copyWith(
                  top: AppSpacing.sm,
                  bottom:
                      AppSpacing.md + MediaQuery.paddingOf(context).bottom,
                ),
                child: Column(
                  children: <Widget>[
                    Text(
                      '$playable cartes prêtes pour cette partie',
                      style:
                          context.text.bodySmall?.copyWith(fontSize: 11.5),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppButton(
                      label: enoughPlayers
                          ? 'Lancer la partie'
                          : 'Ajouter des joueurs',
                      icon: enoughPlayers
                          ? Icons.play_arrow_rounded
                          : Icons.group_add_outlined,
                      color: mode.color,
                      onPressed: enoughPlayers ? _start : _openSettings,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.on,
    required this.color,
    required this.onTap,
  });

  final GameCategory category;
  final bool on;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors; // <-- Ajouté
    return Pressable(
      scale: 0.93,
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.base,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: on ? color.withValues(alpha: 0.18) : colors.fill, // <-- Modifié
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: on ? color.withValues(alpha: 0.6) : colors.borderSoft, // <-- Modifié
            width: on ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              category.icon,
              size: 13,
              color: on ? color : colors.textMuted, // <-- Modifié
            ),
            const SizedBox(width: 6),
            Text(
              category.label,
              style: context.text.titleMedium?.copyWith(
                fontSize: 12.5,
                color: on ? color : colors.textMuted, // <-- Modifié
              ),
            ),
          ],
        ),
      ),
    );
  }
}