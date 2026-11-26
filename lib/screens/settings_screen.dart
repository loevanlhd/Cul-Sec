import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../data/avatar_catalog.dart';
import '../models/game_rules.dart';
import '../models/player.dart';
import '../services/app_state.dart';
import '../services/auth_service.dart';
import '../services/haptics.dart';
import '../services/sounds.dart';
import '../theme/app_theme.dart';
import '../widgets/ambient_background.dart';
import '../widgets/avatar_picker_sheet.dart';
import '../widgets/avatar_view.dart';
import '../widgets/common.dart';
import '../widgets/intensity_selector.dart';
import 'custom_cards_screen.dart';

Set<String> takenAvatars(List<Player> roster, {Player? except}) => roster
    .where(
      (Player p) =>
          p.id != except?.id && p.isSelected && !p.hasPhoto,
    )
    .map((Player p) => p.emoji)
    .toSet();

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  String? _nextAvatar;

  Set<String> _usedAvatars(AppState state) => takenAvatars(state.roster);

  String _avatarFor(AppState state) {
    final Set<String> taken = _usedAvatars(state);
    final String? next = _nextAvatar;
    if (next != null && !taken.contains(next)) return next;
    return _nextAvatar = AvatarCatalog.randomMascot(taken: taken);
  }

  void _shuffleAvatar(AppState state) {
    Haptics.tick();
    setState(() {
      _nextAvatar = AvatarCatalog.randomMascot(
        taken: _usedAvatars(state),
        current: _nextAvatar,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final String name = _controller.text.trim();
    if (name.isEmpty) return;
    final AppState state = context.read<AppState>();
    Haptics.medium();
    await state.addPlayer(name, _avatarFor(state));
    _controller.clear();
    setState(() {
      _nextAvatar = AvatarCatalog.randomMascot(taken: _usedAvatars(state));
    });
    _focus.requestFocus();
  }

  Future<void> _edit(Player player) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlayerEditSheet(player: player),
    );
  }

  void _openCustomCards() {
    Haptics.light();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CustomCardsScreen()),
    );
  }

  Future<void> _reorder(
    AppState state,
    int oldIndex,
    int newIndex,
  ) async {
    if (oldIndex == newIndex) return;
    Haptics.medium();
    await state.reorderPlayers(oldIndex, newIndex);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    final AppState state = context.watch<AppState>();
    final List<Player> roster = state.roster;
    final bool allSelected =
        roster.isNotEmpty && roster.every((Player p) => p.isSelected);
    final int customCount = state.customCardCount;

    return Scaffold(
      body: AmbientBackground(
        primary: state.intensity.color,
        child: SafeArea(
          child: Column(
            children: <Widget>[
              AppHeader(
                title: 'Réglages',
                subtitle: roster.isEmpty
                    ? 'Aucun joueur enregistré'
                    : '${state.selectedCount} sur ${roster.length} à table',
                onBack: () => Navigator.of(context).pop(),
                action: roster.isEmpty
                    ? null
                    : TextButton(
                        onPressed: () {
                          Haptics.tick();
                          state.selectAll(!allSelected);
                        },
                        child: Text(
                          allSelected ? 'Tout décocher' : 'Tout cocher',
                        ),
                      ),
              ),
              Expanded(
                child: ListView(
                  padding: AppSpacing.screen.copyWith(bottom: AppSpacing.md),
                  children: <Widget>[
                    const SectionTitle('INTENSITÉ'),
                    const IntensitySelector(),

                    const SizedBox(height: AppSpacing.xl),
                    const SectionTitle('APPARENCE'),
                    _ThemeSelector(state: state),

                    const SizedBox(height: AppSpacing.xl),
                    const SectionTitle('COMPTE'),
                    const _AccountCard(),

                    const SizedBox(height: AppSpacing.xl),
                    const SectionTitle('RÈGLES DE PARTIE'),
                    _GameRulesCard(state: state),

                    const SizedBox(height: AppSpacing.xl),
                    const SectionTitle('JOUEURS'),
                    if (roster.isEmpty)
                      const _EmptyRoster()
                    else ...<Widget>[
                      const _ReorderHint(),
                      const SizedBox(height: AppSpacing.sm),
                      _ReorderableRoster(
                        roster: roster,
                        onEdit: _edit,
                        onToggle: (Player p) {
                          Haptics.tick();
                          state.toggleSelected(p.id);
                        },
                        onReorder: (int oldIndex, int newIndex) =>
                            unawaited(
                          _reorder(state, oldIndex, newIndex),
                        ),
                      ),
                    ],

                    const SizedBox(height: AppSpacing.xl),
                    const SectionTitle('MES CARTES'),
                    AppCard(
                      onTap: _openCustomCards,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.edit_note_rounded,
                            size: 21,
                            color: colors.textSecondary,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Cartes personnalisées',
                                  style: context.text.titleMedium,
                                ),
                                Text(
                                  customCount == 0
                                      ? 'Écrivez vos propres cartes, pour '
                                          'tous les jeux'
                                      : customCount == 1
                                          ? '1 carte perso'
                                          : '$customCount cartes perso',
                                  style: context.text.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 19,
                            color: colors.textMuted,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xl),
                    const SectionTitle('SURPRISES'),
                    _ToggleTile(
                      icon: Icons.bolt_rounded,
                      title: 'Cartes Événement',
                      subtitle: 'Surprises entre deux manches, dans tous '
                          'les jeux',
                      value: state.eventsEnabled,
                      onChanged: state.setEventsEnabled,
                    ),
                    const SizedBox(height: AppSpacing.sm + 2),
                    _ToggleTile(
                      icon: Icons.casino_rounded,
                      title: 'Roulette du multi-jeu',
                      subtitle: 'Une roue tire le jeu avant chaque manche',
                      value: state.rouletteEnabled,
                      onChanged: state.setRouletteEnabled,
                    ),

                    const SizedBox(height: AppSpacing.xl),
                    const SectionTitle('APPAREIL'),
                    _HapticsTile(state: state),
                    const SizedBox(height: AppSpacing.sm + 2),
                    _ToggleTile(
                      icon: Icons.volume_up_rounded,
                      title: 'Sons',
                      subtitle:
                          'Roulette, révélations, sanctions, fin de partie',
                      value: state.soundsEnabled,
                      onChanged: (bool v) {
                        state.setSounds(v);
                        Sounds.enabled = v;
                        if (v) {
                          unawaited(
                            Future<void>.delayed(
                              const Duration(milliseconds: 400),
                              () => Sounds.play(Sfx.success),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm + 2),
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.bar_chart_rounded,
                            size: 19,
                            color: colors.textSecondary,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Statistiques',
                                  style: context.text.titleMedium,
                                ),
                                Text(
                                  '${state.gamesPlayed} parties jouées',
                                  style: context.text.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: state.gamesPlayed == 0
                                ? null
                                : () => _confirmReset(context, state),
                            child: const Text('Effacer'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm + 2),
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.history_rounded,
                            size: 19,
                            color: colors.textSecondary,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Cartes déjà vues',
                                  style: context.text.titleMedium,
                                ),
                                Text(
                                  '${state.seenCount} vues · remise à zéro '
                                  'chaque jour à 12 h',
                                  style: context.text.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: state.seenCount == 0
                                ? null
                                : () => _confirmForget(context, state),
                            child: const Text('Oublier'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Center(
                      child: Text(
                        'Cul Sec · hors-ligne · sans publicité',
                        style:
                            context.text.bodySmall?.copyWith(fontSize: 11.5),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),

              Padding(
                padding: AppSpacing.screen.copyWith(
                  top: AppSpacing.sm,
                  bottom: AppSpacing.md,
                ),
                child: Row(
                  children: <Widget>[
                    Pressable(
                      onTap: () => _shuffleAvatar(state),
                      child: AvatarView(
                        emoji: _avatarFor(state),
                        color: colors.border,
                        size: 54,
                        showRing: false,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm + 2),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focus,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _add(),
                        style: context.text.titleMedium,
                        decoration: const InputDecoration(
                          hintText: 'Ajouter un joueur',
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm + 2),
                    Pressable(
                      onTap: _add,
                      child: Container(
                        width: 54,
                        height: 54,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: AppGradients.accent,
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          boxShadow: AppShadows.glow(AppColors.accent),
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          size: 23,
                          color: Colors.white,
                        ),
                      ),
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

  Future<void> _confirmReset(BuildContext context, AppState state) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(
          'Effacer les statistiques ?',
          style: context.text.titleLarge,
        ),
        content: Text(
          'Les compteurs de parties et de gorgées repartent à zéro. '
          'Le répertoire de joueurs est conservé.',
          style: context.text.bodyMedium,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
    if (ok == true) {
      Haptics.medium();
      await state.resetStats();
    }
  }

  Future<void> _confirmForget(BuildContext context, AppState state) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(
          'Oublier les cartes vues ?',
          style: context.text.titleLarge,
        ),
        content: Text(
          'Toutes les cartes redeviennent inédites. Vos cartes perso et vos '
          'statistiques sont conservées.',
          style: context.text.bodyMedium,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Oublier'),
          ),
        ],
      ),
    );
    if (ok == true) {
      Haptics.medium();
      await state.resetSeenCards();
    }
  }
}

// ---------------------------------------------------------------------------
// Carte Compte
// ---------------------------------------------------------------------------

class _AccountCard extends StatefulWidget {
  const _AccountCard();

  @override
  State<_AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends State<_AccountCard> {
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Progression sauvegardée avec succès !')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isAnonymous = AuthService.instance.isAnonymous;
    final String email = AuthService.instance.currentUser?.email ?? '';

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                isAnonymous ? Icons.person_outline_rounded : Icons.cloud_done_rounded,
                size: 22,
                color: isAnonymous ? AppColors.warning : AppColors.success,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAnonymous ? 'Compte local (Anonyme)' : 'Compte synchronisé',
                      style: context.text.titleMedium,
                    ),
                    Text(
                      isAnonymous
                          ? 'Créez un compte pour sauvegarder votre progression.'
                          : email,
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isAnonymous) ...[
            const SizedBox(height: AppSpacing.md),
            GoogleSignInButton(
              loading: _loading,
              onPressed: _login,
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sélecteur de Thème
// ---------------------------------------------------------------------------

class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final ThemeMode current = state.themeMode;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Thème de l\'application', style: context.text.titleMedium),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              _ThemeOption(
                label: 'Système',
                icon: Icons.settings_suggest_rounded,
                selected: current == ThemeMode.system,
                onTap: () => state.setThemeMode(ThemeMode.system),
              ),
              const SizedBox(width: AppSpacing.sm),
              _ThemeOption(
                label: 'Clair',
                icon: Icons.light_mode_rounded,
                selected: current == ThemeMode.light,
                onTap: () => state.setThemeMode(ThemeMode.light),
              ),
              const SizedBox(width: AppSpacing.sm),
              _ThemeOption(
                label: 'Sombre',
                icon: Icons.dark_mode_rounded,
                selected: current == ThemeMode.dark,
                onTap: () => state.setThemeMode(ThemeMode.dark),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.base,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent.withValues(alpha: 0.15) : colors.fill,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
              color: selected ? AppColors.accent : colors.borderSoft,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? AppColors.accent : colors.textMuted,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: context.text.labelMedium?.copyWith(
                  fontSize: 11,
                  color: selected ? AppColors.accent : colors.textMuted,
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
// Liste des joueurs réordonnable
// ---------------------------------------------------------------------------

class _ReorderableRoster extends StatelessWidget {
  const _ReorderableRoster({
    required this.roster,
    required this.onEdit,
    required this.onToggle,
    required this.onReorder,
  });

  final List<Player> roster;
  final void Function(Player) onEdit;
  final void Function(Player) onToggle;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: roster.length,
      onReorderItem: onReorder,
      proxyDecorator: (
        Widget child,
        int index,
        Animation<double> animation,
      ) {
        return AnimatedBuilder(
          animation: animation,
          builder: (BuildContext context, Widget? _) {
            final double t = Curves.easeOut.transform(animation.value);
            return Transform.scale(
              scale: 1 + 0.03 * t,
              child: Material(
                color: Colors.transparent,
                elevation: 8 * t,
                shadowColor:
                    roster[index].color.withValues(alpha: 0.4 * t),
                borderRadius: AppRadii.card,
                child: child,
              ),
            );
          },
        );
      },
      itemBuilder: (BuildContext context, int i) {
        final Player p = roster[i];
        return Padding(
          key: ValueKey<String>(p.id),
          padding: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
          child: _PlayerTile(
            player: p,
            onToggle: () => onToggle(p),
            onEdit: () => onEdit(p),
            dragHandle: ReorderableDragStartListener(
              index: i,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Icon(
                  Icons.drag_indicator_rounded,
                  size: 22,
                  color: colors.textMuted,
                ),
              ),
            ),
          )
              .animate()
              .fadeIn(duration: 240.ms),
        );
      },
    );
  }
}

class _ReorderHint extends StatelessWidget {
  const _ReorderHint();

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    return Row(
      children: <Widget>[
        Icon(
          Icons.drag_indicator_rounded,
          size: 14,
          color: colors.textMuted,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Glisse la poignée à droite d’un joueur pour changer l’ordre',
            style: context.text.bodySmall?.copyWith(fontSize: 11.5),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Carte « Règles de partie »
// ---------------------------------------------------------------------------

class _GameRulesCard extends StatelessWidget {
  const _GameRulesCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    final GameRules rules = state.gameRules;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Choisissez le nombre de gorgées pour chaque situation. '
            '0 permet de jouer sans boire.',
            style: context.text.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Text('ACTION OU VÉRITÉ', style: context.text.labelMedium),
          _RuleStepper(
            label: 'Défi refusé',
            value: rules.actionRefusal,
            onChanged: (int v) =>
                state.setGameRules(rules.copyWith(actionRefusal: v)),
          ),
          _RuleStepper(
            label: 'Autre carte',
            value: rules.actionRedraw,
            onChanged: (int v) =>
                state.setGameRules(rules.copyWith(actionRedraw: v)),
          ),
          Divider(color: colors.borderSoft),
          Text('JE N’AI JAMAIS', style: context.text.labelMedium),
          _RuleStepper(
            label: 'Joueur concerné',
            value: rules.jamaisConcerned,
            onChanged: (int v) =>
                state.setGameRules(rules.copyWith(jamaisConcerned: v)),
          ),
          Divider(color: colors.borderSoft),
          Text('TU PRÉFÈRES', style: context.text.labelMedium),
          _RuleStepper(
            label: 'Minorité ou égalité',
            value: rules.prefereMinority,
            onChanged: (int v) =>
                state.setGameRules(rules.copyWith(prefereMinority: v)),
          ),
          Divider(color: colors.borderSoft),
          Text('QUI POURRAIT…', style: context.text.labelMedium),
          _RuleStepper(
            label: 'Joueur le plus désigné',
            value: rules.quiDesigne,
            onChanged: (int v) =>
                state.setGameRules(rules.copyWith(quiDesigne: v)),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => state.resetGameRules(),
              child: const Text('Valeurs par défaut'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleStepper extends StatelessWidget {
  const _RuleStepper({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodyMedium,
          ),
        ),
        IconButton(
          tooltip: 'Diminuer : $label',
          visualDensity: VisualDensity.compact,
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline_rounded, size: 22),
        ),
        SizedBox(
          width: 24,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: context.text.titleMedium,
          ),
        ),
        IconButton(
          tooltip: 'Augmenter : $label',
          visualDensity: VisualDensity.compact,
          onPressed: value < GameRules.limit
              ? () => onChanged(value + 1)
              : null,
          icon: const Icon(Icons.add_circle_outline_rounded, size: 22),
        ),
      ],
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
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
    final colors = context.culColors;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 19, color: colors.textSecondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: context.text.titleMedium),
                Text(subtitle, style: context.text.bodySmall),
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

class _HapticsTile extends StatelessWidget {
  const _HapticsTile({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    final bool on = state.hapticsEnabled;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.vibration_rounded,
                size: 19,
                color: colors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Vibrations', style: context.text.titleMedium),
                    Text(
                      'À chaque moment marquant du jeu',
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
              ),
              MiniSwitch(
                value: on,
                onChanged: (bool v) {
                  state.setHaptics(v);
                  Haptics.enabled = v;
                  if (v) Haptics.medium();
                },
              ),
            ],
          ),
          if (on) ...<Widget>[
            const SizedBox(height: AppSpacing.sm + 2),
            Divider(height: 1, color: colors.borderSoft),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Rien ne se passe ? Vérifiez que le mode vibreur est '
                    'activé dans les réglages du téléphone.',
                    style: context.text.bodySmall?.copyWith(fontSize: 11.5),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                TextButton.icon(
                  onPressed: () async {
                    final ScaffoldMessengerState messenger =
                        ScaffoldMessenger.of(context);
                    unawaited(Haptics.demo());
                    final String info = await Haptics.diagnose();
                    messenger
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          content: Text(info),
                          duration: const Duration(seconds: 5),
                        ),
                      );
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 16),
                  label: const Text('Tester'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({
    required this.player,
    required this.onToggle,
    required this.onEdit,
    required this.dragHandle,
  });

  final Player player;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final Widget dragHandle;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    final bool on = player.isSelected;

    return AnimatedOpacity(
      duration: AppMotion.base,
      opacity: on ? 1 : 0.45,
      child: AppCard(
        padding: const EdgeInsets.only(
          left: AppSpacing.md - 2,
          top: AppSpacing.sm + 3,
          bottom: AppSpacing.sm + 3,
          right: 0,
        ),
        accent: on ? player.color : null,
        onTap: onToggle,
        child: Row(
          children: <Widget>[
            AnimatedContainer(
              duration: AppMotion.base,
              curve: AppMotion.emphasized,
              width: 23,
              height: 23,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? player.color : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: on ? player.color : colors.border,
                  width: 1.6,
                ),
              ),
              child: on
                  ? const Icon(
                      Icons.check_rounded,
                      size: 15,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: AppSpacing.md - 2),
            AvatarView.fromPlayer(player, size: 40),
            const SizedBox(width: AppSpacing.md - 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          player.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleMedium,
                        ),
                      ),
                      if (player.noDrink) ...<Widget>[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.no_drinks_rounded,
                          size: 15,
                          color: AppColors.modePrefere,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    player.gamesPlayed == 0
                        ? 'Jamais joué'
                        : '${player.gamesPlayed} parties · '
                            '${player.totalSips} gorgées',
                    style: context.text.bodySmall?.copyWith(fontSize: 11.5),
                  ),
                ],
              ),
            ),
            Pressable(
              onTap: onEdit,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Icon(
                  Icons.more_horiz_rounded,
                  size: 20,
                  color: colors.textMuted,
                ),
              ),
            ),
            dragHandle,
          ],
        ),
      ),
    );
  }
}

class _PlayerEditSheet extends StatefulWidget {
  const _PlayerEditSheet({required this.player});

  final Player player;

  @override
  State<_PlayerEditSheet> createState() => _PlayerEditSheetState();
}

class _PlayerEditSheetState extends State<_PlayerEditSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.player.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar(AppState state, Player player) async {
    final AvatarChoice? choice = await AvatarPickerSheet.show(
      context,
      currentEmoji: player.emoji,
      currentPhoto: player.photoBase64,
      color: player.color,
      taken: takenAvatars(state.roster, except: player),
    );
    if (choice == null || !mounted) return;

    if (choice.photoBase64 != null) {
      await state.setPhoto(player.id, choice.photoBase64);
    } else if (choice.emoji != null) {
      await state.setAvatar(player.id, choice.emoji!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    final AppState state = context.watch<AppState>();
    final Player player = widget.player;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
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
            Text('NOM', style: context.text.labelMedium),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              style: context.text.titleMedium,
              onSubmitted: (String v) => state.renamePlayer(player.id, v),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('AVATAR', style: context.text.labelMedium),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                AvatarView.fromPlayer(player, size: 56),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppButton(
                    label: player.hasPhoto
                        ? 'Changer la photo'
                        : 'Choisir un avatar',
                    primary: false,
                    icon: Icons.face_retouching_natural_outlined,
                    onPressed: () => _pickAvatar(state, player),
                  ),
                ),
              ],
            ),
            if (player.hasPhoto) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    Haptics.tick();
                    state.clearPhoto(player.id);
                  },
                  icon: const Icon(Icons.close_rounded, size: 15),
                  label: const Text('Revenir à un avatar'),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text('BOISSON', style: context.text.labelMedium),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              accent: player.noDrink ? AppColors.modePrefere : null,
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.no_drinks_rounded,
                    size: 20,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Je ne bois pas',
                          style: context.text.titleMedium,
                        ),
                        Text(
                          'Ses gorgées deviennent des gages',
                          style: context.text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  MiniSwitch(
                    value: player.noDrink,
                    onChanged: (bool v) {
                      Haptics.tick();
                      state.setNoDrink(player.id, v);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: AppButton(
                    label: 'Supprimer',
                    primary: false,
                    icon: Icons.delete_outline_rounded,
                    onPressed: () {
                      Haptics.heavy();
                      state.deletePlayer(player.id);
                      Navigator.of(context).pop();
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm + 2),
                Expanded(
                  child: AppButton(
                    label: 'Terminé',
                    color: player.color,
                    onPressed: () {
                      state.renamePlayer(player.id, _name.text);
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRoster extends StatelessWidget {
  const _EmptyRoster();

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.fill,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.people_outline_rounded,
            size: 30,
            color: colors.textMuted,
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          Text(
            'Ajoutez vos habitués une fois.\n'
            'Ils seront proposés à chaque soirée.',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium,
          ),
        ],
      ),
    );
  }
}