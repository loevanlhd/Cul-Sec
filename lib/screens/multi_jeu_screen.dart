import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../data/game_modes_catalog.dart';
import '../models/enums.dart';
import '../models/game_mode.dart';
import '../models/player.dart';
import '../services/app_state.dart';
import '../services/game_session.dart';
import '../services/haptics.dart';
import '../services/round_events.dart';
import '../services/saved_game.dart';
import '../theme/app_theme.dart';
import '../widgets/ambient_background.dart';
import '../widgets/common.dart';
import '../widgets/round_overlays.dart';
import 'end_screen.dart';
import 'game_launcher.dart';
import 'settings_screen.dart';

/// Mode « virtuel » du multi-jeu, utilisé pour l'écran de fin.
const GameMode kMultiJeuMode = GameMode(
  id: GameModeId.actionOuVerite,
  title: 'Multi-jeu',
  tagline: 'Le jeu change à chaque manche',
  rules: 'Choisissez 2 à 4 jeux : à chaque manche, l’un d’eux est tiré au '
      'hasard. Les gorgées s’additionnent sur toute la partie.',
  howTo: <String>[
    'Choisissez les jeux du mélange',
    'Chaque manche tire un jeu au hasard',
    'Le récapitulatif compte toutes les gorgées',
  ],
  icon: Icons.shuffle_rounded,
  color: AppColors.accent,
  colorAlt: AppColors.accentDeep,
);

/// Exposé aux écrans de jeu pendant un multi-jeu : la sortie de partie
/// affiche le récapitulatif global et « Rejouer » relance le même mélange.
class MultiJeuController {
  MultiJeuController({required this.modes, required this.onFinish});

  final List<GameMode> modes;
  final void Function(BuildContext context) onFinish;

  void finish(BuildContext context) => onFinish(context);
}

// ---------------------------------------------------------------------------
// Feuille de sélection
// ---------------------------------------------------------------------------

/// Choix des jeux du mélange (2 à 4), ouvert depuis l'accueil.
class MultiJeuSheet extends StatefulWidget {
  const MultiJeuSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const MultiJeuSheet(),
    );
  }

  @override
  State<MultiJeuSheet> createState() => _MultiJeuSheetState();
}

class _MultiJeuSheetState extends State<MultiJeuSheet> {
  /// Par défaut, tous les jeux sont dans le mélange.
  final Set<GameModeId> _chosen =
      kGameModes.map((GameMode m) => m.id).toSet();

  void _toggle(GameMode mode) {
    Haptics.tick();
    setState(() {
      if (!_chosen.remove(mode.id)) _chosen.add(mode.id);
    });
  }

  void _start(List<GameMode> modes) {
    Haptics.medium();
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => MultiJeuLauncher(modes: modes)),
    );
  }

  void _openSettings() {
    Haptics.light();
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors; // <-- Modifié
    final AppState state = context.watch<AppState>();
    final int players = state.selectedCount;

    bool playable(GameMode m) => players >= m.minPlayers;

    final List<GameMode> selected = kGameModes
        .where((GameMode m) => _chosen.contains(m.id) && playable(m))
        .toList();
    final bool enoughPlayers = state.hasEnoughPlayers;
    final bool canStart = enoughPlayers && selected.length >= 2;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceTop, // <-- Modifié
        borderRadius: AppRadii.sheet,
        border: Border(
          top: BorderSide(
            color: kMultiJeuMode.color.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
      ),
      padding: AppSpacing.screen.copyWith(
        top: AppSpacing.sm + 2,
        bottom: AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border, // <-- Modifié
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                Container(
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AppGradients.pair(
                      kMultiJeuMode.color.withValues(alpha: 0.28),
                      kMultiJeuMode.colorAlt.withValues(alpha: 0.12),
                    ),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(
                      color: kMultiJeuMode.color.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Icon(
                    kMultiJeuMode.icon,
                    size: 26,
                    color: kMultiJeuMode.color,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        kMultiJeuMode.title,
                        style: context.text.headlineLarge,
                      ),
                      Text(
                        kMultiJeuMode.tagline,
                        style: context.text.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(kMultiJeuMode.rules, style: context.text.bodyLarge),
            const SizedBox(height: AppSpacing.lg),
            SectionTitle(
              'JEUX DU MÉLANGE',
              trailing: '${selected.length} choisis',
            ),
            for (final GameMode mode in kGameModes) ...<Widget>[
              _ModeToggle(
                mode: mode,
                selected: _chosen.contains(mode.id) && playable(mode),
                enabled: playable(mode),
                disabledReason: '${mode.minPlayers} joueurs minimum',
                onTap: () => _toggle(mode),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.md),
            const SectionTitle('OPTIONS'),
            _OptionRow(
              icon: Icons.casino_rounded,
              title: 'Roulette',
              subtitle: 'Une roue tire le jeu avant chaque manche',
              value: state.rouletteEnabled,
              onChanged: state.setRouletteEnabled,
            ),
            const SizedBox(height: AppSpacing.sm),
            _OptionRow(
              icon: Icons.bolt_rounded,
              title: 'Cartes Événement',
              subtitle: 'Surprises entre deux manches',
              value: state.eventsEnabled,
              onChanged: state.setEventsEnabled,
            ),
            const SizedBox(height: AppSpacing.md),
            if (!enoughPlayers)
              _Hint(
                text: 'Il faut au moins 2 joueurs sélectionnés.',
                action: 'Joueurs',
                onAction: _openSettings,
              )
            else if (selected.length < 2)
              const _Hint(text: 'Choisissez au moins 2 jeux.'),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: canStart
                  ? 'Lancer le multi-jeu · ${selected.length} jeux'
                  : 'Lancer le multi-jeu',
              icon: Icons.shuffle_rounded,
              color: kMultiJeuMode.color,
              onPressed: canStart ? () => _start(selected) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors; // <-- Modifié
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md - 2,
        vertical: AppSpacing.sm + 3,
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: colors.textSecondary), // <-- Modifié
          const SizedBox(width: AppSpacing.md - 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: context.text.titleMedium?.copyWith(fontSize: 15),
                ),
                Text(
                  subtitle,
                  style: context.text.bodySmall?.copyWith(fontSize: 11.5),
                ),
              ],
            ),
          ),
          MiniSwitch(
            value: value,
            onChanged: (bool v) {
              Haptics.tick();
              onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({
    required this.mode,
    required this.selected,
    required this.enabled,
    required this.disabledReason,
    required this.onTap,
  });

  final GameMode mode;
  final bool selected;
  final bool enabled;
  final String disabledReason;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors; // <-- Modifié
    return AnimatedOpacity(
      duration: AppMotion.base,
      opacity: enabled ? 1 : 0.45,
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md - 2,
          vertical: AppSpacing.sm + 3,
        ),
        accent: selected ? mode.color : null,
        onTap: enabled ? onTap : null,
        child: Row(
          children: <Widget>[
            Icon(mode.icon, size: 20, color: mode.color),
            const SizedBox(width: AppSpacing.md - 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    mode.title,
                    style: context.text.titleMedium?.copyWith(fontSize: 15),
                  ),
                  if (!enabled)
                    Text(
                      disabledReason,
                      style: context.text.bodySmall?.copyWith(fontSize: 11.5),
                    ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: AppMotion.base,
              curve: AppMotion.emphasized,
              width: 23,
              height: 23,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? mode.color : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: selected ? mode.color : colors.border, // <-- Modifié
                  width: 1.6,
                ),
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text, this.action, this.onAction});

  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Icon(
          Icons.info_outline_rounded,
          size: 16,
          color: AppColors.warning,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: context.text.bodySmall?.copyWith(color: AppColors.warning),
          ),
        ),
        if (action != null)
          TextButton(onPressed: onAction, child: Text(action!)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Chargement
// ---------------------------------------------------------------------------

/// Prépare une session par jeu choisi, toutes reliées au même score.
class MultiJeuLauncher extends StatefulWidget {
  const MultiJeuLauncher({super.key, required this.modes, this.resume});

  final List<GameMode> modes;

  /// Partie sauvegardée à reprendre, le cas échéant.
  final SavedGame? resume;

  @override
  State<MultiJeuLauncher> createState() => _MultiJeuLauncherState();
}

class _MultiJeuLauncherState extends State<MultiJeuLauncher> {
  late final Future<Map<GameModeId, GameSession>> _future = _build();

  Future<Map<GameModeId, GameSession>> _build() async {
    final AppState state = context.read<AppState>();
    await Future<void>.delayed(Duration.zero);

    final SavedGame? resume = widget.resume;
    final List<Player> players =
        resume?.playersFrom(state.roster) ?? state.players;
    final SessionScore score = resume?.restoreScore() ?? SessionScore();
    final Map<GameModeId, GameSession> sessions = <GameModeId, GameSession>{};
    for (final GameMode mode in widget.modes) {
      sessions[mode.id] = await buildGameSession(
        state,
        mode,
        score: score,
        players: players,
      );
    }
    // Un multi-jeu compte pour une seule partie (déjà comptée si reprise).
    if (resume == null) await state.incrementGamesPlayed();
    SavedGame.attach(
      state,
      score,
      multi: true,
      modes: widget.modes.map((GameMode m) => m.id).toList(),
      players: players,
    );
    return sessions;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<GameModeId, GameSession>>(
      future: _future,
      builder: (
        BuildContext context,
        AsyncSnapshot<Map<GameModeId, GameSession>> snapshot,
      ) {
        if (snapshot.hasError) {
          return Scaffold(
            body: AmbientBackground(
              child: Center(
                child: Padding(
                  padding: AppSpacing.screen,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'Impossible de charger les cartes.',
                        style: context.text.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppButton(
                        label: 'Retour',
                        expand: false,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return Scaffold(
            body: AmbientBackground(
              primary: kMultiJeuMode.color,
              secondary: kMultiJeuMode.colorAlt,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      kMultiJeuMode.icon,
                      size: 42,
                      color: kMultiJeuMode.color,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text('On mélange les jeux…', style: context.text.bodyLarge),
                  ],
                ),
              ),
            ),
          );
        }
        return MultiJeuScreen(
          modes: widget.modes,
          sessions: snapshot.data!,
          resumed: widget.resume != null,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Partie
// ---------------------------------------------------------------------------

/// Enchaîne les manches : à chaque fin de manche, un jeu est tiré au hasard
/// parmi ceux choisis. Gorgées, tours et ordre de passage sont communs.
class MultiJeuScreen extends StatefulWidget {
  const MultiJeuScreen({
    super.key,
    required this.modes,
    required this.sessions,
    this.resumed = false,
  });

  final List<GameMode> modes;
  final Map<GameModeId, GameSession> sessions;

  /// Partie reprise : pas de roulette d'ouverture.
  final bool resumed;

  @override
  State<MultiJeuScreen> createState() => _MultiJeuScreenState();
}

class _MultiJeuScreenState extends State<MultiJeuScreen> {
  final math.Random _random = math.Random();
  late final MultiJeuController _controller = MultiJeuController(
    modes: widget.modes,
    onFinish: _finish,
  );

  late GameMode _mode;
  int _round = 0;
  bool _finished = false;

  final EventDeck _events = EventDeck();

  /// Une carte Événement ou la roulette est affichée.
  bool _transitioning = false;

  /// La pastille du jeu n'est utile que sans roulette.
  bool _showBanner = true;

  @override
  void initState() {
    super.initState();
    for (final GameSession s in widget.sessions.values) {
      s.onRoundEnd = _nextRound;
    }
    _mode = _pick();
    _prepare(_mode);
    _showBanner =
        widget.resumed || !context.read<AppState>().rouletteEnabled;

    // Roulette d'ouverture : le premier jeu est tiré devant tout le monde.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || widget.resumed) return;
      if (!context.read<AppState>().rouletteEnabled) return;
      _transitioning = true;
      try {
        await showRouletteDialog(context, modes: widget.modes, target: _mode);
      } finally {
        _transitioning = false;
      }
    });
  }

  @override
  void dispose() {
    for (final GameSession s in widget.sessions.values) {
      s.onRoundEnd = null;
    }
    super.dispose();
  }

  /// Tirage totalement aléatoire parmi les jeux choisis.
  GameMode _pick() => widget.modes[_random.nextInt(widget.modes.length)];

  GameSession get _session => widget.sessions[_mode.id]!;

  /// Les jeux à carte unique tirent leur carte avant l'affichage ;
  /// Action ou Vérité tire la sienne après le choix du joueur.
  void _prepare(GameMode mode) {
    if (mode.id != GameModeId.actionOuVerite) {
      widget.sessions[mode.id]!.prepareRound();
    }
  }

  Future<void> _nextRound() async {
    if (!mounted || _finished || _transitioning) return;
    _transitioning = true;
    try {
      final AppState state = context.read<AppState>();

      // Carte Événement entre deux manches.
      if (state.eventsEnabled && _events.shouldTrigger()) {
        final RoundEvent? event = _events.draw(_session);
        if (event != null) {
          await showEventDialog(context, _session, event);
          if (!mounted || _finished) return;
        }
      }

      final GameMode next = _pick();
      final bool roulette = state.rouletteEnabled && widget.modes.length > 1;
      if (roulette) {
        await showRouletteDialog(context, modes: widget.modes, target: next);
        if (!mounted || _finished) return;
      } else {
        Haptics.light();
      }

      _prepare(next);
      setState(() {
        _mode = next;
        _round++;
        _showBanner = !roulette;
      });
    } finally {
      _transitioning = false;
    }
  }

  void _finish(BuildContext context) {
    if (_finished) return;
    _finished = true;
    for (final GameSession s in widget.sessions.values) {
      s.onRoundEnd = null;
    }
    final List<GameMode> modes = widget.modes;
    final NavigatorState navigator = Navigator.of(context);
    navigator.pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: AppMotion.slow,
        pageBuilder: (_, __, ___) => EndScreen(
          mode: kMultiJeuMode,
          session: _session,
          onReplay: () => navigator.pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => MultiJeuLauncher(modes: modes),
            ),
          ),
        ),
        transitionsBuilder: (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondary,
          Widget child,
        ) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final GameMode mode = _mode;

    return Provider<MultiJeuController?>.value(
      value: _controller,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: AppMotion.slow,
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (Widget child, Animation<double> anim) =>
                  AnimatedBuilder(
                animation: anim,
                // L'écran sortant ne réagit plus aux touches : impossible
                // de sauter une manche par un double appui.
                builder: (BuildContext context, Widget? built) =>
                    IgnorePointer(
                  ignoring: anim.status == AnimationStatus.reverse ||
                      anim.status == AnimationStatus.dismissed,
                  child: built,
                ),
                child: FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.97, end: 1).animate(anim),
                    child: child,
                  ),
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey<int>(_round),
                child: ChangeNotifierProvider<GameSession>.value(
                  value: _session,
                  child: gameScreenFor(mode),
                ),
              ),
            ),
          ),
          // Annonce du jeu de la manche.
          Positioned(
            left: 0,
            right: 0,
            top: MediaQuery.paddingOf(context).top + 64,
            child: IgnorePointer(
              child: Center(
                child: _showBanner
                    ? _RoundBanner(key: ValueKey<int>(_round), mode: mode)
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundBanner extends StatelessWidget {
  const _RoundBanner({super.key, required this.mode});

  final GameMode mode;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors; // <-- Modifié
    return Material(
      type: MaterialType.transparency,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surfaceTop, // <-- Modifié
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: mode.color, width: 1.5),
          boxShadow: AppShadows.glow(mode.color, opacity: 0.35),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.shuffle_rounded,
              size: 15,
              color: colors.textSecondary, // <-- Modifié
            ),
            const SizedBox(width: 8),
            Icon(mode.icon, size: 16, color: mode.color),
            const SizedBox(width: 6),
            Text(
              mode.title,
              style: context.text.titleMedium?.copyWith(
                fontSize: 14,
                color: mode.color,
              ),
            ),
          ],
        ),
      )
          .animate()
          .fadeIn(duration: 220.ms)
          .scaleXY(begin: 0.85, curve: Curves.easeOutBack)
          .then(delay: 1100.ms)
          .fadeOut(duration: 350.ms),
    );
  }
}