import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../services/app_state.dart';
import '../services/haptics.dart';
import '../theme/app_theme.dart';

class IntensitySelector extends StatelessWidget {
  const IntensitySelector({
    super.key,
    this.onChanged,
    this.cardCounts,
    this.compact = false,
  });

  final ValueChanged<Intensity>? onChanged;
  final Map<Intensity, int>? cardCounts;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    final AppState state = context.watch<AppState>();
    final Intensity selected = state.intensity;
    const List<Intensity> options = Intensity.values;
    final int index = options.indexOf(selected);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          height: compact ? 44 : 54,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: colors.borderSoft),
          ),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) {
              final double segment = c.maxWidth / options.length;

              return Stack(
                children: <Widget>[
                  AnimatedPositioned(
                    duration: AppMotion.base,
                    curve: AppMotion.emphasized,
                    left: segment * index,
                    top: 0,
                    bottom: 0,
                    width: segment,
                    child: AnimatedContainer(
                      duration: AppMotion.base,
                      decoration: BoxDecoration(
                        gradient: AppGradients.pair(
                          selected.color,
                          Color.lerp(selected.color, Colors.black, 0.22)!,
                        ),
                        borderRadius: BorderRadius.circular(AppRadii.sm + 2),
                        boxShadow: AppShadows.glow(selected.color),
                      ),
                    ),
                  ),
                  Row(
                    children: options.map((Intensity value) {
                      final bool isOn = value == selected;

                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (isOn) return;
                            Haptics.medium();
                            state.setIntensity(value);
                            onChanged?.call(value);
                          },
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    AnimatedScale(
                                      duration: AppMotion.base,
                                      curve: AppMotion.overshoot,
                                      scale: isOn ? 1 : 0.9,
                                      child: Icon(
                                        value.icon,
                                        size: compact ? 12 : 13,
                                        color: isOn
                                            ? Colors.white
                                            : value.color
                                                .withValues(alpha: 0.55),
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    AnimatedDefaultTextStyle(
                                      duration: AppMotion.base,
                                      style:
                                          context.text.titleMedium!.copyWith(
                                        fontSize: compact ? 12 : 13.5,
                                        color: isOn
                                            ? Colors.white
                                            : colors.textSecondary,
                                        fontWeight: isOn
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                      child: Text(value.label),
                                    ),
                                  ],
                                ),
                                if (!compact && cardCounts != null)
                                  AnimatedDefaultTextStyle(
                                    duration: AppMotion.base,
                                    style: context.text.bodySmall!.copyWith(
                                      fontSize: 10,
                                      color: isOn
                                          ? Colors.white
                                              .withValues(alpha: 0.85)
                                          : colors.textMuted,
                                    ),
                                    child:
                                        Text('${cardCounts![value] ?? 0}'),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              );
            },
          ),
        ),

        if (!compact) ...<Widget>[
          const SizedBox(height: AppSpacing.sm + 2),
          Row(
            children: <Widget>[
              Container(
                width: 3,
                height: 15,
                decoration: BoxDecoration(
                  color: selected.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AnimatedSwitcher(
                  duration: AppMotion.base,
                  child: Row(
                    key: ValueKey<Intensity>(selected),
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          selected.tagline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleMedium?.copyWith(
                            fontSize: 13,
                            color: selected.color,
                          ),
                        ),
                      ),
                      if (selected.isExplicit) ...<Widget>[
                        const SizedBox(width: AppSpacing.sm),
                        const AdultBadge(),
                      ],
                    ],
                  ),
                ),
              ),
              if (cardCounts != null)
                Text(
                  '${cardCounts![selected] ?? 0} cartes',
                  style: context.text.bodySmall?.copyWith(fontSize: 11.5),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class AdultBadge extends StatelessWidget {
  const AdultBadge({super.key, this.small = true});

  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 8,
        vertical: small ? 1.5 : 3,
      ),
      decoration: BoxDecoration(
        color: AppColors.intensityAdulte.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: AppColors.intensityAdulte.withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        '18+',
        style: context.text.labelMedium?.copyWith(
          fontSize: small ? 9 : 11,
          letterSpacing: 0.4,
          color: AppColors.intensityAdulte,
        ),
      ),
    );
  }
}

class IntensityChip extends StatelessWidget {
  const IntensityChip({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Intensity level = context.watch<AppState>().intensity;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.base,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: level.color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: level.color.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(level.icon, size: 13, color: level.color),
            const SizedBox(width: 5),
            Text(
              level.label,
              style: context.text.titleMedium?.copyWith(
                fontSize: 12,
                color: level.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class IntensitySheet extends StatelessWidget {
  const IntensitySheet({super.key, this.onChanged, this.cardCounts});

  final ValueChanged<Intensity>? onChanged;
  final Map<Intensity, int>? cardCounts;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    final AppState state = context.watch<AppState>();

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceTop,
        borderRadius: AppRadii.sheet,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      padding: AppSpacing.screen.copyWith(
        top: AppSpacing.md,
        bottom: AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('INTENSITÉ', style: context.text.labelMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Chaque palier inclut les précédents.',
            style: context.text.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),

          for (int i = 0; i < Intensity.values.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
              child: _IntensityRow(
                value: Intensity.values[i],
                selected: state.intensity == Intensity.values[i],
                count: cardCounts?[Intensity.values[i]],
                onTap: () {
                  Haptics.medium();
                  state.setIntensity(Intensity.values[i]);
                  onChanged?.call(Intensity.values[i]);
                },
              )
                  .animate()
                  .fadeIn(delay: (i * 55).ms, duration: 260.ms)
                  .slideY(begin: 0.15, curve: Curves.easeOutCubic),
            ),
        ],
      ),
    );
  }
}

class _IntensityRow extends StatelessWidget {
  const _IntensityRow({
    required this.value,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final Intensity value;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.base,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color:
              selected ? value.color.withValues(alpha: 0.12) : colors.fill,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(
            color: selected
                ? value.color.withValues(alpha: 0.6)
                : colors.borderSoft,
            width: selected ? 1.6 : 1,
          ),
          boxShadow:
              selected ? AppShadows.glow(value.color, opacity: 0.18) : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: value.color.withValues(alpha: selected ? 0.22 : 0.10),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Icon(value.icon, size: 18, color: value.color),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        value.label,
                        style: context.text.titleLarge?.copyWith(
                          fontSize: 16,
                          color:
                              selected ? value.color : colors.textPrimary,
                        ),
                      ),
                      if (value.isExplicit) ...<Widget>[
                        const SizedBox(width: AppSpacing.sm),
                        const AdultBadge(),
                      ],
                      const Spacer(),
                      if (count != null)
                        Text(
                          '$count cartes',
                          style: context.text.bodySmall
                              ?.copyWith(fontSize: 11.5),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(value.description, style: context.text.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showIntensitySheet(
  BuildContext context, {
  ValueChanged<Intensity>? onChanged,
  Map<Intensity, int>? cardCounts,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => IntensitySheet(
      onChanged: onChanged,
      cardCounts: cardCounts,
    ),
  );
}