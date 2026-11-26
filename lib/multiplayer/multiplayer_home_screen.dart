import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/player.dart';
import '../services/auth_service.dart';
import '../services/haptics.dart';
import '../theme/app_theme.dart';
import '../widgets/ambient_background.dart';
import '../widgets/app_transitions.dart';
import '../widgets/avatar_view.dart';
import '../widgets/common.dart';
import 'create_character_screen.dart';
import 'host_screen.dart';
import 'join_screen.dart';
import 'online_lobby_screen.dart';

class MultiplayerHomeScreen extends StatelessWidget {
  const MultiplayerHomeScreen({super.key});

  static const Color _accent = Color(0xFF38BDF8);
  static const Color _accentAlt = Color(0xFF8B7BFF);
  static const Color _onlineColor = Color(0xFF4ADE80);

  Future<void> _onlineMode(BuildContext context) async {
    Haptics.medium();
    
    if (AuthService.instance.isAnonymous) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const _RequireAccountSheet(),
      );
      return;
    }

    if (!context.mounted) return;

    // 1. Afficher un indicateur de chargement
    unawaited(
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          final colors = ctx.culColors;
          return Dialog(
            backgroundColor: colors.surfaceTop,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: _onlineColor),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Chargement du profil…', style: ctx.text.bodyMedium),
                ],
              ),
            ),
          );
        },
      ),
    );

    // 2. Récupération du profil Firestore
    final String uid = AuthService.instance.uid!;
    Player? existingPlayer;
    
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        existingPlayer = Player(
          id: uid,
          name: data['name'] ?? 'Joueur',
          emoji: data['emoji'] ?? '🎉',
          colorIndex: data['colorIndex'] ?? 0,
          photoBase64: data['photoBase64'],
        );
      }
    } catch (e) {
      debugPrint('Erreur chargement profil: $e');
    }

    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop(); // Fermer le loader
    }

    if (!context.mounted) return;

    // 3. Si le joueur existe, on lui demande s'il veut le garder
    Player? finalPlayer = existingPlayer;

    if (existingPlayer != null) {
      final bool? keepProfile = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final colors = ctx.culColors;
          return AlertDialog(
            backgroundColor: colors.surfaceTop,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
            contentPadding: const EdgeInsets.all(AppSpacing.lg),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Bon retour !',
                  style: ctx.text.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                AvatarView.fromPlayer(existingPlayer!, size: 80),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  existingPlayer.name,
                  style: ctx.text.titleLarge?.copyWith(color: existingPlayer.color),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'C’est bien toi ?',
                  style: ctx.text.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actionsAlignment: MainAxisAlignment.spaceEvenly,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false), // Va modifier
                child: const Text('Changer de profil'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true), // Garde le profil
                style: FilledButton.styleFrom(backgroundColor: _onlineColor),
                child: const Text('C\'est moi !'),
              ),
            ],
          );
        },
      );

      if (keepProfile == null) return; // L'utilisateur a annulé (clic en dehors)

      if (keepProfile == false) {
        // L'utilisateur veut modifier son profil -> on efface le profil existant
        // pour forcer la création, mais on passe quand même existingPlayer pour pré-remplir
        finalPlayer = null; 
      }
    }

    // 4. Menu de choix Héberger / Rejoindre
    if (!context.mounted) return;
    final bool? isHosting = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final colors = ctx.culColors;
        return Container(
          decoration: BoxDecoration(
            color: colors.surfaceTop,
            borderRadius: AppRadii.sheet,
            border: Border(top: BorderSide(color: colors.border)),
          ),
          padding: AppSpacing.screen.copyWith(
            top: AppSpacing.md,
            bottom: AppSpacing.xl + MediaQuery.paddingOf(ctx).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Partie en ligne',
                textAlign: TextAlign.center,
                style: ctx.text.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Héberger une partie',
                icon: Icons.wifi_tethering_rounded,
                color: _onlineColor,
                onPressed: () => Navigator.pop(ctx, true),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Rejoindre une partie',
                icon: Icons.login_rounded,
                primary: false,
                color: _onlineColor,
                onPressed: () => Navigator.pop(ctx, false),
              ),
            ],
          ),
        );
      },
    );

    if (isHosting == null || !context.mounted) return;

    // 5. Création ou récupération du personnage
    Player? player = finalPlayer;
    
    // Si pas de joueur, ou si le joueur a décidé de changer de profil
    if (player == null) {
      player = await Navigator.of(context).push<Player>(
        MaterialPageRoute(
          builder: (_) => CreateCharacterScreen(
            title: isHosting ? 'Ton personnage (Hôte)' : 'Ton personnage',
            buttonLabel: isHosting ? 'Héberger' : 'Chercher la partie',
            initialPlayer: existingPlayer, // On pré-remplit avec l'ancien profil s'il existe
          ),
        ),
      );
      
      if (player == null || !context.mounted) return;

      // On sauvegarde (ou met à jour) le profil dans Firestore
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'name': player.name,
          'emoji': player.emoji,
          'colorIndex': player.colorIndex,
          'photoBase64': player.photoBase64,
        });
      } catch (e) {
        debugPrint('Erreur sauvegarde profil: $e');
      }
    }

    if (!context.mounted) return;

    // 6. Navigation finale
    if (isHosting) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OnlineHostScreen(hostPlayer: player!)),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OnlineJoinScreen(player: player!)),
      );
    }
  }

  Future<void> _host(BuildContext context) async {
    final Player? player = await Navigator.of(context).push<Player>(
      MaterialPageRoute(
        builder: (_) => const CreateCharacterScreen(
          title: 'Ton personnage',
          buttonLabel: 'Héberger la partie',
        ),
      ),
    );
    
    if (player == null || !context.mounted) return;
    Navigator.of(context).push(
      ForwardRoute<void>(builder: (_) => HostScreen(hostPlayer: player)),
    );
  }

  Future<void> _join(BuildContext context) async {
    final Player? player = await Navigator.of(context).push<Player>(
      MaterialPageRoute(
        builder: (_) => const CreateCharacterScreen(
          title: 'Ton personnage',
          buttonLabel: 'Chercher une partie',
        ),
      ),
    );
    
    if (player == null || !context.mounted) return;
    Navigator.of(context).push(
      ForwardRoute<void>(builder: (_) => JoinScreen(player: player)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AmbientBackground(
        primary: _accent,
        secondary: _accentAlt,
        child: SafeArea(
          child: Column(
            children: <Widget>[
              AppHeader(
                title: 'Multijoueur',
                subtitle: 'Chacun son téléphone',
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: ListView(
                  padding: AppSpacing.screen.copyWith(
                    top: AppSpacing.lg,
                    bottom: AppSpacing.xl,
                  ),
                  children: <Widget>[
                    const SectionTitle('EN LIGNE'),
                    _ActionCard(
                      icon: Icons.language_rounded,
                      title: 'Partie en ligne',
                      subtitle: 'Jouer avec des amis à distance',
                      color: _onlineColor,
                      onTap: () => _onlineMode(context),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    
                    const SectionTitle('RÉSEAU LOCAL'),
                    Text(
                      'Un appareil héberge la partie et affiche un QR code. '
                      'Les autres le scannent pour le rejoindre. Tout se '
                      'passe sur le réseau local — Wi-Fi ou partage de '
                      'connexion — sans aucune connexion Internet.',
                      style: context.text.bodyLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _ActionCard(
                      icon: Icons.wifi_tethering_rounded,
                      title: 'Héberger (Local)',
                      subtitle: 'Crée la partie et affiche le code d’appairage.',
                      color: _accent,
                      onTap: () => _host(context),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _ActionCard(
                      icon: Icons.qr_code_scanner_rounded,
                      title: 'Rejoindre (Local)',
                      subtitle: 'Scanne le QR code ou cherche les parties à proximité.',
                      color: _accentAlt,
                      onTap: () => _join(context),
                    ),
                    
                    const SizedBox(height: AppSpacing.xl),
                    const _Hint(
                      text: 'Tous les appareils doivent être sur le même réseau '
                          'Wi-Fi. En l’absence de box, active le partage de '
                          'connexion sur un des téléphones.',
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

class _RequireAccountSheet extends StatefulWidget {
  const _RequireAccountSheet();

  @override
  State<_RequireAccountSheet> createState() => _RequireAccountSheetState();
}

class _RequireAccountSheetState extends State<_RequireAccountSheet> {
  bool _loading = false;

  Future<void> _login() async {
    setState(() => _loading = true);
    Haptics.medium();
    final result = await AuthService.instance.linkWithGoogle();
    if (mounted) {
      setState(() => _loading = false);
      if (result != null) {
        await Haptics.success();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Compte connecté ! Tu peux rejouer en ligne.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceTop,
        borderRadius: AppRadii.sheet,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      padding: AppSpacing.screen.copyWith(
        top: AppSpacing.md,
        bottom: AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const Icon(Icons.lock_person_rounded, size: 64, color: AppColors.warning),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Compte requis',
            textAlign: TextAlign.center,
            style: context.text.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Pour jouer en ligne avec tes amis à distance, tu dois créer un compte. '
            'Cela permet de sauvegarder tes statistiques et de te reconnecter facilement.',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
          GoogleSignInButton(
            loading: _loading,
            onPressed: _login,
          ),
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Plus tard'),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      accent: color,
      padding: const EdgeInsets.all(AppSpacing.md + 4),
      child: Row(
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: context.text.headlineMedium?.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: context.text.bodyMedium),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 22,
            color: context.culColors.textMuted,
          ),
        ],
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
            Icons.lightbulb_outline_rounded,
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