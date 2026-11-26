import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../models/game_mode.dart';
import '../models/player.dart';
import '../services/badges.dart';
import '../services/game_session.dart';
import '../services/haptics.dart';
import '../theme/app_theme.dart';
import 'avatar_view.dart';
import 'common.dart';

Future<void> showShareRecap(
  BuildContext context, {
  required GameMode mode,
  required GameSession session,
  required List<EveningBadge> badges,
}) {
  Haptics.light();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SharePreview(
      mode: mode,
      session: session,
      badges: badges,
    ),
  );
}

class _SharePreview extends StatefulWidget {
  const _SharePreview({
    required this.mode,
    required this.session,
    required this.badges,
  });

  final GameMode mode;
  final GameSession session;
  final List<EveningBadge> badges;

  @override
  State<_SharePreview> createState() => _SharePreviewState();
}

class _SharePreviewState extends State<_SharePreview> {
  final GlobalKey _captureKey = GlobalKey();
  final GlobalKey _buttonKey = GlobalKey();
  bool _busy = false;

  Future<Uint8List?> _capture() async {
    final RenderObject? object =
        _captureKey.currentContext?.findRenderObject();
    if (object is! RenderRepaintBoundary) return null;
    final ui.Image image = await object.toImage(pixelRatio: 2);
    final ByteData? data =
        await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data?.buffer.asUint8List();
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    Haptics.medium();
    try {
      final Uint8List? bytes = await _capture();
      if (bytes == null || !mounted) return;

      final RenderBox? box =
          _buttonKey.currentContext?.findRenderObject() as RenderBox?;
      final Rect? origin =
          box == null ? null : box.localToGlobal(Offset.zero) & box.size;

      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[
            XFile.fromData(
              bytes,
              mimeType: 'image/png',
              name: 'cul_sec_recap.png',
            ),
          ],
          text: 'Notre soirée Cul Sec 🍻',
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('Le partage a échoué.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    final double maxHeight = MediaQuery.sizeOf(context).height * 0.62;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceTop,
        borderRadius: AppRadii.sheet,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      padding: AppSpacing.screen.copyWith(
        top: AppSpacing.sm + 2,
        bottom: AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('APERÇU', style: context.text.labelMedium),
          const SizedBox(height: AppSpacing.md),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: FittedBox(
              child: RepaintBoundary(
                key: _captureKey,
                child: RecapCard(
                  mode: widget.mode,
                  session: widget.session,
                  badges: widget.badges,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            key: _buttonKey,
            label: _busy ? 'Préparation…' : 'Partager l’image',
            icon: Icons.ios_share_rounded,
            color: widget.mode.color,
            onPressed: _busy ? null : _share,
          ),
        ],
      ),
    );
  }
}

class RecapCard extends StatelessWidget {
  const RecapCard({
    super.key,
    required this.mode,
    required this.session,
    required this.badges,
  });

  final GameMode mode;
  final GameSession session;
  final List<EveningBadge> badges;

  static const double width = 360;

  String get _date {
    final DateTime d = session.startedAt;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  String get _duration {
    final Duration e = session.elapsed;
    if (e.inHours > 0) return '${e.inHours} h ${two(e.inMinutes % 60)}';
    return '${math.max(1, e.inMinutes)} min';
  }

  static String two(int v) => v.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    final List<Player> ranked = List<Player>.from(session.players)
      ..sort((Player a, Player b) =>
          session.sipsOf(b).compareTo(session.sipsOf(a)),);
    final List<Player> podium = ranked.take(3).toList();
    final List<EveningBadge> shownBadges = badges.take(6).toList();

    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: width,
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color.lerp(colors.ink, mode.color, 0.35)!,
              colors.ink,
              Color.lerp(colors.ink, mode.colorAlt, 0.25)!,
            ],
          ),
          border: Border.all(color: mode.color.withValues(alpha: 0.6)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Image.asset(
                  'assets/images/logo_cul_sec.png',
                  height: 34,
                  filterQuality: FilterQuality.medium,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Cul Sec !',
                        style: context.text.headlineMedium?.copyWith(
                          fontSize: 22,
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        '${mode.title} · $_date',
                        style: context.text.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                _MiniStat(value: '${session.turn}', label: 'tours'),
                _MiniStat(value: _duration, label: 'de soirée'),
                _MiniStat(
                  value: '${session.totalSips}',
                  label: 'gorgées',
                  color: AppColors.warning,
                ),
              ],
            ),
            if (podium.isNotEmpty) ...<Widget>[
              const SizedBox(height: 18),
              _Label('PODIUM DES ASSOIFFÉS', color: mode.color),
              const SizedBox(height: 8),
              for (int i = 0; i < podium.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: <Widget>[
                      SizedBox(
                        width: 26,
                        child: Text(
                          const <String>['🥇', '🥈', '🥉'][i],
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                      AvatarView.fromPlayer(
                        podium[i],
                        size: 28,
                        showRing: false,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          podium[i].name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleMedium?.copyWith(
                            fontSize: 15,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        '${session.sipsOf(podium[i])} 🍺',
                        style: context.text.titleMedium?.copyWith(
                          fontSize: 14,
                          color: podium[i].color,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            if (shownBadges.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              _Label('BADGES DE LA SOIRÉE', color: mode.color),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final EveningBadge b in shownBadges)
                    Container(
                      width: (width - 44 - 8) / 2,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: b.color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: b.color.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Text(b.emoji, style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  b.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.text.labelMedium?.copyWith(
                                    fontSize: 10.5,
                                    letterSpacing: 0.3,
                                    color: b.color,
                                  ),
                                ),
                                Text(
                                  b.player.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.text.titleMedium?.copyWith(
                                    fontSize: 13.5,
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            Center(
              child: Text(
                'Jeux de soirée · à consommer avec modération',
                style: context.text.bodySmall?.copyWith(
                  fontSize: 10.5,
                  color: colors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.value, required this.label, this.color});

  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          children: <Widget>[
            Text(
              value,
              style: context.text.headlineMedium?.copyWith(
                fontSize: 20,
                color: color ?? colors.textPrimary,
              ),
            ),
            Text(
              label,
              style: context.text.bodySmall?.copyWith(fontSize: 10.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: context.text.labelMedium?.copyWith(fontSize: 10.5, color: color),
    );
  }
}