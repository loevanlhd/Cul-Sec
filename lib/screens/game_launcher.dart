import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/game_mode.dart';
import '../models/player.dart';
import '../models/prompt.dart';
import '../services/app_state.dart';
import '../services/content_service.dart';
import '../services/game_session.dart';
import '../services/round_events.dart';
import '../services/saved_game.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/round_overlays.dart';
import 'games/action_verite_screen.dart';
import 'games/je_nai_jamais_screen.dart';
import 'games/qui_pourrait_screen.dart';
import 'games/tu_preferes_screen.dart';

Future<GameSession> buildGameSession(
  AppState state,
  GameMode mode, {
  SessionScore? score,
  List<Player>? players,
}) async {
  final PromptPack pack = await ContentService.instance.load(mode.id);
  final Set<GameCategory> cats = state.categories;

  List<Prompt> prompts = pack.filtered(state.intensity, categories: cats);

  if (prompts.isEmpty) prompts = pack.filtered(state.intensity);
  if (prompts.isEmpty) prompts = pack.filtered(Intensity.soft);

  return GameSession(
    players: players ?? state.players,
    intensity: state.intensity,
    rules: state.gameRules,
    prompts: prompts,
    maxGorgeesParTour: math.max(pack.maxGorgeesParTour, state.gameRules.highest),
    seenIds: state.seenCards,
    onSeen: state.markCardSeen,
    onForget: state.forgetSeenCards,
    score: score,
  );
}

Widget gameScreenFor(GameMode mode) => switch (mode.id) {
      GameModeId.actionOuVerite => ActionVeriteScreen(mode: mode),
      GameModeId.jeNaiJamais => JeNaiJamaisScreen(mode: mode),
      GameModeId.tuPreferes => TuPreferesScreen(mode: mode),
      GameModeId.quiPourrait => QuiPourraitScreen(mode: mode),
    };

class GameLauncher extends StatefulWidget {
  const GameLauncher({super.key, required this.mode, this.resume});

  final GameMode mode;
  final SavedGame? resume;

  @override
  State<GameLauncher> createState() => _GameLauncherState();
}

class _GameLauncherState extends State<GameLauncher> {
  late final Future<GameSession> _future = _build();

  Future<GameSession> _build() async {
    final AppState state = context.read<AppState>();
    await Future<void>.delayed(Duration.zero);

    final SavedGame? resume = widget.resume;
    final List<Player> players =
        resume?.playersFrom(state.roster) ?? state.players;
    final SessionScore score = resume?.restoreScore() ?? SessionScore();

    final GameSession session = await buildGameSession(
      state,
      widget.mode,
      score: score,
      players: players,
    );
    if (resume == null) await state.incrementGamesPlayed();

    SavedGame.attach(
      state,
      score,
      multi: false,
      modes: <GameModeId>[widget.mode.id],
      players: players,
    );
    session.onRoundComplete = _onRoundComplete;
    return session;
  }

  final EventDeck _events = EventDeck();
  bool _eventShowing = false;

  Future<void> _onRoundComplete() async {
    if (!mounted || _eventShowing) return;
    final AppState state = context.read<AppState>();
    if (!state.eventsEnabled || !_events.shouldTrigger()) return;
    final GameSession session = await _future;
    final RoundEvent? event = _events.draw(session);
    if (event == null || !mounted) return;
    _eventShowing = true;
    try {
      await showEventDialog(context, session, event);
    } finally {
      _eventShowing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GameSession>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<GameSession> snapshot) {
        if (snapshot.hasError) return _ErrorScreen(mode: widget.mode);
        if (!snapshot.hasData) return _LoadingScreen(mode: widget.mode);

        return ChangeNotifierProvider<GameSession>.value(
          value: snapshot.data!,
          child: gameScreenFor(widget.mode),
        );
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen({required this.mode});

  final GameMode mode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.culColors.ink, // <-- Modifié
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(mode.icon, size: 42, color: mode.color),
            const SizedBox(height: AppSpacing.lg),
            Text('On mélange les cartes…', style: context.text.bodyLarge),
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.mode});

  final GameMode mode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.culColors.ink, // <-- Modifié
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: AppSpacing.screen,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.report_gmailerrorred_rounded,
                  size: 42,
                  color: AppColors.warning,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Contenu introuvable',
                  style: context.text.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Le fichier assets/data/${mode.slug}.json n’a pas pu être '
                  'chargé. Vérifiez qu’il existe et qu’il est déclaré dans '
                  'pubspec.yaml, puis relancez l’application — un hot reload '
                  'ne suffit pas pour les assets.',
                  style: context.text.bodyMedium,
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
}