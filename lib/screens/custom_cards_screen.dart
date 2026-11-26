import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../data/game_modes_catalog.dart';
import '../models/enums.dart';
import '../models/game_mode.dart';
import '../models/prompt.dart';
import '../services/app_state.dart';
import '../services/haptics.dart';
import '../theme/app_theme.dart';
import '../widgets/ambient_background.dart';
import '../widgets/branded_qr.dart';
import '../widgets/common.dart';
import '../widgets/intensity_selector.dart';
import '../widgets/qr_scanner_view.dart';

class CustomCardsScreen extends StatefulWidget {
  const CustomCardsScreen({super.key});

  @override
  State<CustomCardsScreen> createState() => _CustomCardsScreenState();
}

class _CustomCardsScreenState extends State<CustomCardsScreen> {
  GameModeId _filter = GameModeId.values.first;

  Future<void> _openEditor({Prompt? card}) async {
    Haptics.light();
    final GameModeId? savedIn = await showModalBottomSheet<GameModeId>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CustomCardEditorSheet(initialMode: _filter, card: card),
    );
    if (savedIn != null && mounted) setState(() => _filter = savedIn);
  }

  Future<void> _exportCards() async {
    final AppState state = context.read<AppState>();
    final String code = state.exportCustomCards();
    
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune carte perso à partager.')),
      );
      return;
    }

    Haptics.medium();
    
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Partager mes cartes'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Fais scanner ce QR Code par un autre joueur pour lui envoyer tes cartes.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Center(child: BrandedQr(data: code, size: 240)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<void> _importCards() async {
    final String? scannedCode = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => QrScannerView(
          title: 'Scanner les cartes',
          color: AppColors.accent,
          onDetect: (capture) {
            final raw = capture.barcodes.first.rawValue;
            if (raw != null) {
              Haptics.success();
              Navigator.of(context).pop(raw);
            }
          },
        ),
      ),
    );

    if (scannedCode == null || !mounted) return;

    try {
      final int count = await context.read<AppState>().importCustomCards(scannedCode);
      if (count > 0) {
        await Haptics.success();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$count carte(s) importée(s) avec succès !')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aucune nouvelle carte à importer (doublons ignorés).')),
          );
        }
      }
    } on FormatException {
      await Haptics.failure();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR Code invalide ou corrompu.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    final GameMode mode = gameModeById(_filter);
    final List<Prompt> cards = state.customCardsFor(_filter).reversed.toList();
    final int total = state.customCardCount;

    return Scaffold(
      body: AmbientBackground(
        primary: mode.color,
        secondary: mode.colorAlt,
        child: SafeArea(
          child: Column(
            children: <Widget>[
              AppHeader(
                title: 'Mes cartes',
                subtitle: total == 0
                    ? 'Aucune carte perso pour l’instant'
                    : total == 1
                        ? '1 carte perso'
                        : '$total cartes perso',
                onBack: () => Navigator.of(context).pop(),
                action: total == 0
                    ? null
                    : IconButton(
                        icon: Icon(Icons.qr_code_rounded, color: context.culColors.textSecondary),
                        tooltip: 'Partager mes cartes via QR Code',
                        onPressed: _exportCards,
                      ),
              ),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: AppSpacing.screen,
                  itemCount: kGameModes.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (BuildContext context, int i) {
                    final GameMode m = kGameModes[i];
                    final int count = state.customCardsFor(m.id).length;
                    return _ChoicePill(
                      label: count == 0 ? m.title : '${m.title} · $count',
                      icon: m.icon,
                      color: m.color,
                      selected: m.id == _filter,
                      onTap: () {
                        Haptics.tick();
                        setState(() => _filter = m.id);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: cards.isEmpty
                    ? _EmptyCards(mode: mode)
                    : ListView.separated(
                        padding:
                            AppSpacing.screen.copyWith(bottom: AppSpacing.md),
                        itemCount: cards.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm + 2),
                        itemBuilder: (BuildContext context, int i) =>
                            _CardTile(
                          key: ValueKey<String>(cards[i].id),
                          card: cards[i],
                          mode: mode,
                          onTap: () => _openEditor(card: cards[i]),
                        )
                                .animate()
                                .fadeIn(
                                  delay: (i * 35).ms,
                                  duration: 260.ms,
                                ),
                      ),
              ),
              Padding(
                padding: AppSpacing.screen.copyWith(
                  top: AppSpacing.sm,
                  bottom: AppSpacing.md,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: AppButton(
                        label: 'Scanner',
                        primary: false,
                        icon: Icons.qr_code_scanner_rounded,
                        color: mode.color,
                        onPressed: _importCards,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      flex: 2,
                      child: AppButton(
                        label: 'Nouvelle carte',
                        icon: Icons.add_rounded,
                        color: mode.color,
                        onPressed: () => _openEditor(),
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
}

// ---------------------------------------------------------------------------
// Liste
// ---------------------------------------------------------------------------

class _CardTile extends StatelessWidget {
  const _CardTile({
    super.key,
    required this.card,
    required this.mode,
    required this.onTap,
  });

  final Prompt card;
  final GameMode mode;
  final VoidCallback onTap;

  String get _preview => switch (mode.id) {
        GameModeId.jeNaiJamais => 'Je n’ai jamais ${card.text}',
        GameModeId.quiPourrait => 'Qui pourrait ${card.text}',
        GameModeId.tuPreferes => card.options.length > 1
            ? '${card.options[0]}\nou ${card.options[1]}'
            : card.text,
        GameModeId.actionOuVerite => card.text,
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors; // <-- Ajouté
    final Intensity level = card.intensity;
    final TextStyle? meta = context.text.bodySmall?.copyWith(fontSize: 11.5);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _preview,
            style: context.text.titleMedium?.copyWith(height: 1.35),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Icon(level.icon, size: 13, color: level.color),
              const SizedBox(width: 5),
              Text(level.label, style: meta?.copyWith(color: level.color)),
              if (level.isExplicit) ...<Widget>[
                const SizedBox(width: 6),
                const AdultBadge(),
              ],
              if (mode.id == GameModeId.actionOuVerite) ...<Widget>[
                _Dot(style: meta),
                Text(
                  card.kind == PromptKind.action ? 'Action' : 'Vérité',
                  style: meta,
                ),
              ],
              _Dot(style: meta),
              Icon(card.category.icon, size: 12, color: colors.textMuted), // <-- Modifié
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  card.category.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: meta,
                ),
              ),
              Icon(
                Icons.edit_outlined,
                size: 15,
                color: colors.textMuted, // <-- Modifié
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({this.style});

  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text('·', style: style),
      );
}

class _EmptyCards extends StatelessWidget {
  const _EmptyCards({required this.mode});

  final GameMode mode;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.screen,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              mode.icon,
              size: 38,
              color: mode.color.withValues(alpha: 0.7),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Aucune carte perso pour « ${mode.title} »',
              textAlign: TextAlign.center,
              style: context.text.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Blagues internes, prénoms, souvenirs communs : ce sont '
              'souvent les cartes qui marquent le plus une soirée.',
              textAlign: TextAlign.center,
              style: context.text.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Éditeur
// ---------------------------------------------------------------------------

class CustomCardEditorSheet extends StatefulWidget {
  const CustomCardEditorSheet({
    super.key,
    required this.initialMode,
    this.card,
  });

  final GameModeId initialMode;
  final Prompt? card;

  @override
  State<CustomCardEditorSheet> createState() => _CustomCardEditorSheetState();
}

class _CustomCardEditorSheetState extends State<CustomCardEditorSheet> {
  static final RegExp _jamaisPrefix = RegExp(
    r"^\s*je\s+n['’]ai\s+jamais\s*(\.\.\.|…)?\s*",
    caseSensitive: false,
  );
  static final RegExp _quiPrefix = RegExp(
    r'^\s*qui\s+pourrait\s*(\.\.\.|…)?\s*',
    caseSensitive: false,
  );
  static final RegExp _endPunctuation = RegExp(r'[.!?…]$');
  static final RegExp _trailingQuestion = RegExp(r'[\s?]+$');

  late GameModeId _mode = widget.initialMode;
  late PromptKind _kind = widget.card?.kind == PromptKind.verite
      ? PromptKind.verite
      : PromptKind.action;
  late Intensity _intensity = widget.card?.intensity ?? Intensity.normal;
  late GameCategory _category = widget.card?.category ?? GameCategory.amis;

  late final TextEditingController _text = TextEditingController(
    text: widget.card == null || widget.card!.isDilemme
        ? ''
        : widget.card!.text,
  );
  late final TextEditingController _optionA = TextEditingController(
    text: (widget.card?.options.length ?? 0) > 0 ? widget.card!.options[0] : '',
  );
  late final TextEditingController _optionB = TextEditingController(
    text: (widget.card?.options.length ?? 0) > 1 ? widget.card!.options[1] : '',
  );

  bool get _editing => widget.card != null;

  @override
  void initState() {
    super.initState();
    for (final TextEditingController c
        in <TextEditingController>[_text, _optionA, _optionB]) {
      c.addListener(_refresh);
    }
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _text.dispose();
    _optionA.dispose();
    _optionB.dispose();
    super.dispose();
  }

  Prompt? _build() {
    final String id = widget.card?.id ??
        '${Prompt.customPrefix}${DateTime.now().microsecondsSinceEpoch}';
    final int sips = switch (_intensity) {
      Intensity.soft => 1,
      Intensity.normal => 2,
      _ => 3,
    };

    switch (_mode) {
      case GameModeId.tuPreferes:
        final String a = _optionA.text.trim();
        final String b = _optionB.text.trim();
        if (a.isEmpty || b.isEmpty) return null;
        return Prompt(
          id: id,
          text: 'Tu préfères…',
          kind: PromptKind.dilemme,
          intensity: _intensity,
          category: _category,
          gorgees: 2,
          options: <String>[a, b],
        );

      case GameModeId.jeNaiJamais:
        String t = _text.text.trim().replaceFirst(_jamaisPrefix, '');
        if (t.isEmpty) return null;
        if (!_endPunctuation.hasMatch(t)) t = '$t.';
        return Prompt(
          id: id,
          text: t,
          kind: PromptKind.statement,
          intensity: _intensity,
          category: _category,
          gorgees: sips,
        );

      case GameModeId.quiPourrait:
        final String t = _text.text
            .trim()
            .replaceFirst(_quiPrefix, '')
            .replaceFirst(_trailingQuestion, '');
        if (t.isEmpty) return null;
        return Prompt(
          id: id,
          text: '$t ?',
          kind: PromptKind.statement,
          intensity: _intensity,
          category: _category,
          gorgees: sips,
        );

      case GameModeId.actionOuVerite:
        final String t = _text.text.trim();
        if (t.isEmpty) return null;
        return Prompt(
          id: id,
          text: t,
          kind: _kind,
          intensity: _intensity,
          category: _category,
          gorgees: sips,
        );
    }
  }

  Future<void> _save() async {
    final Prompt? card = _build();
    if (card == null) return;
    final AppState state = context.read<AppState>();
    Haptics.medium();
    await state.saveCustomCard(_mode, card);
    if (mounted) Navigator.of(context).pop(_mode);
  }

  Future<void> _delete() async {
    final Prompt? card = widget.card;
    if (card == null) return;
    final AppState state = context.read<AppState>();
    await Haptics.heavy();
    await state.deleteCustomCard(card.id);
    if (mounted) Navigator.of(context).pop();
  }

  Widget _field(
    TextEditingController controller,
    String hint, {
    TextCapitalization capitalization = TextCapitalization.sentences,
    int maxLength = 160,
    int minLines = 2,
  }) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: 4,
      maxLength: maxLength,
      textCapitalization: capitalization,
      style: context.text.titleMedium,
      decoration: InputDecoration(hintText: hint, counterText: ''),
    );
  }

  List<Widget> _textFields() {
    switch (_mode) {
      case GameModeId.tuPreferes:
        return <Widget>[
          const _Hint('La carte s’affichera sous « Tu préfères… ».'),
          const SizedBox(height: AppSpacing.sm),
          _field(
            _optionA,
            'Option A — ex. : Ne plus jamais boire de café',
            maxLength: 90,
            minLines: 1,
          ),
          const SizedBox(height: AppSpacing.sm),
          _field(
            _optionB,
            'Option B — ex. : Ne plus jamais boire d’alcool',
            maxLength: 90,
            minLines: 1,
          ),
        ];
      case GameModeId.jeNaiJamais:
        return <Widget>[
          const _Hint('La carte commencera par « Je n’ai jamais… ».'),
          const SizedBox(height: AppSpacing.sm),
          _field(
            _text,
            'ex. : dormi dans une gare',
            capitalization: TextCapitalization.none,
          ),
        ];
      case GameModeId.quiPourrait:
        return <Widget>[
          const _Hint('La carte commencera par « Qui pourrait… ».'),
          const SizedBox(height: AppSpacing.sm),
          _field(
            _text,
            'ex. : se perdre dans son propre quartier ?',
            capitalization: TextCapitalization.none,
          ),
        ];
      case GameModeId.actionOuVerite:
        return <Widget>[
          _field(
            _text,
            _kind == PromptKind.action
                ? 'ex. : Imite quelqu’un du groupe jusqu’à ce qu’on devine.'
                : 'ex. : Quel est ton pire souvenir de soirée ?',
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors; // <-- Ajouté
    final GameMode mode = gameModeById(_mode);
    final bool valid = _build() != null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        decoration: BoxDecoration( // <-- Retrait du const
          color: colors.surfaceTop, // <-- Modifié
          borderRadius: AppRadii.sheet,
          border: Border(top: BorderSide(color: colors.border)), // <-- Modifié
        ),
        child: SingleChildScrollView(
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
                  decoration: BoxDecoration( // <-- Retrait du const
                    color: colors.border, // <-- Modifié
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                _editing ? 'Modifier la carte' : 'Nouvelle carte',
                style: context.text.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              const _Label('JEU'),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  for (final GameMode m in kGameModes)
                    _ChoicePill(
                      label: m.title,
                      icon: m.icon,
                      color: m.color,
                      selected: m.id == _mode,
                      onTap: () {
                        Haptics.tick();
                        setState(() => _mode = m.id);
                      },
                    ),
                ],
              ),
              if (_mode == GameModeId.actionOuVerite) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                const _Label('TYPE'),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    _ChoicePill(
                      label: 'Action',
                      icon: Icons.bolt_rounded,
                      color: AppColors.modeAction,
                      selected: _kind == PromptKind.action,
                      onTap: () {
                        Haptics.tick();
                        setState(() => _kind = PromptKind.action);
                      },
                    ),
                    _ChoicePill(
                      label: 'Vérité',
                      icon: Icons.chat_bubble_outline_rounded,
                      color: AppColors.modePrefereAlt,
                      selected: _kind == PromptKind.verite,
                      onTap: () {
                        Haptics.tick();
                        setState(() => _kind = PromptKind.verite);
                      },
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              const _Label('TEXTE'),
              ..._textFields(),
              const SizedBox(height: AppSpacing.lg),
              const _Label('INTENSITÉ'),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  for (final Intensity level in Intensity.values)
                    _ChoicePill(
                      label: level.label,
                      icon: level.icon,
                      color: level.color,
                      selected: level == _intensity,
                      onTap: () {
                        Haptics.tick();
                        setState(() => _intensity = level);
                      },
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const _Label('THÈME'),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  for (final GameCategory c in GameCategory.values)
                    _ChoicePill(
                      label: c.label,
                      icon: c.icon,
                      color: mode.color,
                      selected: c == _category,
                      onTap: () {
                        Haptics.tick();
                        setState(() => _category = c);
                      },
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: <Widget>[
                  if (_editing) ...<Widget>[
                    Expanded(
                      child: AppButton(
                        label: 'Supprimer',
                        primary: false,
                        icon: Icons.delete_outline_rounded,
                        onPressed: _delete,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm + 2),
                  ],
                  Expanded(
                    child: AppButton(
                      label: _editing ? 'Enregistrer' : 'Ajouter',
                      icon: Icons.check_rounded,
                      color: mode.color,
                      onPressed: valid ? _save : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(text, style: context.text.labelMedium),
      );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: context.text.bodySmall);
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors; // <-- Ajouté
    return Pressable(
      scale: 0.93,
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.base,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            if (icon != null) ...<Widget>[
              Icon(
                icon,
                size: 13,
                color: selected ? color : colors.textMuted, // <-- Modifié
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: context.text.titleMedium?.copyWith(
                fontSize: 12.5,
                color: selected ? color : colors.textMuted, // <-- Modifié
              ),
            ),
          ],
        ),
      ),
    );
  }
}