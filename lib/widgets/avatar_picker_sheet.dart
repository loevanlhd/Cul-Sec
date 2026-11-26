import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../data/avatar_catalog.dart';
import '../services/avatar_photo_service.dart';
import '../services/haptics.dart';
import '../theme/app_theme.dart';
import 'avatar_view.dart';
import 'common.dart';

class AvatarChoice {
  const AvatarChoice.emoji(this.emoji) : photoBase64 = null;
  const AvatarChoice.photo(this.photoBase64) : emoji = null;

  final String? emoji;
  final String? photoBase64;
}

class AvatarPickerSheet extends StatefulWidget {
  const AvatarPickerSheet({
    super.key,
    required this.currentEmoji,
    required this.currentPhoto,
    required this.color,
    this.taken = const <String>{},
  });

  final String currentEmoji;
  final String? currentPhoto;
  final Color color;
  final Set<String> taken;

  static const Duration _openDuration = Duration(milliseconds: 260);
  static const Duration _closeDuration = Duration(milliseconds: 190);

  static Future<AvatarChoice?> show(
    BuildContext context, {
    required String currentEmoji,
    String? currentPhoto,
    required Color color,
    Set<String> taken = const <String>{},
  }) {
    return showModalBottomSheet<AvatarChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: const AnimationStyle(
        duration: _openDuration,
        reverseDuration: _closeDuration,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
      builder: (_) => AvatarPickerSheet(
        currentEmoji: currentEmoji,
        currentPhoto: currentPhoto,
        color: color,
        taken: taken,
      ),
    );
  }

  @override
  State<AvatarPickerSheet> createState() => _AvatarPickerSheetState();
}

class _AvatarPickerSheetState extends State<AvatarPickerSheet> {
  bool _busy = false;

  late String? _selected =
      widget.currentPhoto == null ? widget.currentEmoji : null;

  Future<void> _capture(Future<AvatarPickResult> Function() action) async {
    setState(() => _busy = true);
    final AvatarPickResult result = await action();
    if (!mounted) return;
    setState(() => _busy = false);

    switch (result.status) {
      case AvatarPickStatus.success:
        Haptics.medium();
        if (!mounted) return;
        Navigator.of(context).pop(AvatarChoice.photo(result.base64!));

      case AvatarPickStatus.tooLarge:
        await Haptics.failure();
        if (!mounted) return;
        ScaffoldMessenger.maybeOf(context)
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Image trop lourde. Choisissez une photo plus légère '
                'ou utilisez l’appareil photo.',
              ),
              duration: Duration(seconds: 3),
            ),
          );

      case AvatarPickStatus.cancelled:
      case AvatarPickStatus.unavailable:
        break;
    }
  }

  void _pick(String value) {
    if (widget.taken.contains(value)) {
      Haptics.light();
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Cet avatar est déjà pris par un autre joueur.'),
            duration: Duration(seconds: 2),
          ),
        );
      return;
    }
    Haptics.tick();
    setState(() => _selected = value);
    Navigator.of(context).pop(AvatarChoice.emoji(value));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colors.surfaceHigh,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadii.xl),
            ),
            border: Border(top: BorderSide(color: colors.border)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: <Widget>[
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textMuted,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: <Widget>[
                    AvatarView(
                      emoji: _selected ?? widget.currentEmoji,
                      photoBase64:
                          _selected == null ? widget.currentPhoto : null,
                      color: widget.color,
                      size: 52,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'Choisis ton avatar',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
              ),
              _PhotoActions(busy: _busy, onCapture: _capture),
              const Divider(),
              Expanded(
                child: _AvatarGrid(
                  controller: scrollController,
                  selected: _selected,
                  taken: widget.taken,
                  color: widget.color,
                  onPick: _pick,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PhotoActions extends StatelessWidget {
  const _PhotoActions({required this.busy, required this.onCapture});

  final bool busy;
  final Future<void> Function(Future<AvatarPickResult> Function()) onCapture;

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: <Widget>[
          if (AvatarPhotoService.isCameraAvailable) ...<Widget>[
            Expanded(
              child: _PhotoButton(
                icon: Icons.photo_camera_outlined,
                label: 'Photo',
                onTap: () => onCapture(AvatarPhotoService.takePhoto),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: _PhotoButton(
              icon: Icons.photo_library_outlined,
              label: 'Galerie',
              onTap: () => onCapture(AvatarPhotoService.pickFromGallery),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoButton extends StatelessWidget {
  const _PhotoButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: colors.fill,
          borderRadius: AppRadii.button,
          border: Border.all(color: colors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 20, color: colors.textPrimary),
            const SizedBox(width: AppSpacing.sm),
            Text(label, style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}

class _AvatarGrid extends StatelessWidget {
  const _AvatarGrid({
    required this.controller,
    required this.selected,
    required this.taken,
    required this.color,
    required this.onPick,
  });

  final ScrollController controller;
  final String? selected;
  final Set<String> taken;
  final Color color;
  final ValueChanged<String> onPick;

  static const SliverGridDelegate _emojiDelegate =
      SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 6,
    mainAxisSpacing: AppSpacing.sm,
    crossAxisSpacing: AppSpacing.sm,
  );

  static const SliverGridDelegate _mascotDelegate =
      SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 4,
    mainAxisSpacing: AppSpacing.sm,
    crossAxisSpacing: AppSpacing.sm,
    childAspectRatio: 0.78,
  );

  Widget _header(String text, TextStyle? style) => SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        sliver: SliverToBoxAdapter(child: Text(text, style: style)),
      );

  Widget _mascotGrid(List<String> values) => SliverGrid(
        gridDelegate: _mascotDelegate,
        delegate: SliverChildBuilderDelegate(
          (BuildContext context, int index) {
            final String value = values[index];
            return _MascotTile(
              key: ValueKey<String>(value),
              value: value,
              selected: selected == value,
              taken: taken.contains(value),
              color: color,
              onTap: () => onPick(value),
            );
          },
          childCount: values.length,
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: false,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final TextStyle? headerStyle =
        Theme.of(context).textTheme.bodySmall?.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            );

    return CustomScrollView(
      controller: controller,
      physics: const ClampingScrollPhysics(),
      scrollCacheExtent: const ScrollCacheExtent.pixels(400),
      slivers: <Widget>[
        for (final MapEntry<String, Map<String, String>> group
            in AvatarCatalog.mascotGroups.entries) ...<Widget>[
          _header('AVATARS · ${group.key}', headerStyle),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            sliver: _mascotGrid(AvatarCatalog.valuesOf(group.value)),
          ),
        ],
        for (final MapEntry<String, List<String>> group
            in AvatarCatalog.groups.entries) ...<Widget>[
          _header(group.key.toUpperCase(), headerStyle),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            sliver: SliverGrid(
              gridDelegate: _emojiDelegate,
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) {
                  final String emoji = group.value[index];
                  return _EmojiTile(
                    key: ValueKey<String>(emoji),
                    emoji: emoji,
                    selected: selected == emoji,
                    taken: taken.contains(emoji),
                    color: color,
                    onTap: () => onPick(emoji),
                  );
                },
                childCount: group.value.length,
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: false,
              ),
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
      ],
    );
  }
}

class _TakenBadge extends StatelessWidget {
  const _TakenBadge();

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.surfaceHigh,
        border: Border.all(color: colors.border),
      ),
      child: Icon(
        Icons.lock_rounded,
        size: 12,
        color: colors.textMuted,
      ),
    );
  }
}

class _MascotTile extends StatelessWidget {
  const _MascotTile({
    super.key,
    required this.value,
    required this.selected,
    required this.taken,
    required this.color,
    required this.onTap,
  });

  final String value;
  final bool selected;
  final bool taken;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Pressable(
        onTap: onTap,
        scale: taken ? 1 : 0.9,
        child: Opacity(
          opacity: taken ? 0.35 : 1,
          child: Column(
            children: <Widget>[
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    children: <Widget>[
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: selected
                                ? Border.all(color: color, width: 3)
                                : null,
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(selected ? 3 : 0),
                            child: ClipOval(
                              child: LayoutBuilder(
                                builder: (_, BoxConstraints c) =>
                                    MascotImage(
                                  value: value,
                                  size: c.maxWidth,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (taken)
                        const Positioned(
                          right: 0,
                          bottom: 0,
                          child: _TakenBadge(),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AvatarCatalog.nameFor(value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w700 : null,
                      color: selected ? color : null,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmojiTile extends StatelessWidget {
  const _EmojiTile({
    super.key,
    required this.emoji,
    required this.selected,
    required this.taken,
    required this.color,
    required this.onTap,
  });

  final String emoji;
  final bool selected;
  final bool taken;
  final Color color;
  final VoidCallback onTap;

  static const TextStyle _emojiStyle = TextStyle(fontSize: 24);

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    final Widget label = Text(emoji, style: _emojiStyle);

    if (taken) {
      return RepaintBoundary(
        child: GestureDetector(
          onTap: onTap,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: Opacity(
                  opacity: 0.35,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.fill,
                      borderRadius:
                          const BorderRadius.all(Radius.circular(AppRadii.sm)),
                    ),
                    child: Center(child: label),
                  ),
                ),
              ),
              const Positioned(right: 0, bottom: 0, child: _TakenBadge()),
            ],
          ),
        ),
      );
    }

    if (!selected) {
      return RepaintBoundary(
        child: Pressable(
          onTap: onTap,
          scale: 0.88,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.fill,
              borderRadius: const BorderRadius.all(Radius.circular(AppRadii.sm)),
            ),
            child: Center(child: label),
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: Pressable(
        onTap: onTap,
        scale: 0.88,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.emphasized,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: Border.all(color: color, width: 2),
          ),
          alignment: Alignment.center,
          child: label,
        ),
      ),
    );
  }
}