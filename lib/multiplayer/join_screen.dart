import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:nsd/nsd.dart' as nsd;
import 'package:provider/provider.dart';

import '../models/player.dart';
import '../screens/games/multi_jeu_multiplayer_screen.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_view.dart';
import '../widgets/common.dart';
import 'client_game_controller.dart';
import 'mdns_helper.dart';
import 'room_code.dart';
import 'web_client_transport.dart';
import '../multiplayer/multiplayer_session.dart';

class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key, required this.player});

  final Player player;

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> with WidgetsBindingObserver {
  final MobileScannerController _scanner = MobileScannerController(
    autoStart: false,
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
  );

  final TextEditingController _manual = TextEditingController();
  final FocusNode _manualFocus = FocusNode();

  bool _scanning = true;
  bool _torchOn = false;
  bool _cameraReady = false;
  String? _cameraError;
  bool _starting = false;
  bool _returningFromSettings = false;

  ClientGameController? _controller;
  bool _connected = false;
  bool _navigatedToGame = false;
  bool _hostLeft = false;

  nsd.Discovery? _discovery;
  bool _discovering = false;
  List<nsd.Service> _foundServices = <nsd.Service>[];

  String? _savedUri;
  Uri? _lastConnectedUri;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _savedUri = context.read<AppState>().lastGameUri;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_startCamera());
        unawaited(_startDiscovery());
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanner.dispose();
    _manual.dispose();
    _manualFocus.dispose();
    _controller?.dispose();
    final nsd.Discovery? d = _discovery;
    if (d != null) unawaited(MdnsHelper.stopDiscovery(d));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_scanning || _connected) return;
        if (_returningFromSettings) {
          _returningFromSettings = false;
          _cameraReady = false;
          unawaited(_startCamera());
        } else if (!_cameraReady) {
          unawaited(_startCamera());
        } else {
          unawaited(_resumeCamera());
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _startDiscovery() async {
    if (_discovering) return;
    try {
      final nsd.Discovery discovery = await MdnsHelper.discover();
      discovery.addListener(_onDiscoveryUpdate);
      if (!mounted) return;
      setState(() {
        _discovery = discovery;
        _discovering = true;
        _foundServices = List<nsd.Service>.from(discovery.services);
      });
    } catch (_) {}
  }

  void _onDiscoveryUpdate() {
    if (!mounted) return;
    setState(() {
      _foundServices = List<nsd.Service>.from(
        _discovery?.services ?? const <nsd.Service>[],
      );
    });
  }

  Future<void> _stopDiscovery() async {
    final nsd.Discovery? discovery = _discovery;
    _discovery = null;
    if (discovery != null) {
      discovery.removeListener(_onDiscoveryUpdate);
      await MdnsHelper.stopDiscovery(discovery);
    }
    if (mounted) {
      setState(() {
        _discovering = false;
        _foundServices = <nsd.Service>[];
      });
    }
  }

  Future<void> _connectToService(nsd.Service service) async {
    final String? ip = MdnsHelper.ipv4Of(service);
    final String code = MdnsHelper.roomCodeOf(service);
    if (ip == null || code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ce service n’est pas encore prêt. Réessayez.'),
        ),
      );
      return;
    }
    await _stopDiscovery();
    unawaited(_scanner.stop().catchError((_) {}));
    final Uri uri = Uri(
      scheme: 'ws',
      host: ip,
      port: service.port,
      path: '/',
      queryParameters: <String, String>{'code': code},
    );
    await _connectWith(uri);
  }

  Future<void> _resumeCamera() async {
    if (_starting) return;
    _starting = true;
    try {
      if (!_scanner.value.isRunning) await _scanner.start();
    } catch (_) {
    } finally {
      _starting = false;
    }
  }

  Future<void> _startCamera() async {
    if (_starting) return;
    _starting = true;
    try {
      if (_scanner.value.isRunning) await _scanner.stop();
      await _scanner.start();
      if (!mounted) return;
      setState(() {
        _cameraReady = true;
        _cameraError = null;
      });
    } on MobileScannerException catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraReady = false;
        _cameraError = _humanReadableError(e);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cameraReady = false;
        _cameraError = 'Impossible d’ouvrir la caméra. Réessayez.';
      });
    } finally {
      _starting = false;
    }
  }

  String _humanReadableError(MobileScannerException e) {
    switch (e.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        return 'L’accès à la caméra a été refusé. Autorisez-le dans les réglages.';
      case MobileScannerErrorCode.unsupported:
        return 'Cet appareil ne supporte pas le scan de QR codes.';
      default:
        return 'Caméra indisponible. Vérifiez qu’aucune autre application ne l’utilise.';
    }
  }

  Future<void> _forceRestart() async {
    setState(() {
      _cameraReady = false;
      _cameraError = null;
    });
    try {
      await _scanner.stop();
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await _startCamera();
  }

  Future<void> _connectWith(Uri uri, {String? forcePlayerId}) async {
    try {
      final AppState state = context.read<AppState>();
      final String? lastPlayerId = forcePlayerId ?? state.lastPlayerId;

      final WebClientTransport transport = await WebClientTransport.connect(
        uri: uri,
        displayName: widget.player.name,
      );
      if (!mounted) return;

      final ClientGameController controller =
          ClientGameController(transport: transport);
      controller.start(player: widget.player, reconnectPlayerId: lastPlayerId);
      controller.addListener(_onControllerChanged);

      setState(() {
        _controller = controller;
        _connected = true;
        _scanning = false;
        _cameraReady = false;
        _hostLeft = false;
        _savedUri = null;
      });
      unawaited(_scanner.stop().catchError((_) {}));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec de connexion : $e')),
      );
      setState(() {
        _scanning = true;
      });
      unawaited(_startCamera());
      unawaited(_startDiscovery());
    }
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final ClientGameController? controller = _controller;
    if (controller == null) return;

    final AppState state = context.read<AppState>();

    if (controller.assignedPlayerId != null &&
        state.lastPlayerId != controller.assignedPlayerId) {
      unawaited(
        state.saveMultiplayerSession(
          _lastConnectedUri!.toString(),
          controller.assignedPlayerId!,
        ),
      );
    }

    if (controller.disconnected.value && !_hostLeft) {
      setState(() => _hostLeft = true);
      return;
    }

    final snapshot = controller.snapshot;
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
          _connected = false;
          _scanning = true;
          _controller?.dispose();
          _controller = null;
        });
        unawaited(_startCamera());
        unawaited(_startDiscovery());
      });
    }
  }

  void _onQrDetected(BarcodeCapture capture) {
    if (!_scanning || _connected) return;
    final List<Barcode> codes = capture.barcodes;
    if (codes.isEmpty) return;
    final String? raw = codes.first.rawValue;
    if (raw == null) return;

    final Uri? parsed = Uri.tryParse(raw);
    if (parsed == null || parsed.scheme != 'culsec') return;

    final String ip = parsed.queryParameters['ip'] ?? '';
    final int? port = int.tryParse(parsed.queryParameters['port'] ?? '');
    final String code = parsed.queryParameters['code'] ?? '';
    if (ip.isEmpty || port == null || code.isEmpty) return;

    _scanning = false;
    unawaited(_scanner.stop().catchError((_) {}));
    unawaited(_stopDiscovery());

    final Uri uri = Uri(
      scheme: 'ws',
      host: ip,
      port: port,
      path: '/',
      queryParameters: <String, String>{'code': code},
    );
    _lastConnectedUri = uri;
    unawaited(_connectWith(uri));
  }

  Future<void> _connectManual() async {
    final String raw = _manual.text.trim();
    if (raw.isEmpty) return;

    final Uri? parsed = Uri.tryParse(raw);
    if (parsed != null && parsed.scheme == 'culsec') {
      final String ip = parsed.queryParameters['ip'] ?? '';
      final int? port = int.tryParse(parsed.queryParameters['port'] ?? '');
      final String code = parsed.queryParameters['code'] ?? '';
      if (ip.isEmpty || port == null || code.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lien d’invitation incomplet.')),
        );
        return;
      }
      await _stopDiscovery();
      final Uri uri = Uri(
        scheme: 'ws',
        host: ip,
        port: port,
        path: '/',
        queryParameters: <String, String>{'code': code},
      );
      _lastConnectedUri = uri;
      await _connectWith(uri);
      return;
    }

    final String code = RoomCode.normalize(raw);
    if (!RoomCode.isValid(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code invalide (6 caractères requis).')),
      );
      return;
    }
    await _promptManualIp(code);
  }

  Future<void> _promptManualIp(String code) async {
    final TextEditingController ipController = TextEditingController();
    final TextEditingController portController =
        TextEditingController(text: '40404');
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Adresse de l’hôte'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: ipController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Adresse IP',
                hintText: '192.168.1.42',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: portController,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: const InputDecoration(labelText: 'Port'),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Connecter'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final int? port = int.tryParse(portController.text);
    if (port == null) return;
    await _stopDiscovery();
    final Uri uri = Uri(
      scheme: 'ws',
      host: ipController.text.trim(),
      port: port,
      path: '/',
      queryParameters: <String, String>{'code': code},
    );
    _lastConnectedUri = uri;
    await _connectWith(uri);
  }

  Future<void> _toggleTorch() async {
    try {
      await _scanner.toggleTorch();
      if (mounted) setState(() => _torchOn = !_torchOn);
    } catch (_) {}
  }

  Future<void> _pasteFromClipboard() async {
    final ClipboardData? data = await Clipboard.getData('text/plain');
    if (data?.text == null) return;
    _manual.text = data!.text!;
    _manualFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    if (_hostLeft) {
      final AppState state = context.read<AppState>();
      final bool canReconnect = state.lastGameUri != null;

      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.link_off_rounded,
                  size: 48,
                  color: Colors.orange,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Déconnecté de l’hôte.',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                if (canReconnect)
                  FilledButton.icon(
                    onPressed: () {
                      final Uri? uri = Uri.tryParse(state.lastGameUri!);
                      if (uri != null) {
                        setState(() {
                          _hostLeft = false;
                          _connected = false;
                          _scanning = false;
                        });
                        _lastConnectedUri = uri;
                        unawaited(
                          _connectWith(
                            uri,
                            forcePlayerId: state.lastPlayerId,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Se reconnecter'),
                  ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () {
                    unawaited(state.clearMultiplayerSession());
                    setState(() {
                      _hostLeft = false;
                      _connected = false;
                      _scanning = true;
                      _controller?.dispose();
                      _controller = null;
                      _savedUri = null;
                    });
                    unawaited(_startCamera());
                    unawaited(_startDiscovery());
                  },
                  child: const Text('Retour à l’accueil'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rejoindre · multijoueur local'),
        actions: <Widget>[
          if (!_connected && _cameraReady)
            IconButton(
              icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
              onPressed: () => unawaited(_toggleTorch()),
              tooltip: 'Torche',
            ),
          if (!_connected)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() => _scanning = true);
                unawaited(_forceRestart());
              },
              tooltip: 'Relancer la caméra',
            ),
        ],
      ),
      body: _connected
          ? _LobbyClientView(controller: _controller!)
          : _buildJoiner(),
    );
  }

  Widget _buildJoiner() {
    final colors = context.culColors;
    final AppState state = context.read<AppState>();
    final String? savedUriStr = _savedUri ?? state.lastGameUri;
    final String? savedPlayerId = state.lastPlayerId;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: <Widget>[
          if (savedUriStr != null && savedPlayerId != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              child: AppCard(
                accent: AppColors.warning,
                padding: const EdgeInsets.all(16),
                onTap: () {
                  final Uri? uri = Uri.tryParse(savedUriStr);
                  if (uri != null) {
                    _lastConnectedUri = uri;
                    _savedUri = null;
                    unawaited(
                      _connectWith(uri, forcePlayerId: savedPlayerId),
                    );
                  }
                },
                child: Row( // <-- Retrait du const
                  children: <Widget>[
                    const Icon(
                      Icons.history_rounded,
                      color: AppColors.warning,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Reprendre la partie',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: colors.textPrimary, // <-- Modifié
                            ),
                          ),
                          Text(
                            'Dernière session en cours',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textMuted, // <-- Modifié
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: AppColors.warning,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _DiscoverySection(
              discovering: _discovering,
              services: _foundServices,
              onRefresh: () => unawaited(_startDiscovery()),
              onConnect: (nsd.Service s) => unawaited(_connectToService(s)),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: <Widget>[
                Expanded(child: Divider(color: colors.borderSoft)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'ou scanner le QR',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontSize: 12),
                  ),
                ),
                Expanded(child: Divider(color: colors.borderSoft)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          
          SizedBox(
            height: 240,
            child: _cameraError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(Icons.no_photography_outlined, size: 40),
                          const SizedBox(height: 12),
                          Text(
                            _cameraError!,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => unawaited(_forceRestart()),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Réessayer'),
                          ),
                        ],
                      ),
                    ),
                  )
                : !_cameraReady
                    ? const Center(child: CircularProgressIndicator())
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: ClipRRect(
                          borderRadius: AppRadii.bigCard,
                          child: Stack(
                            children: [
                              MobileScanner(
                                controller: _scanner,
                                onDetect: _onQrDetected,
                              ),
                              Center(
                                child: Container(
                                  width: 160,
                                  height: 160,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: AppColors.accent,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.accent.withValues(alpha: 0.3),
                                        blurRadius: 12,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 16,
                                left: 0,
                                right: 0,
                                child: Text(
                                  'Placez le QR Code dans le cadre',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.white,
                                    shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
          ),

          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: <Widget>[
                TextField(
                  controller: _manual,
                  focusNode: _manualFocus,
                  autocorrect: false,
                  enableSuggestions: false,
                  maxLines: 2,
                  minLines: 1,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'K7M3PQ  ou  culsec://join?...',
                    hintStyle: const TextStyle(fontSize: 13),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.paste_rounded),
                      tooltip: 'Coller',
                      onPressed: () => unawaited(_pasteFromClipboard()),
                    ),
                  ),
                  onSubmitted: (_) => unawaited(_connectManual()),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => unawaited(_connectManual()),
                    child: const Text('Se connecter'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _DiscoverySection extends StatelessWidget {
  const _DiscoverySection({
    required this.discovering,
    required this.services,
    required this.onRefresh,
    required this.onConnect,
  });

  final bool discovering;
  final List<nsd.Service> services;
  final VoidCallback onRefresh;
  final ValueChanged<nsd.Service> onConnect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'PARTIES À PROXIMITÉ',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            TextButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Actualiser'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (services.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: <Widget>[
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Recherche des parties sur le réseau…',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontSize: 12),
                  ),
                ),
              ],
            ),
          )
        else
          for (final nsd.Service s in services)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _DiscoveredTile(service: s, onTap: () => onConnect(s)),
            ),
      ],
    );
  }
}

class _DiscoveredTile extends StatelessWidget {
  const _DiscoveredTile({required this.service, required this.onTap});
  final nsd.Service service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    final String room = MdnsHelper.roomCodeOf(service);
    final String? ip = MdnsHelper.ipv4Of(service);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadii.button,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: colors.surfaceHigh,
            borderRadius: AppRadii.button,
            border: Border.all(color: colors.borderSoft),
          ),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.wifi_tethering_rounded,
                size: 20,
                color: AppColors.accent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      room.isEmpty ? 'Partie Cul Sec' : 'Partie $room',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontSize: 14),
                    ),
                    Text(
                      ip != null
                          ? '$ip:${service.port}'
                          : 'Adresse en cours de résolution…',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: colors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LobbyClientView extends StatelessWidget {
  const _LobbyClientView({required this.controller});
  final ClientGameController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? _) {
        final MultiplayerSnapshot? snapshot = controller.snapshot;
        
        if (snapshot == null) {
          return Center(
            child: Padding(
              padding: AppSpacing.screen,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const CircularProgressIndicator(color: AppColors.accent),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Connexion à la salle d’attente…',
                    textAlign: TextAlign.center,
                    style: context.text.bodyMedium,
                  ),
                ],
              ),
            ),
          );
        }

        final String name = controller.assignedName ?? 'Joueur';
        final String emoji = controller.assignedEmoji ?? '🎉';
        final Color myColor = AppColors.playerPalette[
            controller.assignedColorIndex % AppColors.playerPalette.length];

        return SafeArea(
          child: Padding(
            padding: AppSpacing.screen.copyWith(top: AppSpacing.lg),
            child: Column(
              children: <Widget>[
                Text(
                  'Tu joues en tant que',
                  style: context.text.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    AvatarView(
                      emoji: emoji,
                      photoBase64: controller.assignedPhotoBase64,
                      color: myColor,
                      size: 40,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      name,
                      style: context.text.headlineMedium?.copyWith(
                        color: myColor,
                        fontSize: 24,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: AppSpacing.xl),
                const Divider(),
                const SizedBox(height: AppSpacing.lg),

                Text(
                  'SALLE D’ATTENTE',
                  style: context.text.labelMedium?.copyWith(letterSpacing: 2),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'En attente du lancement par l’hôte…',
                  style: context.text.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xl),

                Expanded(
                  child: SingleChildScrollView(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.md,
                      children: <Widget>[
                        for (final p in snapshot.players)
                          _LobbyAvatar(
                            player: p,
                            isHost: p.id == snapshot.players.first.id,
                            isMe: p.id == controller.assignedPlayerId,
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),
                const CircularProgressIndicator(color: AppColors.accent),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
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
    required this.isMe,
  });
  
  final MultiplayerPlayer player;
  final bool isHost;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final Color color = AppColors.playerPalette[player.colorIndex % AppColors.playerPalette.length];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            AvatarView(
              emoji: player.emoji,
              photoBase64: player.photoBase64,
              color: color,
              size: 56,
              showRing: true,
            ),
            if (isMe)
              Positioned(
                bottom: -4,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Text(
                      'TOI',
                      style: context.text.labelMedium?.copyWith(
                        fontSize: 8,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          player.name,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 14,
                color: color,
              ),
        ),
        if (isHost)
          Text(
            'Hôte',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: AppColors.warning,
                ),
          ),
      ],
    );
  }
}