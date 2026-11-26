import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
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
import '../services/auth_service.dart';
import '../services/game_session.dart';
import '../services/haptics.dart';
import '../theme/app_theme.dart';
import '../widgets/ambient_background.dart';
import '../widgets/avatar_view.dart';
import '../widgets/branded_qr.dart';
import '../widgets/common.dart';
import '../widgets/qr_scanner_view.dart';
import 'client_game_controller.dart';
import 'firestore_transport.dart';
import 'host_game_controller.dart';
import 'multiplayer_session.dart';
import 'room_code.dart';

// ---------------------------------------------------------------------------
// Couleurs du mode en ligne.
// ---------------------------------------------------------------------------

const Color _onlineAccent = Color(0xFF4ADE80); // Vert success
const Color _onlineAccentAlt = Color(0xFF38BDF8); // Bleu

class _Selection {
  const _Selection({this.modeId, this.multiGame = false});
  final GameModeId? modeId;
  final bool multiGame;
}

// ---------------------------------------------------------------------------
// Hébergement en ligne
// ---------------------------------------------------------------------------

class OnlineHostScreen extends StatefulWidget {
  const OnlineHostScreen({super.key, required this.hostPlayer});

  final Player hostPlayer;

  @override
  State<OnlineHostScreen> createState() => _OnlineHostScreenState();
}

class _OnlineHostScreenState extends State<OnlineHostScreen> {
  String? _roomCode;
  FirestoreTransport? _transport;
  HostGameController? _controller;
  String? _error;
  bool _starting = true;
  bool _launching = false;

  _Selection _selection = const _Selection(modeId: GameModeId.tuPreferes);

  @override
  void initState() {
    super.initState();
    unawaited(_startHosting());
  }

  Future<void> _startHosting() async {
    final String? uid = AuthService.instance.uid;
    if (uid == null) {
      if (mounted) {
        setState(() {
          _starting = false;
          _error = 'Aucun identifiant Firebase.\nVérifiez votre connexion.';
        });
      }
      return;
    }

    try {
      final String code = RoomCode.generate();
      final FirestoreTransport transport = FirestoreTransport(
        selfId: uid,
        isHost: true,
        roomCode: code,
      );
      transport.listenAsHost();

      final HostGameController controller = HostGameController(
        transport: transport,
        hostPlayer: widget.hostPlayer,
      );

      if (!mounted) {
        unawaited(transport.close());
        controller.dispose();
        return;
      }

      setState(() {
        _roomCode = code;
        _transport = transport;
        _controller = controller;
        _starting = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _starting = false;
          _error = 'Impossible de créer la partie :\n$e';
        });
      }
    }
  }

  @override
  void dispose() {
    final FirestoreTransport? transport = _transport;
    if (transport != null) unawaited(transport.close());
    _controller?.dispose();
    super.dispose();
  }

  void _kick(String playerId) {
    if (_controller == null) return;
    unawaited(Haptics.heavy());
    _controller!.removePlayer(playerId);
  }

  Future<void> _launch() async {
    if (_launching || _transport == null || _controller == null) return;
    if (_controller!.players.length < 2) return;

    final AppState state = context.read<AppState>();
    setState(() => _launching = true);

    try {
      final Map<String, GameSession> sessions = <String, GameSession>{};
      final List<Player> players = _controller!.players;

      if (_selection.multiGame) {
        for (final GameMode m in kGameModes) {
          sessions[m.slug] = await buildGameSession(
            state,
            m,
            players: players,
          );
        }
        _controller!.startGame(
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
        _controller!.startGame(
          sessions: sessions,
          modeId: mode.slug,
          multiGame: false,
        );
      }

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _screenFor(_controller!),
        ),
      );
    } finally {
      if (mounted) setState(() => _launching = false);
    }
  }

  Widget _screenFor(HostGameController controller) {
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

  Future<void> _confirmLeave() async {
    Haptics.light();
    final bool? leave = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text('Quitter la partie ?', style: ctx.text.titleLarge),
        content: Text(
          'Les joueurs connectés seront déconnectés.',
          style: ctx.text.bodyMedium,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Rester'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) unawaited(_confirmLeave());
      },
      child: Scaffold(
        body: AmbientBackground(
          primary: _onlineAccent,
          secondary: _onlineAccentAlt,
          child: SafeArea(
            child: _starting
                ? _buildLoading()
                : _error != null
                    ? _ErrorView(
                        message: _error!,
                        onRetry: () {
                          setState(() {
                            _starting = true;
                            _error = null;
                          });
                          unawaited(_startHosting());
                        },
                      )
                    : _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(color: _onlineAccent),
          const SizedBox(height: AppSpacing.lg),
          Text('Création de la partie…', style: context.text.bodyLarge),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final HostGameController controller = _controller!;

    return Column(
      children: <Widget>[
        AppHeader(
          title: 'Héberger',
          subtitle: 'En ligne · code ${_roomCode!}',
          onBack: () => unawaited(_confirmLeave()),
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: controller,
            builder: (BuildContext context, Widget? _) {
              final List<MultiplayerPlayer> players =
                  controller.snapshot.players;
              final bool allConnected = players.length >= 2;

              return SingleChildScrollView(
                padding: AppSpacing.screen.copyWith(
                  top: AppSpacing.sm,
                  bottom: AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _CodeCard(code: _roomCode!, color: _onlineAccent),
                    const SizedBox(height: AppSpacing.lg),
                    Center(
                      child: BrandedQr(
                        data: 'culsec://join?code=$_roomCode',
                        size: 200,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Center(
                      child: Text(
                        'Scannez pour rejoindre',
                        style: context.text.bodySmall,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xl),
                    SectionTitle(
                      'À TABLE',
                      trailing: '${players.length} / ${players.length}',
                    ),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.md,
                      children: <Widget>[
                        for (int i = 0; i < players.length; i++)
                          _LobbyAvatar(
                            player: players[i],
                            isHost: i == 0,
                            onKick: i == 0
                                ? null
                                : () => _kick(players[i].id),
                          ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.xl),
                    const SectionTitle('MODE DE JEU'),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: <Widget>[
                        for (final GameModeId id in <GameModeId>[
                          GameModeId.tuPreferes,
                          GameModeId.quiPourrait,
                          GameModeId.jeNaiJamais,
                          GameModeId.actionOuVerite,
                        ])
                          _ModeChip(
                            mode: gameModeById(id),
                            selected: !_selection.multiGame &&
                                id == _selection.modeId,
                            onTap: () {
                              Haptics.tick();
                              setState(
                                () => _selection = _Selection(modeId: id),
                              );
                            },
                          ),
                        _MultiGameChip(
                          selected: _selection.multiGame,
                          onTap: () {
                            Haptics.tick();
                            setState(
                              () => _selection =
                                  const _Selection(multiGame: true),
                            );
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.xl),
                    if (!allConnected)
                      const _Hint(
                        text:
                            'En attente d’un 2ème joueur pour lancer la partie…',
                      ),
                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      label: _launching
                          ? 'Préparation…'
                          : !allConnected
                              ? 'En attente de joueurs'
                              : 'Lancer la partie',
                      icon: _launching
                          ? null
                          : allConnected
                              ? Icons.play_arrow_rounded
                              : Icons.hourglass_empty_rounded,
                      color: _onlineAccent,
                      onPressed: (allConnected && !_launching)
                          ? () => unawaited(_launch())
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Center(
                      child: Text(
                        'Les joueurs doivent saisir le code\n'
                        'ou scanner le QR code.',
                        textAlign: TextAlign.center,
                        style: context.text.bodySmall,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Rejoindre en ligne (COMPLET)
// ---------------------------------------------------------------------------

class OnlineJoinScreen extends StatefulWidget {
  const OnlineJoinScreen({super.key, required this.player});
  final Player player;

  @override
  State<OnlineJoinScreen> createState() => _OnlineJoinScreenState();
}

class _OnlineJoinScreenState extends State<OnlineJoinScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _connecting = false;
  
  FirestoreTransport? _transport;
  ClientGameController? _controller;
  bool _navigatedToGame = false;
  bool _hostLeft = false;

  @override
  void initState() {
    super.initState();
    // Vérifier si on a une session en cours
    final AppState state = context.read<AppState>();
    final String? roomCode = state.onlineRoomCode;
    final String? playerId = state.onlinePlayerId;
    
    if (roomCode != null && playerId != null) {
      // On tente de restaurer la session
      _codeController.text = roomCode;
      unawaited(_connect(reconnectPlayerId: playerId));
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _controller?.dispose();
    unawaited(_transport?.close());
    super.dispose();
  }

  Future<void> _openScanner() async {
    Haptics.light();
    final String? scannedCode = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => QrScannerView(
          title: 'Scanner la partie',
          color: _onlineAccent,
          onDetect: (BarcodeCapture capture) {
            final String? raw = capture.barcodes.first.rawValue;
            if (raw != null) {
              unawaited(Haptics.success());
              Navigator.of(context).pop(raw);
            }
          },
        ),
      ),
    );

    if (scannedCode == null || !mounted) return;

    final Uri? uri = Uri.tryParse(scannedCode);
    if (uri != null && uri.scheme == 'culsec') {
      final String code = uri.queryParameters['code'] ?? '';
      _codeController.text = code;
    } else {
      _codeController.text = scannedCode;
    }

    unawaited(_connect());
  }

  Future<void> _connect({String? reconnectPlayerId}) async {
    final String code = RoomCode.normalize(_codeController.text);
    if (!RoomCode.isValid(code)) {
      await Haptics.failure();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code invalide (6 caractères requis).')),
      );
      return;
    }

    Haptics.medium();
    setState(() => _connecting = true);

    try {
      final FirestoreTransport transport = FirestoreTransport(
        selfId: AuthService.instance.uid ?? 'client',
        isHost: false,
        roomCode: code,
      );

      await transport.join();
      transport.listenAsClient();

      final ClientGameController controller = ClientGameController(transport: transport);
      controller.addListener(_onControllerChanged);
      
      // Si on reconnecte, on passe l'ID du joueur
      controller.start(player: widget.player, reconnectPlayerId: reconnectPlayerId);

      if (!mounted) {
        controller.dispose();
        unawaited(transport.close());
        return;
      }

      setState(() {
        _transport = transport;
        _controller = controller;
        _hostLeft = false;
      });

      // Sauvegarder la session en cours
      if (controller.assignedPlayerId != null) {
        unawaited(context.read<AppState>().saveOnlineSession(code, controller.assignedPlayerId!));
      }

    } catch (e) {
      await Haptics.failure();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec de connexion : $e')),
      );
      unawaited(context.read<AppState>().clearOnlineSession());
      setState(() => _connecting = false);
    }
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final ClientGameController? controller = _controller;
    if (controller == null) return;

    if (controller.disconnected.value && !_hostLeft) {
      setState(() => _hostLeft = true);
      unawaited(context.read<AppState>().clearOnlineSession());
      return;
    }

    final MultiplayerSnapshot? snapshot = controller.snapshot;
    final bool isInLobby = snapshot == null || snapshot.modeId == 'lobby';

    if (!_navigatedToGame && !isInLobby) {
      _navigatedToGame = true;
      Navigator.of(context)
          .push(
        MaterialPageRoute<void>(
          builder: (_) => MultiJeuMultiplayerScreen(
            clientController: controller,
            onQuit: () => Navigator.of(context).pop(),
          ),
        ),
      )
          .then((_) {
        if (!mounted) return;
        setState(() {
          _navigatedToGame = false;
        });
        
        final snap = controller.snapshot;
        if (snap == null || snap.modeId != 'lobby') {
          setState(() {
            _controller?.dispose();
            _controller = null;
            _transport?.close();
            _transport = null;
            _connecting = false;
          });
          unawaited(context.read<AppState>().clearOnlineSession());
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hostLeft) {
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
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: 'Retour à l’accueil',
                    color: AppColors.danger,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Si on est connecté mais en salle d'attente
    if (_controller != null && _controller!.assignedPlayerId != null) {
      return _ClientLobbyView(controller: _controller!);
    }

    // Sinon, on affiche l'écran de saisie
    return Scaffold(
      body: AmbientBackground(
        primary: _onlineAccentAlt,
        secondary: _onlineAccent,
        child: SafeArea(
          child: Column(
            children: [
              AppHeader(
                title: 'Rejoindre',
                subtitle: 'En ligne',
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: AppSpacing.screen.copyWith(top: AppSpacing.md),
                  child: Column(
                    children: [
                      const SizedBox(height: AppSpacing.lg),
                      
                      AvatarView.fromPlayer(widget.player, size: 80),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        widget.player.name,
                        style: context.text.headlineLarge?.copyWith(
                          color: widget.player.color,
                        ),
                      ),
                      
                      const SizedBox(height: AppSpacing.xxl),
                      
                      Text(
                        'ENTRE LE CODE À 6 LETTRES',
                        style: context.text.labelMedium?.copyWith(letterSpacing: 2),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppCard(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                        accent: _onlineAccent,
                        child: TextField(
                          controller: _codeController,
                          textAlign: TextAlign.center,
                          textCapitalization: TextCapitalization.characters,
                          maxLength: 6,
                          style: context.text.displayMedium?.copyWith(
                            letterSpacing: 12,
                            color: _onlineAccent,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'ABCDEF',
                            counterText: '',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            fillColor: Colors.transparent,
                            filled: false,
                          ),
                          onSubmitted: (_) => unawaited(_connect()),
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xl),
                      
                      AppButton(
                        label: _connecting ? 'Connexion...' : 'Rejoindre la partie',
                        icon: _connecting ? null : Icons.login_rounded,
                        color: _onlineAccent,
                        onPressed: _connecting ? null : () => unawaited(_connect()),
                      ),
                      
                      const SizedBox(height: AppSpacing.xl),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text('OU', style: context.text.bodySmall),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      
                      AppButton(
                        label: 'Scanner un QR Code',
                        icon: Icons.qr_code_scanner_rounded,
                        primary: false,
                        color: _onlineAccentAlt,
                        onPressed: _connecting ? null : _openScanner,
                      ),
                    ],
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

// ---------------------------------------------------------------------------
// Écran d'attente pour le client
// ---------------------------------------------------------------------------

class _ClientLobbyView extends StatelessWidget {
  const _ClientLobbyView({required this.controller});
  final ClientGameController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AmbientBackground(
        primary: _onlineAccent,
        secondary: _onlineAccentAlt,
        child: SafeArea(
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              final snapshot = controller.snapshot;
              if (snapshot == null) {
                return const Center(child: CircularProgressIndicator());
              }

              return Column(
                children: [
                  const SizedBox(height: AppSpacing.xxl),
                  const Icon(Icons.check_circle_rounded, size: 64, color: _onlineAccent),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Connecté !',
                    style: context.text.displaySmall?.copyWith(color: _onlineAccent),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'En attente du lancement par l’hôte…',
                    style: context.text.bodyLarge,
                  ),
                  const Spacer(),
                  
                  Text('DANS LA SALLE', style: context.text.labelMedium),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final p in snapshot.players)
                        _LobbyAvatar(
                          player: p,
                          isHost: p.id == snapshot.players.first.id,
                        ),
                    ],
                  ),

                  const Spacer(),
                  const CircularProgressIndicator(color: _onlineAccent),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets privés partagés
// ---------------------------------------------------------------------------

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code, required this.color});

  final String code;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      accent: color,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg + 4,
      ),
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.vpn_key_rounded, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                'CODE DE LA PARTIE',
                style: context.text.labelMedium?.copyWith(
                  letterSpacing: 2,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              code,
              style: context.text.displayMedium?.copyWith(
                fontSize: 56,
                fontWeight: FontWeight.w800,
                letterSpacing: 10,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Partagez ce code à vos amis',
            style: context.text.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _LobbyAvatar extends StatelessWidget {
  const _LobbyAvatar({
    required this.player,
    required this.isHost,
    this.onKick,
  });

  final MultiplayerPlayer player;
  final bool isHost;
  final VoidCallback? onKick;

  @override
  Widget build(BuildContext context) {
    final Color color = AppColors
        .playerPalette[player.colorIndex % AppColors.playerPalette.length];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            AvatarView(
              emoji: player.emoji,
              photoBase64: player.photoBase64,
              color: color,
              size: 52,
              showRing: true,
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
                    child: const Icon(
                      Icons.close_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          isHost ? 'Hôte' : player.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.titleMedium?.copyWith(
            fontSize: 12.5,
            color: color,
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
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.base,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? mode.color.withValues(alpha: 0.18) : colors.fill,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: selected
                ? mode.color.withValues(alpha: 0.7)
                : colors.borderSoft,
            width: selected ? 1.6 : 1,
          ),
          boxShadow:
              selected ? AppShadows.glow(mode.color, opacity: 0.20) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              mode.icon,
              size: 16,
              color: selected ? mode.color : colors.textMuted,
            ),
            const SizedBox(width: 8),
            Text(
              mode.title,
              style: context.text.titleMedium?.copyWith(
                fontSize: 13,
                color: selected ? mode.color : colors.textSecondary,
              ),
            ),
            if (selected) ...<Widget>[
              const SizedBox(width: 6),
              Icon(Icons.check_rounded, size: 14, color: mode.color),
            ],
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

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.base,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? _onlineAccent.withValues(alpha: 0.18)
              : colors.fill,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: selected
                ? _onlineAccent.withValues(alpha: 0.7)
                : colors.borderSoft,
            width: selected ? 1.6 : 1,
          ),
          boxShadow:
              selected ? AppShadows.glow(_onlineAccent, opacity: 0.20) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.shuffle_rounded,
              size: 16,
              color: selected ? _onlineAccent : colors.textMuted,
            ),
            const SizedBox(width: 8),
            Text(
              'Multi-jeu',
              style: context.text.titleMedium?.copyWith(
                fontSize: 13,
                color: selected ? _onlineAccent : colors.textSecondary,
              ),
            ),
            if (selected) ...<Widget>[
              const SizedBox(width: 6),
              const Icon(
                Icons.check_rounded,
                size: 14,
                color: _onlineAccent,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.fill,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.hourglass_top_rounded,
            size: 18,
            color: AppColors.warning,
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Text(text, style: context.text.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.screen,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.warning_amber_rounded,
              size: 48,
              color: AppColors.warning,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.text.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Réessayer',
              icon: Icons.refresh_rounded,
              color: _onlineAccent,
              expand: false,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}