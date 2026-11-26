import 'package:flutter/material.dart';

import '../data/avatar_catalog.dart';
import '../models/player.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_picker_sheet.dart';
import '../widgets/avatar_view.dart';
import '../widgets/common.dart';

/// Écran de création de personnage pour le multijoueur local.
class CreateCharacterScreen extends StatefulWidget {
  const CreateCharacterScreen({
    super.key,
    this.title = 'Créer ton personnage',
    this.buttonLabel = 'Valider',
    this.initialPlayer,
  });

  final String title;
  final String buttonLabel;
  final Player? initialPlayer;

  @override
  State<CreateCharacterScreen> createState() => _CreateCharacterScreenState();
}

class _CreateCharacterScreenState extends State<CreateCharacterScreen> {
  final TextEditingController _nameController = TextEditingController();
  String _selectedAvatar = AvatarCatalog.defaultFor(0);
  String? _selectedPhoto;

  @override
  void initState() {
    super.initState();
    
    // Si on a un joueur existant, on pré-remplit les champs
    if (widget.initialPlayer != null) {
      _nameController.text = widget.initialPlayer!.name;
      _selectedAvatar = widget.initialPlayer!.emoji;
      _selectedPhoto = widget.initialPlayer!.photoBase64;
    }

    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _isValidName => _nameController.text.trim().length >= 3;

  Future<void> _pickAvatar() async {
    FocusScope.of(context).unfocus(); // Ferme le clavier pour éviter les conflits
    
    final AvatarChoice? choice = await AvatarPickerSheet.show(
      context,
      currentEmoji: _selectedAvatar,
      currentPhoto: _selectedPhoto,
      color: AppColors.accent,
    );
    if (choice == null || !mounted) return;
    
    if (choice.emoji != null) {
      setState(() {
        _selectedAvatar = choice.emoji!;
        _selectedPhoto = null;
      });
    } else if (choice.photoBase64 != null) {
      setState(() {
        _selectedPhoto = choice.photoBase64;
      });
    }
  }

  void _submit() {
    if (!_isValidName) return;
    
    FocusScope.of(context).unfocus();
    final String name = _nameController.text.trim();

    final Player player = Player(
      id: widget.initialPlayer?.id ?? 'p_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      emoji: _selectedAvatar,
      photoBase64: _selectedPhoto,
      colorIndex: widget.initialPlayer?.colorIndex ?? 0, // Sera réassigné par le contrôleur
    );

    Navigator.of(context).pop(player);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.culColors;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const SizedBox(height: AppSpacing.md),
                    
                    // --- Avatar ---
                    Center(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _pickAvatar,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            AvatarView(
                              emoji: _selectedAvatar,
                              photoBase64: _selectedPhoto,
                              color: AppColors.accent,
                              size: 100,
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: colors.surfaceTop,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.edit_rounded,
                                size: 20,
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Center(
                      child: TextButton.icon(
                        onPressed: _pickAvatar,
                        icon: const Icon(Icons.face_retouching_natural, size: 18),
                        label: const Text('Choisir un avatar'),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // --- Prénom ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('TON PRÉNOM', style: context.text.labelMedium),
                        if (_nameController.text.isNotEmpty && !_isValidName)
                          Text(
                            '3 lettres minimum',
                            style: context.text.bodySmall?.copyWith(
                              color: AppColors.danger,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      style: context.text.headlineMedium?.copyWith(fontSize: 24),
                      decoration: InputDecoration(
                        hintText: 'Ex: Marie',
                        contentPadding: const EdgeInsets.all(AppSpacing.lg),
                        errorText: _nameController.text.isNotEmpty && !_isValidName
                            ? 'Trop court'
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // --- Bouton toujours visible en bas ---
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: AppButton(
                label: widget.buttonLabel,
                icon: Icons.check_rounded,
                color: AppColors.accent,
                onPressed: _isValidName ? _submit : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}