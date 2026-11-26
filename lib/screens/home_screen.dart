import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../data/game_modes_catalog.dart';
import '../models/enums.dart';
import '../models/game_mode.dart';
import '../models/player.dart';
import '../models/prompt.dart';
import '../multiplayer/multiplayer_home_screen.dart';
import '../services/app_state.dart';
import '../services/content_service.dart';
import '../services/haptics.dart';
import '../services/saved_game.dart';
import '../theme/app_theme.dart';
import '../widgets/ambient_background.dart';
import '../widgets/app_transitions.dart';
import '../widgets/avatar_view.dart';
import '../widgets/common.dart';
import '../widgets/intensity_selector.dart';
import 'game_launcher.dart';
import 'mode_intro_sheet.dart';
import 'multi_jeu_screen.dart';
import 'settings_screen.dart';

const GameMode kMultiplayerMode = GameMode(
  id: GameModeId.actionOuVerite,
  title: 'Multijoueur local',
  tagline: 'Chacun son téléphone, un hôte central',
  rules: 'Un appareil héberge la partie, les autres le rejoignent en '
      'scannant un QR code ou en saisissant un code à 6 caractères. '
      'Tout se passe sur le réseau local, sans Internet.',
  howTo: <String>[
    'L’hôte ouvre l’écran « Héberger »',
    'Les autres scannent le QR code affiché',
    'La partie démarre quand tout le monde est connecté',
  ],
  icon: Icons.devices_rounded,
  color: Color(0xFF38BDF8),
  colorAlt: Color(0xFF8B7BFF),
);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scroll = ScrollController();
  final ValueNotifier<double> _offset = ValueNotifier<double>(0);

  Map<Intensity, int>? _cachedCounts;
  int _cachedCustomCount = -1;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _offerResume());
  }

  Future<void> _offerResume() async {
    if (!mounted) return;
    final AppState state = context.read<AppState>();
    final SavedGame? saved = SavedGame.fromJson(state.savedGame);
    if (saved == null) return;

    final List<Player> players = saved.playersFrom(state.roster);
    if (!saved.isFresh || saved.turn == 0 || players.length < 2) {
      await state.clearSavedGame();
      return;
    }
    final List<GameMode> modes = <GameMode>[
      for (final GameModeId id in saved.modes)
        ...kGameModes.where((GameMode m) => m.id == id),
    ];
    if (modes.isEmpty || (saved.multi && modes.length < 2)) {
      await state.clearSavedGame();
      return;
    }

    final Object? rawSips = saved.score['sips'];
    final int sips = rawSips is Map
        ? rawSips.values.whereType<num>().fold<int>(
              0,
              (int sum, num v) => sum + v.toInt(),
            )
        : 0;
    final Duration ago = DateTime.now().difference(saved.savedAt);
    final String when = ago.inMinutes < 1
        ? 'à l’instant'
        : ago.inHours < 1
            ? 'il y a ${ago.inMinutes} min'
            : 'il y a ${ago.inHours} h';
    final String title = saved.multi ? 'Multi-jeu' : modes.first.title;

    Haptics.medium();
    final bool? resume = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(
          'Reprendre la partie ?',
          style: dialogContext.text.titleLarge,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '$title · ${saved.turn} tours · $sips gorgées',
              style: dialogContext.text.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            _AvatarStack(players: players),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${players.map((Player p) => p.name).join(', ')}\n'
              'Interrompue $when.',
              style: dialogContext.text.bodyMedium,
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Nouvelle partie'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reprendre'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (resume != true) {
      await state.clearSavedGame();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => saved.multi
            ? MultiJeuLauncher(modes: modes, resume: saved)
            : GameLauncher(mode: modes.first, resume: saved),
      ),
    );
  }

  void _onScroll() {
    _offset.value = _scroll.offset;
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    _offset.dispose();
    super.dispose();
  }

  Map<Intensity, int> _globalCounts() {
    final int custom = context.read<AppState>().customCardCount;
    if (_cachedCounts != null && custom == _cachedCustomCount) {
      return _cachedCounts!;
    }

    final Map<Intensity, int> counts = <Intensity, int>{};
    for (final Intensity level in Intensity.values) {
      int total = 0;
      for (final GameMode mode in kGameModes) {
        final PromptPack? pack = ContentService.instance.cached(mode.id);
        if (pack != null) total += pack.countAt(level);
      }
      counts[level] = total;
    }
    _cachedCounts = counts;
    _cachedCustomCount = custom;
    return counts;
  }

  void _openMode(GameMode mode) {
    Haptics.medium();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ModeIntroSheet(mode: mode),
    );
  }

  void _openMultiplayer() {
    Haptics.medium();
    Navigator.of(context).push(
      ForwardRoute<void>(
        builder: (_) => const MultiplayerHomeScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    final Map<Intensity, int> counts = _globalCounts();

    return Scaffold(
      body: AmbientBackground(
        primary: state.intensity.color,
        secondary: AppColors.accent,
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            controller: _scroll,
            scrollCacheExtent: const ScrollCacheExtent.pixels(800),
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: _ParallaxHeader(
                  offset: _offset,
                  child: _Header(state: state),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: AppSpacing.screen.copyWith(top: AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const SectionTitle('INTENSITÉ'),
                      IntensitySelector(cardCounts: counts),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(delay: 180.ms, duration: 400.ms)
                    .slideY(begin: 0.1, curve: Curves.easeOutCubic),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: AppSpacing.screen.copyWith(top: AppSpacing.xl),
                  child: SectionTitle(
                    'LES JEUX',
                    trailing: '${kGameModes.length} modes',
                  ),
                ),
              ),
              SliverPadding(
                padding: AppSpacing.screen,
                sliver: SliverList.separated(
                  itemCount: kGameModes.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (BuildContext context, int i) {
                    final GameMode mode = kGameModes[i];
                    final PromptPack? pack =
                        ContentService.instance.cached(mode.id);

                    return RepaintBoundary(
                      child: _ModeCard(
                        mode: mode,
                        cardCount: pack?.countAt(state.intensity) ?? 0,
                        onTap: () => _openMode(mode),
                      )
                          .animate()
                          .fadeIn(delay: (260 + i * 90).ms, duration: 420.ms)
                          .slideY(begin: 0.14, curve: Curves.easeOutCubic)
                          .scaleXY(begin: 0.96, curve: Curves.easeOutCubic),
                    );
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: AppSpacing.screen.copyWith(top: AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const SectionTitle('MULTI-JEU'),
                      RepaintBoundary(
                        child: _ModeCard(
                          mode: kMultiJeuMode,
                          cardCount: counts[state.intensity] ?? 0,
                          onTap: () {
                            Haptics.medium();
                            MultiJeuSheet.show(context);
                          },
                        )
                            .animate()
                            .fadeIn(
                              delay: (260 + kGameModes.length * 90).ms,
                              duration: 420.ms,
                            )
                            .slideY(begin: 0.14, curve: Curves.easeOutCubic)
                            .scaleXY(begin: 0.96, curve: Curves.easeOutCubic),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: AppSpacing.screen.copyWith(top: AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const SectionTitle('MULTIJOUEUR LOCAL'),
                      RepaintBoundary(
                        child: _ModeCard(
                          mode: kMultiplayerMode,
                          cardCount: counts[state.intensity] ?? 0,
                          onTap: _openMultiplayer,
                        )
                            .animate()
                            .fadeIn(
                              delay: (260 + (kGameModes.length + 1) * 90).ms,
                              duration: 420.ms,
                            )
                            .slideY(begin: 0.14, curve: Curves.easeOutCubic)
                            .scaleXY(begin: 0.96, curve: Curves.easeOutCubic),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: AppSpacing.screen.copyWith(
                    top: AppSpacing.xl,
                    bottom:
                        AppSpacing.xxl + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: Center(
                    child: Text(
                      state.gamesPlayed == 0
                          ? 'Hors-ligne · sans publicité · sans compte'
                          : '${state.gamesPlayed} parties jouées',
                      style: context.text.bodySmall?.copyWith(fontSize: 11.5),
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

class _ParallaxHeader extends StatelessWidget {
  const _ParallaxHeader({required this.offset, required this.child});

  final ValueNotifier<double> offset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: offset,
      child: child,
      builder: (BuildContext context, Widget? built) {
        final double value = offset.value < 0 ? 0 : offset.value;
        final double fade = (1 - value / 220).clamp(0.0, 1.0);

        return Transform.translate(
          offset: Offset(0, value * 0.3),
          child: fade >= 1 ? built : Opacity(opacity: fade, child: built),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state});

  final AppState state;

  void _openSettings(BuildContext context) {
    Haptics.light();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    final List<Player> selected = state.players;

    return Padding(
      padding: AppSpacing.screen.copyWith(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Image.asset(
                'assets/images/logo_cul_sec.png',
                height: 46,
                cacheHeight: 138,
                filterQuality: FilterQuality.medium,
              ),
              const Spacer(),
              AppPill(
                padding: const EdgeInsets.all(10),
                onTap: () => _openSettings(context),
                child: Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Cul Sec !',
            style: context.text.displayMedium?.copyWith(fontSize: 46),
          ),
          const SizedBox(height: AppSpacing.md),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openSettings(context),
            child: Row(
              children: <Widget>[
                if (selected.isNotEmpty) ...<Widget>[
                  _AvatarStack(players: selected),
                  const SizedBox(width: AppSpacing.sm + 2),
                ],
                Flexible(
                  child: Text(
                    selected.isEmpty
                        ? 'Aucun joueur — touchez pour en ajouter'
                        : selected.length == 1
                            ? '1 joueur à table'
                            : '${selected.length} joueurs à table',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyMedium,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 17,
                  color: colors.textMuted,
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 420.ms)
        .slideY(begin: -0.08, curve: Curves.easeOutCubic);
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.players});

  final List<Player> players;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    final List<Player> shown = players.take(4).toList();
    final int extra = players.length - shown.length;
    final int slots = shown.length + (extra > 0 ? 1 : 0);

    return SizedBox(
      height: 30,
      width: 30 + (slots - 1) * 20,
      child: Stack(
        children: <Widget>[
          for (int i = 0; i < shown.length; i++)
            Positioned(
              left: i * 20,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.ink,
                ),
                padding: const EdgeInsets.all(2),
                child: AvatarView.fromPlayer(
                  shown[i],
                  size: 26,
                  showRing: false,
                ),
              ),
            ),
          if (extra > 0)
            Positioned(
              left: shown.length * 20,
              child: Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.fillStrong,
                  border: Border.all(color: colors.ink, width: 2),
                ),
                child: Text(
                  '+$extra',
                  style: context.text.labelMedium?.copyWith(
                    fontSize: 10,
                    letterSpacing: 0,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatefulWidget {
  const _ModeCard({
    required this.mode,
    required this.cardCount,
    required this.onTap,
  });

  final GameMode mode;
  final int cardCount;
  final VoidCallback onTap;

  @override
  State<_ModeCard> createState() => _ModeCardState();
}

class _ModeCardState extends State<_ModeCard> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v && mounted) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    final GameMode mode = widget.mode;

    final Color borderColor =
        _pressed ? mode.color : mode.color.withValues(alpha: 0.35);
    final Color accentSoft = mode.color.withValues(alpha: 0.9);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1,
        duration: AppMotion.fast,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          height: 132,
          decoration: BoxDecoration(
            borderRadius: AppRadii.bigCard,
            boxShadow: _pressed
                ? AppShadows.glow(mode.color, opacity: 0.35)
                : AppShadows.card,
          ),
          child: ClipRRect(
            borderRadius: AppRadii.bigCard,
            clipBehavior: Clip.hardEdge,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: <Color>[
                        Color.lerp(colors.surface, mode.color, 0.26)!,
                        Color.lerp(colors.surface, mode.colorAlt, 0.08)!,
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: -20,
                  top: -14,
                  child: Icon(
                    mode.icon,
                    size: 150,
                    color: mode.color.withValues(alpha: 0.13),
                  ),
                ),
                AnimatedContainer(
                  duration: AppMotion.fast,
                  decoration: BoxDecoration(
                    borderRadius: AppRadii.bigCard,
                    border: Border.all(
                      color: borderColor,
                      width: _pressed ? 2 : 1.2,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md + 2),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: mode.color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(AppRadii.sm + 3),
                          border: Border.all(
                            color: mode.color.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Icon(mode.icon, size: 23, color: mode.color),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text(
                              mode.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.headlineMedium?.copyWith(
                                fontSize: 20,
                                color: colors.textPrimary, // <-- Modifié (sur fond de carte)
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              mode.tagline,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.bodyMedium?.copyWith(
                                fontSize: 13,
                                color: colors.textSecondary, // <-- Modifié
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: <Widget>[
                                Icon(
                                  Icons.style_rounded,
                                  size: 12,
                                  color: accentSoft,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '${widget.cardCount} cartes',
                                  style: context.text.bodySmall?.copyWith(
                                    fontSize: 11.5,
                                    color: colors.textMuted, // <-- Modifié
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: mode.color,
                          boxShadow: AppShadows.glow(mode.color),
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          size: 21,
                          color: colors.textOnAccent, // <-- Modifié
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}