import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// ---------------------------------------------------------------------------
/// Force l'écran en haut taux de rafraîchissement.
///
/// **Pourquoi ce service existe** — c'est très probablement la cause
/// principale de ton problème de fluidité : sur de nombreux appareils Android
/// (Xiaomi, Redmi et POCO en tête, mais aussi Samsung et OnePlus), le système
/// démarre les applications tierces en 60 Hz et ne passe en 120/144 Hz que si
/// l'application le demande explicitement. Flutter ne fait pas cette demande
/// tout seul.
///
/// Résultat : l'application tourne à 60 Hz sur un écran 144 Hz. Le défilement
/// paraît saccadé alors que le code peut être parfaitement optimisé — aucune
/// optimisation Dart ne corrigera cela.
///
/// **Pourquoi sans paquet externe** — la version précédente s'appuyait sur
/// `flutter_display_mode`, qui refusait de s'installer derrière le proxy
/// d'entreprise. Ce service fait la même chose via un `MethodChannel` et une
/// vingtaine de lignes de Kotlin dans `MainActivity.kt` : zéro dépendance à
/// télécharger, et le code natif est sous ton contrôle.
///
/// **Côté MIUI**, vérifie aussi :
/// * Paramètres > Écran > Taux de rafraîchissement → « Par défaut » ou
///   « 144 Hz », surtout pas « 60 Hz » ;
/// * économie de batterie désactivée : MIUI force le 60 Hz quand elle tourne.
/// ---------------------------------------------------------------------------
class DisplayService {
  const DisplayService._();

  /// Doit correspondre exactement au nom déclaré dans `MainActivity.kt`.
  static const MethodChannel _channel =
      MethodChannel('cul_sec/display');

  /// À appeler une fois au démarrage, après
  /// `WidgetsFlutterBinding.ensureInitialized()`.
  ///
  /// Ne lève jamais : un échec laisse simplement l'application en 60 Hz.
  static Future<void> enableHighRefreshRate() async {
    // Le canal n'existe que sur Android. Ailleurs, on ne fait rien.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    try {
      final double? rate =
          await _channel.invokeMethod<double>('setHighRefreshRate');

      if (kDebugMode) {
        debugPrint(
          rate == null
              ? '[Display] Aucun mode alternatif disponible.'
              : '[Display] Taux de rafraîchissement demandé : '
                  '${rate.toStringAsFixed(0)} Hz',
        );
      }
    } on MissingPluginException {
      // `MainActivity.kt` n'a pas encore été modifié : on le signale
      // clairement plutôt que d'échouer en silence.
      debugPrint(
        '[Display] Canal natif absent. Vérifie que MainActivity.kt '
        'déclare bien le MethodChannel "cul_sec/display".',
      );
    } catch (error) {
      // Appareil sans mode alternatif, fabricant qui refuse, API indisponible :
      // l'application reste parfaitement fonctionnelle.
      debugPrint('[Display] Haut taux de rafraîchissement indisponible : $error');
    }
  }

  /// Taux réellement appliqué par le système, en Hz. Utile pour vérifier que
  /// la demande a bien été honorée. `null` si l'information est indisponible.
  static Future<double?> currentRefreshRate() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;

    try {
      return await _channel.invokeMethod<double>('getRefreshRate');
    } catch (_) {
      return null;
    }
  }
}