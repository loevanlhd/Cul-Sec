import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:nsd/nsd.dart' as nsd;
import 'package:provider/provider.dart';

import '../data/game_modes_catalog.dart';
import '../models/enums.dart';
import '../models/game_mode.dart';
import '../models/player.dart';
import '../screens/game_launcher.dart';
import '../screens/games/action_verite_multiplayer_screen.dart';
import '../screens/games/je_nai_jamais_multiplayer_screen.dart';
import '../screens/games/multi_jeu_multiplayer_screen.dart';
import '../screens/games/qui_pourrait_multiplayer_screen.dart';
import '../screens/games/tu_preferes_multiplayer_screen.dart';
import '../services/app_state.dart';
import '../services/game_session.dart';
import '../services/haptics.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_view.dart';
import '../widgets/branded_qr.dart';
import 'host_game_controller.dart';
import 'local_transport.dart';
import 'mdns_helper.dart';
import 'multiplayer_session.dart';
import 'room_code.dart';

class _Selection {
  const _Selection({this.modeId, this.multiGame = false});
  final GameModeId? modeId;
  final bool multiGame;
}

class HostScreen extends StatefulWidget {
  const HostScreen({super.key, required this.hostPlayer});

  final Player hostPlayer;

  @override
  State<HostScreen> createState() => _HostScreenState();
}

class _HostScreenState extends State<HostScreen> {
  static const int _preferredPort = 40404;

  String? _roomCode;
  String? _localIp;
  int? _port;
  LocalTransport? _transport;
  nsd.Registration? _mdnsRegistration;
  String? _error;
  bool _waiting = true;

  HostGameController? _lobbyController;

  _Selection _selection = const _Selection(modeId: GameModeId.tuPreferes);
  bool _launching = false;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    if (kIsWeb) {
      setState(() {
        _waiting = false;
        _error = 'Le mode hôte n’est pas disponible sur le web.';
      });
      return;
    }
    try {
      final String code = RoomCode.generate();
      final ({LocalTransport transport, int port}) host =
          await LocalTransport.startHost(roomCode: code, port: _preferredPort);

      final String? ip = await NetworkInfo().getWifiIP();

      nsd.Registration? registration;
      try {
        registration = await MdnsHelper.register(
          roomCode: code,
          port: host.port,
        );
      } catch (e) {
        debugPrint('[mDNS] La recherche auto sera indisponible : $e');
      }

      if (!mounted) return;

      setState(() {
        _roomCode = code;
        _port = host.port;
        _localIp = ip;
        _transport = host.transport;
        _mdnsRegistration = registration;
        _waiting = false;
        _error = ip == null ? 'Aucune adresse Wi-Fi détectée.' : null;

        _lobbyController = HostGameController(
          transport: host.transport,
          hostPlayer: widget.hostPlayer,
        );
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _waiting = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  void dispose() {
    final nsd.Registration? reg = _mdnsRegistration;
    if (reg != null) unawaited(MdnsHelper.unregister(reg));
    _lobbyController?.dispose();
    unawaited(_transport?.close());
    super.dispose();
  }

  String get _inviteLink =>
      'culsec://join?ip=$_localIp&port=$_port&code=$_roomCode';

  Widget _gameScreenFor(HostGameController controller) {
    if (_selection.multiGame) {
      return MultiJeuMultiplayerScreen(
        hostController: controller,
        onQuit: () => Navigator.of(context).pop(),
      );
    }
    final GameMode mode = gameModeById(_selection.modeId!);
    return switch (_selection.modeId!) {
      GameModeId.tuPreferes => TuPreferesMultiplayerScreen(
          mode: mode,
          hostController: controller,
          onQuit: () => Navigator.of(context).pop(),
        ),
      GameModeId.quiPourrait => QuiPourraitMultiplayerScreen(
          mode: mode,
          hostController: controller,
          onQuit: () => Navigator.of(context).pop(),
        ),
      GameModeId.jeNaiJamais => JeNaiJamaisMultiplayerScreen(
          mode: mode,
          hostController: controller,
          onQuit: () => Navigator.of(context).pop(),
        ),
      GameModeId.actionOuVerite => ActionVeriteMultiplayerScreen(
          mode: mode,
          hostController: controller,
          onQuit: () => Navigator.of(context).pop(),
        ),
    };
  }

  Future<void> _launch() async {
    if (_launching || _transport == null || _lobbyController == null) return;

    final AppState state = context.read<AppState>();
    setState(() => _launching = true);

    try {
      final Map<String, GameSession> sessions = <String, GameSession>{};
      final List<Player> players = _lobbyController!.players;

      if (_selection.multiGame) {
        for (final GameMode m in kGameModes) {
          sessions[m.slug] = await buildGameSession(
            state,
            m,
            players: players,
          );
        }
        _lobbyController!.startGame(
          sessions: sessions,
          modeId: sessions.keys.first,
          multiGame: true,
        );
      } else {
        final GameMode mode = gameModeById(_selection.modeId!);
        sessions[mode.slug] = await buildGameSession(
          state,
          mode,
          players: players,
        );
        _lobbyController!.startGame(
          sessions: sessions,
          modeId: mode.slug,
          multiGame: false,
        );
      }

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _gameScreenFor(_lobbyController!),
        ),
      );
    } finally {
      if (mounted) setState(() => _launching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_lobbyController == null && _error == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Héberger · multijoueur local')),
      body: Center(
        child: _waiting
            ? const CircularProgressIndicator()
            : _error != null
                ? _ErrorView(message: _error!, onRetry: _start)
                : _HostContent(
                    roomCode: _roomCode!,
                    localIp: _localIp,
                    port: _port!,
                    qrData: _inviteLink,
                    lobbyController: _lobbyController!,
                    selection: _selection,
                    launching: _launching,
                    onSelect: (_Selection s) {
                      Haptics.tick();
                      setState(() => _selection = s);
                    },
                    onLaunch: _launch,
                  ),
      ),
    );
  }
}

class _HostContent extends StatelessWidget {
  const _HostContent({
    required this.roomCode,
    required this.localIp,
    required this.port,
    required this.qrData,
    required this.lobbyController,
    required this.selection,
    required this.launching,
    required this.onSelect,
    required this.onLaunch,
  });

  final String roomCode;
  final String? localIp;
  final int port;
  final String qrData;
  final HostGameController lobbyController;
  final _Selection selection;
  final bool launching;
  final ValueChanged<_Selection> onSelect;
  final Future<void> Function() onLaunch;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: lobbyController,
      builder: (BuildContext context, Widget? _) {
        final int maxPlayers = lobbyController.snapshot.players.length;
        final bool allConnected = maxPlayers >= 2;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Code de connexion',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                roomCode,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      letterSpacing: 8,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 24),
              Center(child: BrandedQr(data: qrData)),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  localIp != null
                      ? 'Adresse : $localIp:$port'
                      : 'Adresse Wi-Fi indisponible',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'À TABLE',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  for (int i = 0; i < maxPlayers; i++)
                    _LobbyAvatar(
                      player: lobbyController.snapshot.players[i],
                      isHost: i == 0,
                      isConnected: true,
                      onKick: (i == 0) ? null : () {
                        Haptics.heavy();
                        lobbyController.removePlayer(lobbyController.snapshot.players[i].id);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'MODE DE JEU',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  for (final GameModeId id in <GameModeId>[
                    GameModeId.tuPreferes,
                    GameModeId.quiPourrait,
                    GameModeId.jeNaiJamais,
                    GameModeId.actionOuVerite,
                  ])
                    _ModeChip(
                      mode: gameModeById(id),
                      selected: !selection.multiGame && id == selection.modeId,
                      onTap: () => onSelect(_Selection(modeId: id)),
                    ),
                  _MultiGameChip(
                    selected: selection.multiGame,
                    onTap: () => onSelect(const _Selection(multiGame: true)),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: (launching || !allConnected) ? null : () => onLaunch(),
                icon: launching
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        allConnected
                            ? Icons.play_arrow_rounded
                            : Icons.hourglass_empty_rounded,
                      ),
                label: Text(
                  launching
                      ? 'Préparation…'
                      : !allConnected
                          ? 'En attente d\'un 2ème joueur…'
                          : 'Lancer la partie',
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

class _LobbyAvatar extends StatelessWidget {
  const _LobbyAvatar({
    required this.player,
    required this.isHost,
    required this.isConnected,
    this.onKick,
  });
  final MultiplayerPlayer player;
  final bool isHost;
  final bool isConnected;
  final VoidCallback? onKick;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    final Color color = AppColors.playerPalette[player.colorIndex % AppColors.playerPalette.length];
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedOpacity(
              duration: AppMotion.base,
              opacity: isConnected ? 1.0 : 0.3,
              child: AvatarView(
                emoji: player.emoji,
                photoBase64: player.photoBase64,
                color: color,
                size: 46,
                showRing: isConnected,
              ),
            ),
            if (onKick != null)
              Positioned(
                top: -6,
                right: -6,
                child: GestureDetector(
                  onTap: onKick,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          isHost ? 'Hôte' : player.name,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: isConnected ? colors.textPrimary : colors.textMuted, // <-- Modifié
              ),
        ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.mode,
    required this.selected,
    required this.onTap,
  });
  final GameMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.base,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? mode.color.withValues(alpha: 0.18) : colors.fill, // <-- Modifié
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: selected
                ? mode.color.withValues(alpha: 0.6)
                : colors.borderSoft, // <-- Modifié
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              mode.icon,
              size: 16,
              color: selected ? mode.color : colors.textMuted, // <-- Modifié
            ),
            const SizedBox(width: 8),
            Text(
              mode.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 14,
                    color: selected ? mode.color : colors.textSecondary, // <-- Modifié
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MultiGameChip extends StatelessWidget {
  const _MultiGameChip({required this.selected, required this.onTap});
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    const Color color = AppColors.accent;
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.base,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.18) : colors.fill, // <-- Modifié
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.6) : colors.borderSoft, // <-- Modifié
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.shuffle_rounded,
              size: 16,
              color: selected ? color : colors.textMuted, // <-- Modifié
            ),
            const SizedBox(width: 8),
            Text(
              'Multi-jeu',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 14,
                    color: selected ? color : colors.textSecondary, // <-- Modifié
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.warning_amber_rounded,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => unawaited(onRetry()),
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}