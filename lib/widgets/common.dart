import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Carte de surface : dégradé neutre, bordure fine, ombre portée.
/// [accent] colore la bordure quand l'élément est actif.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.borderRadius,
    this.fill,
    this.accent,
    this.onTap,
    this.elevated = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final Color? fill;
  final Color? accent;
  final VoidCallback? onTap;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = borderRadius ?? AppRadii.card;
    final colors = context.culColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: elevated ? AppShadows.raised : AppShadows.card,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            gradient: fill == null ? colors.gradientSurface : null,
            borderRadius: radius,
            border: Border.all(
              color: accent != null ? accent!.withValues(alpha: 0.42) : colors.borderSoft,
              width: accent != null ? 1.4 : 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: radius,
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pastille compacte, pour les métadonnées.
class AppPill extends StatelessWidget {
  const AppPill({
    super.key,
    required this.child,
    this.color,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
  });

  final Widget child;
  final Color? color;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    final Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color == null ? colors.fill : color!.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(
          color: color == null ? colors.borderSoft : color!.withValues(alpha: 0.4),
        ),
      ),
      child: child,
    );

    if (onTap == null) return content;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: content);
  }
}

/// Élément qui s'enfonce légèrement au toucher.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.97,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;
  bool get _interactive => widget.onTap != null || widget.onLongPress != null;
  void _set(bool value) => setState(() => _pressed = value);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _interactive ? (_) => _set(true) : null,
      onTapUp: _interactive ? (_) => _set(false) : null,
      onTapCancel: _interactive ? () => _set(false) : null,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: AppMotion.fast,
        curve: AppMotion.enter,
        child: widget.child,
      ),
    );
  }
}

/// Action principale d'un écran.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
    this.height = 56,
    this.expand = true,
    this.primary = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final double height;
  final bool expand;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    final bool disabled = onPressed == null;
    final Color tint = color ?? AppColors.accent;

    final Widget button = AnimatedOpacity(
      duration: AppMotion.fast,
      opacity: disabled ? 0.42 : 1,
      child: Container(
        height: height,
        width: expand ? double.infinity : null,
        padding: expand ? null : const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: primary ? AppGradients.pair(tint, Color.lerp(tint, Colors.black, 0.24)!) : null,
          color: primary ? null : colors.fill,
          borderRadius: AppRadii.button,
          border: primary ? null : Border.all(color: colors.border),
          boxShadow: primary && !disabled ? AppShadows.glow(tint) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(
                icon,
                size: 19,
                color: primary ? Colors.white : colors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm + 2),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelLarge?.copyWith(
                  fontSize: 16,
                  color: primary ? Colors.white : colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Pressable(onTap: onPressed, child: expand ? button : Center(child: button));
  }
}

/// En-tête d'écran secondaire : bouton retour, titre, action optionnelle.
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.subtitle,
    this.action,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onBack;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    return Padding(
      padding: AppSpacing.screen.copyWith(top: AppSpacing.sm, bottom: AppSpacing.md),
      child: Row(
        children: <Widget>[
          AppPill(
            padding: const EdgeInsets.all(10),
            onTap: onBack,
            child: Icon(Icons.arrow_back_rounded, size: 19, color: colors.textSecondary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.headlineMedium),
                if (subtitle != null) Text(subtitle!, style: context.text.bodySmall),
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// Interrupteur compact, dessiné à la main.
class MiniSwitch extends StatelessWidget {
  const MiniSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.accent = AppColors.accent,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: AppMotion.base,
        curve: AppMotion.emphasized,
        width: 44,
        height: 25,
        padding: const EdgeInsets.all(3),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(
          color: value ? accent : colors.fillStrong,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: value ? Colors.transparent : colors.border),
        ),
        child: Container(
          width: 19,
          height: 19,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
        ),
      ),
    );
  }
}

/// Titre de section : petites capitales suivies d'un filet.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.label, {super.key, this.trailing});

  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: <Widget>[
          Text(label, style: context.text.labelMedium),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(child: Container(height: 1, color: colors.borderSoft)),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: AppSpacing.sm + 2),
            Text(trailing!, style: context.text.bodySmall?.copyWith(fontSize: 11.5)),
          ],
        ],
      ),
    );
  }
}

/// Le bouton de connexion Google officiel (ou stylisé pour l'être).
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.loading,
    required this.onPressed,
  });

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          side: const BorderSide(color: Colors.grey, width: 0.8),
        ),
      ),
      child: loading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black54),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: const Text(
                    'G',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4285F4),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Continuer avec Google',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[850],
                  ),
                ),
              ],
            ),
    );
  }
}