import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_theme.dart';
import '../widgets/ambient_background.dart';
import '../widgets/avatar_view.dart';
import '../widgets/common.dart';
import 'multiplayer_session.dart';

class MultiplayerEndScreen extends StatelessWidget {
  const MultiplayerEndScreen({
    super.key,
    required this.data,
    required this.isHost,
    required this.onReplay,
    required this.onQuit,
  });

  final MultiplayerEndData data;
  final bool isHost;
  final VoidCallback onReplay;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    final List<MultiplayerPlayer> podium = data.ranking.take(3).toList();
    final int maxSips = data.sips[data.ranking.first.id] ?? 1;

    return Scaffold(
      body: AmbientBackground(
        primary: AppColors.warning,
        secondary: AppColors.accent,
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Expanded(
                child: ListView(
                  padding: AppSpacing.screen.copyWith(top: 32, bottom: 16),
                  children: [
                    Center(
                      child: Column(
                        children: [
                          const Icon(Icons.emoji_events_rounded, size: 56, color: AppColors.warning),
                          const SizedBox(height: 8),
                          Text('FIN DE LA PARTIE', style: context.text.labelMedium?.copyWith(letterSpacing: 3)),
                          const SizedBox(height: 4),
                          Text('Podium', style: context.text.displaySmall),
                        ],
                      ),
                    ).animate().fadeIn().scaleXY(begin: 0.9),

                    const SizedBox(height: AppSpacing.xl),

                    for (int i = 0; i < podium.length; i++)
                      _PodiumRow(rank: i + 1, player: podium[i], sips: data.sips[podium[i].id] ?? 0)
                          .animate().fadeIn(delay: (200 + i * 100).ms).slideY(begin: 0.1),

                    const SizedBox(height: AppSpacing.xl),
                    
                    if (data.badges.isNotEmpty) ...[
                      const SectionTitle('BADGES DE LA SOIRÉE'),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          for (final b in data.badges)
                            _BadgeTile(badge: b).animate().fadeIn(delay: (500 + data.badges.indexOf(b) * 80).ms).scaleXY(begin: 0.8),
                        ],
                      ),
                    ],

                    const SizedBox(height: AppSpacing.xl),
                    
                    const SectionTitle('CLASSEMENT COMPLET'),
                    for (final p in data.ranking)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _RankRow(
                          player: p,
                          sips: data.sips[p.id] ?? 0,
                          maxSips: maxSips,
                        ),
                      ),
                  ],
                ),
              ),
              
              Padding(
                padding: AppSpacing.screen.copyWith(top: 8, bottom: 16),
                child: Column(
                  children: [
                    if (isHost)
                      AppButton(
                        label: 'Rejouer avec ce groupe',
                        icon: Icons.replay_rounded,
                        color: AppColors.accent,
                        onPressed: onReplay,
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colors.fill,
                          borderRadius: BorderRadius.circular(AppRadii.md),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                            const SizedBox(width: 12),
                            Text('En attente de l’hôte…', style: context.text.bodyMedium),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: onQuit,
                      child: const Text('Quitter la partie'),
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

class _PodiumRow extends StatelessWidget {
  const _PodiumRow({required this.rank, required this.player, required this.sips});
  final int rank;
  final MultiplayerPlayer player;
  final int sips;

  @override
  Widget build(BuildContext context) {
    final Color color = AppColors.playerPalette[player.colorIndex % AppColors.playerPalette.length];
    final String emoji = ['🥇', '🥈', '🥉'][rank - 1];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        accent: color,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            AvatarView(emoji: player.emoji, photoBase64: player.photoBase64, color: color, size: 44, showRing: false),
            const SizedBox(width: 12),
            Expanded(
              child: Text(player.name, style: context.text.headlineMedium?.copyWith(color: color)),
            ),
            Text('$sips 🍺', style: context.text.titleLarge?.copyWith(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge});
  final MultiplayerBadgeData badge;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    final color = Color(badge.colorValue);
    return Container(
      width: 160,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surfaceHigh,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(badge.emoji, style: const TextStyle(fontSize: 22)),
              const Spacer(),
              Flexible(
                child: Text(
                  badge.title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelMedium?.copyWith(fontSize: 9, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(badge.playerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleMedium?.copyWith(fontSize: 13)),
          Text(badge.detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall?.copyWith(fontSize: 11)),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.player, required this.sips, required this.maxSips});
  final MultiplayerPlayer player;
  final int sips;
  final int maxSips;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    final Color color = AppColors.playerPalette[player.colorIndex % AppColors.playerPalette.length];
    return Row(
      children: [
        AvatarView(emoji: player.emoji, photoBase64: player.photoBase64, color: color, size: 22, showRing: false),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(player.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleMedium?.copyWith(fontSize: 13)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: LinearProgressIndicator(
              value: maxSips == 0 ? 0 : sips / maxSips,
              minHeight: 6,
              backgroundColor: colors.fill,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(width: 20, child: Text('$sips', textAlign: TextAlign.right, style: context.text.titleMedium?.copyWith(fontSize: 13, color: color))),
      ],
    );
  }
}