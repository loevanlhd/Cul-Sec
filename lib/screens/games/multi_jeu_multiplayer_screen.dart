import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../data/game_modes_catalog.dart';
import '../../models/enums.dart';
import '../../models/game_mode.dart';
import '../../multiplayer/client_game_controller.dart';
import '../../multiplayer/game_message.dart';
import '../../multiplayer/host_game_controller.dart';
import '../../multiplayer/multiplayer_end_screen.dart';
import '../../multiplayer/multiplayer_session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/common.dart';
import 'action_verite_multiplayer_screen.dart';
import 'je_nai_jamais_multiplayer_screen.dart';
import 'qui_pourrait_multiplayer_screen.dart';
import 'tu_preferes_multiplayer_screen.dart';

class MultiJeuMultiplayerScreen extends StatelessWidget {
  const MultiJeuMultiplayerScreen({
    super.key,
    this.hostController,
    this.clientController,
    this.onQuit,
  }) : assert(hostController != null || clientController != null, 'Il faut au moins un contrôleur.');

  final HostGameController? hostController;
  final ClientGameController? clientController;
  final VoidCallback? onQuit;

  bool get isHost => hostController != null;

  Listenable get _listenables => Listenable.merge([hostController, clientController]);

  MultiplayerSnapshot? get _snapshot => hostController?.snapshot ?? clientController?.snapshot;

  GameModeId _modeIdFromSlug(String slug) {
    for (final GameModeId id in GameModeId.values) {
      if (id.slug == slug) return id;
    }
    return GameModeId.tuPreferes;
  }

  void _showReactionMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(ctx).bottom + 16),
        decoration: BoxDecoration(
          color: ctx.culColors.surfaceTop,
          borderRadius: AppRadii.sheet,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['😂', '🔥', '🍻', '😱', '💩'].map((e) => 
            IconButton(
              icon: Text(e, style: const TextStyle(fontSize: 32)),
              onPressed: () {
                Navigator.pop(ctx);
                if (isHost) {
                  hostController!.transport.broadcast(GameMessage(
                    type: 'reaction', 
                    senderId: hostController!.transport.selfId, 
                    payload: {'emoji': e, 'name': 'Hôte'},
                  ),);
                } else {
                  clientController!.sendReaction(e, clientController!.assignedName ?? 'Joueur');
                }
              },
            ),
          ).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _listenables,
      builder: (BuildContext context, Widget? _) {
        if (!isHost && clientController?.disconnected.value == true) {
          return Scaffold(
            body: AmbientBackground(
              primary: AppColors.danger,
              child: Center(
                child: Padding(
                  padding: AppSpacing.screen,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.link_off_rounded, size: 64, color: AppColors.danger),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'L’hôte a quitté la partie',
                        textAlign: TextAlign.center,
                        style: context.text.headlineLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'La connexion avec l’appareil hôte a été perdue.',
                        textAlign: TextAlign.center,
                        style: context.text.bodyLarge,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      AppButton(
                        label: 'Retour à l’accueil',
                        color: AppColors.danger,
                        onPressed: () {
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        final MultiplayerSnapshot? snapshot = _snapshot;

        if (snapshot == null || snapshot.modeId.isEmpty) {
          return _Loader(onQuit: onQuit);
        }

        // --- Retour au lobby après une partie ---
        if (snapshot.modeId == 'lobby') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted && Navigator.canPop(context)) {
              Navigator.of(context).pop();
            }
          });
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.phase == MultiplayerPhase.finished && snapshot.endGameData != null) {
          return MultiplayerEndScreen(
            data: snapshot.endGameData!,
            isHost: isHost,
            onQuit: onQuit ?? () => Navigator.of(context).pop(),
            onReplay: () {
              if (isHost) {
                hostController!.resetForReplay();
              }
            },
          );
        }

        final GameModeId modeId = _modeIdFromSlug(snapshot.modeId);
        final GameMode mode = gameModeById(modeId);

        return Stack(
          children: [
            Positioned.fill(
              child: KeyedSubtree(
                key: ValueKey<String>('mode-${snapshot.modeId}'),
                child: switch (modeId) {
                  GameModeId.tuPreferes => TuPreferesMultiplayerScreen(mode: mode, hostController: hostController, clientController: clientController, onQuit: onQuit),
                  GameModeId.quiPourrait => QuiPourraitMultiplayerScreen(mode: mode, hostController: hostController, clientController: clientController, onQuit: onQuit),
                  GameModeId.jeNaiJamais => JeNaiJamaisMultiplayerScreen(mode: mode, hostController: hostController, clientController: clientController, onQuit: onQuit),
                  GameModeId.actionOuVerite => ActionVeriteMultiplayerScreen(mode: mode, hostController: hostController, clientController: clientController, onQuit: onQuit),
                },
              ),
            ),

            // Bouton de réaction
            Positioned(
              bottom: 24, right: 20,
              child: FloatingActionButton(
                mini: true,
                backgroundColor: context.culColors.surfaceTop,
                child: const Text('😂', style: TextStyle(fontSize: 24)),
                onPressed: () => _showReactionMenu(context),
              ),
            ),

            // Affichage des emojis flottants
            if (isHost)
              ValueListenableBuilder<Map<String, String>?>(
                valueListenable: hostController!.lastReaction,
                builder: (context, reaction, _) {
                  if (reaction == null) return const SizedBox.shrink();
                  return _FloatingEmoji(
                    key: ValueKey(reaction.hashCode),
                    reaction: reaction,
                  );
                },
              )
            else
              ValueListenableBuilder<Map<String, String>?>(
                valueListenable: clientController!.lastReaction,
                builder: (context, reaction, _) {
                  if (reaction == null) return const SizedBox.shrink();
                  return _FloatingEmoji(
                    key: ValueKey(reaction.hashCode),
                    reaction: reaction,
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class _FloatingEmoji extends StatelessWidget {
  final Map<String, String> reaction;
  const _FloatingEmoji({super.key, required this.reaction});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 100,
      left: 20,
      child: Material(
        color: Colors.transparent,
        child: Text(
          '${reaction['emoji']} par ${reaction['name']}', 
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        )
            .animate()
            .slideY(begin: 0, end: -2, duration: 2.seconds)
            .fadeOut(delay: 1.5.seconds),
      ),
    );
  }
}

class _Loader extends StatelessWidget {
  const _Loader({required this.onQuit});

  final VoidCallback? onQuit;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
          child: Stack(
            children: <Widget>[
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const CircularProgressIndicator(color: AppColors.accent),
                    const SizedBox(height: AppSpacing.lg),
                    Text('Préparation du multi-jeu…', style: context.text.bodyLarge),
                  ],
                ),
              ),
              if (onQuit != null)
                Positioned(
                  top: 8,
                  left: 8,
                  child: AppPill(
                    padding: const EdgeInsets.all(12),
                    onTap: onQuit,
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: Icon(Icons.close_rounded, size: 22, color: colors.textSecondary),
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