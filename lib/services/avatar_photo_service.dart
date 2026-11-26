import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// ---------------------------------------------------------------------------
/// Capture ou sélection d'une photo d'avatar.
///
/// **Pourquoi la photo est encodée en base64 plutôt que stockée en chemin ?**
///
/// 1. `image_picker` renvoie sur Android un chemin situé dans le cache, que le
///    système peut purger à tout moment. L'avatar disparaîtrait entre deux
///    soirées — exactement ce qu'on ne veut pas pour un répertoire permanent.
/// 2. `dart:io` (et donc `File`) n'existe pas sur le web, où tu itères. Un
///    chemin y serait ininterprétable.
/// 3. `shared_preferences` ne stocke que des types simples : une chaîne base64
///    s'y range sans dépendance supplémentaire — ni `path_provider`, ni base de
///    données.
///
/// L'image est redimensionnée à 512 px et recompressée **avant** encodage, ce
/// qui donne 20 à 40 ko par joueur. On ne garde jamais une photo de 12 Mpx pour
/// l'afficher dans une pastille de 56 px.
///
/// **Garde-fou de taille** : `imageQuality` n'est pris en compte que pour les
/// JPEG. Un PNG de 12 Mpx passerait inchangé, puis serait encodé en base64
/// (soit ~16 Mo écrits dans les préférences). On rejette donc toute image
/// dont l'encodage dépasserait [_maxEncodedBytes].
///
/// **Pourquoi un Result plutôt qu'un simple `String?`** : l'appelant doit
/// distinguer « l'utilisateur a annulé » de « l'image est trop lourde » pour
/// afficher le bon message. Un `null` seul ne le permet pas.
/// ---------------------------------------------------------------------------
class AvatarPhotoService {
  const AvatarPhotoService._();

  static final ImagePicker _picker = ImagePicker();

  /// Côté maximal de l'image conservée, en pixels.
  static const double _maxSide = 512;

  /// Qualité JPEG (0-100). 80 est le bon compromis poids / rendu.
  static const int _quality = 80;

  /// Taille maximale du base64 produit, en octets. 400 Ko laisse de la marge
  /// pour afficher en grand sur un écran haute densité.
  static const int _maxEncodedBytes = 400 * 1024;

  /// La caméra n'est pas accessible sur le web dans tous les navigateurs.
  /// Permet de masquer le bouton plutôt que d'échouer silencieusement.
  static bool get isCameraAvailable => !kIsWeb;

  /// Prend une photo avec l'appareil.
  static Future<AvatarPickResult> takePhoto() => _pick(ImageSource.camera);

  /// Choisit une image dans la bibliothèque.
  static Future<AvatarPickResult> pickFromGallery() =>
      _pick(ImageSource.gallery);

  static Future<AvatarPickResult> _pick(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: _maxSide,
        maxHeight: _maxSide,
        imageQuality: _quality,
        preferredCameraDevice: CameraDevice.front,
      );

      if (file == null) return const AvatarPickResult.cancelled();

      final Uint8List bytes = await file.readAsBytes();

      // Base64 gonfle de ~33 % : on compare la taille encodée, pas la brute.
      if (bytes.length * 4 ~/ 3 > _maxEncodedBytes) {
        debugPrint(
          'Avatar refusé : ${bytes.length} octets, dépasse la limite de '
          '$_maxEncodedBytes octets encodés.',
        );
        return const AvatarPickResult.tooLarge();
      }

      return AvatarPickResult.success(base64Encode(bytes));
    } catch (error, stack) {
      // Permission refusée, appareil indisponible, format illisible…
      debugPrint('Avatar photo indisponible : $error\n$stack');
      return const AvatarPickResult.unavailable();
    }
  }
}

/// Résultat d'une tentative de capture : succès, annulation, refus de taille
/// ou indisponibilité matérielle.
class AvatarPickResult {
  const AvatarPickResult._(this.base64, this.status);

  const AvatarPickResult.success(String data)
      : this._(data, AvatarPickStatus.success);

  const AvatarPickResult.cancelled()
      : this._(null, AvatarPickStatus.cancelled);

  const AvatarPickResult.tooLarge()
      : this._(null, AvatarPickStatus.tooLarge);

  const AvatarPickResult.unavailable()
      : this._(null, AvatarPickStatus.unavailable);

  final String? base64;
  final AvatarPickStatus status;
}

enum AvatarPickStatus { success, cancelled, tooLarge, unavailable }