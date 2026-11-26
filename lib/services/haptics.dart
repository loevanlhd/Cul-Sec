import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'sounds.dart';

/// ---------------------------------------------------------------------------
/// Retour haptique.
///
/// **Pourquoi un canal natif ?** `HapticFeedback` de Flutter passe par le
/// « retour tactile » du système (`performHapticFeedback`). Sur beaucoup de
/// téléphones — Xiaomi, Redmi, POCO en tête — ce retour est coupé par
/// défaut, trop faible, ou ignoré par la surcouche : rien ne vibre.
///
/// Sur Android, on pilote donc directement le **vibreur** (`Vibrator`) via le
/// canal `cul_sec/haptics` déclaré dans `MainActivity.kt` (permission
/// `VIBRATE` dans le manifeste). Les motifs sont envoyés en une seule fois :
/// le téléphone les joue avec un timing exact.
///
/// Sur iOS (ou si le canal échoue), on retombe sur `HapticFeedback`.
/// Tout peut être coupé d'un seul interrupteur dans les réglages.
///
/// **`unawaited` assumé** : `tick`, `light` et `medium` sont des effets
/// ponctuels qui accompagnent une action immédiate de l'UI. Rien ne dépend
/// de leur fin — on les lance et on passe à autre chose. Les méthodes qui
/// doivent finir avant de continuer (`double`, `triple`, `roll`, `success`,
/// `failure`, `heavy`) restent `async` et attendues à l'appel.
/// ---------------------------------------------------------------------------
class Haptics {
  const Haptics._();

  /// Coupe-circuit global, piloté depuis les réglages.
  static bool enabled = false;

  static const MethodChannel _channel = MethodChannel('cul_sec/haptics');

  /// Passe à `false` si le canal natif est indisponible : on n'essaie plus.
  static bool _native = defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> _pulse(int ms, int amplitude) async {
    if (!_native) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'vibrate',
            <String, int>{'ms': ms, 'amplitude': amplitude},
          ) ??
          false;
    } on MissingPluginException {
      _native = false;
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// [segments] : couples (durée de vibration, intensité) séparés par
  /// [gaps] (pauses en ms, une de moins que de segments).
  static Future<bool> _pattern(
    List<int> on,
    List<int> amps,
    List<int> gaps,
  ) async {
    if (!_native) return false;
    final List<int> timings = <int>[0];
    final List<int> amplitudes = <int>[0];
    for (int i = 0; i < on.length; i++) {
      timings.add(on[i]);
      amplitudes.add(amps[i]);
      if (i < gaps.length) {
        timings.add(gaps[i]);
        amplitudes.add(0);
      }
    }
    try {
      return await _channel.invokeMethod<bool>(
            'pattern',
            <String, List<int>>{'timings': timings, 'amplitudes': amplitudes},
          ) ??
          false;
    } on MissingPluginException {
      _native = false;
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Lance l'appel natif et retombe sur le `HapticFeedback` du système si
  /// celui-ci échoue. Fire-and-forget : aucun appelant n'attend le retour,
  /// et les deux branches sont elles-mêmes des `Future` qu'on ne peut pas
  /// chaîner sans rendre l'API bloquante pour rien.
  static void _fireAndForget(
    Future<bool> native,
    Future<void> Function() fallback,
  ) {
    unawaited(
      native.then((bool ok) async {
        if (!ok) await fallback();
      }),
    );
  }

  /// Sélection, navigation entre cartes. Discret mais perceptible.
  static void tick() {
    Sounds.play(Sfx.tick);
    if (!enabled) return;
    _fireAndForget(_pulse(18, 160), HapticFeedback.selectionClick);
  }

  /// Appui sur un bouton.
  static void light() {
    Sounds.play(Sfx.pop);
    if (!enabled) return;
    _fireAndForget(_pulse(25, 200), HapticFeedback.lightImpact);
  }

  /// Événement marquant : carte révélée, joueur désigné, choix validé.
  static void medium() {
    Sounds.play(Sfx.pop);
    if (!enabled) return;
    _fireAndForget(_pulse(40, 255), HapticFeedback.mediumImpact);
  }

  /// Événement fort : verdict, sanction, dérobade.
  static Future<void> heavy() async {
    Sounds.play(Sfx.event);
    if (!enabled) return;
    if (await _pulse(70, 255)) return;
    await HapticFeedback.heavyImpact();
  }

  /// Deux impulsions rapprochées — révélation d'une carte.
  static Future<void> double({Sfx? sound = Sfx.reveal}) async {
    if (sound != null) Sounds.play(sound);
    if (!enabled) return;
    if (await _pattern(<int>[45, 45], <int>[255, 255], <int>[110])) {
      await Future<void>.delayed(const Duration(milliseconds: 190));
      return;
    }
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 130));
    await HapticFeedback.heavyImpact();
  }

  /// Trois impulsions — sanction encaissée, verdict du groupe.
  static Future<void> triple({Sfx? sound = Sfx.sanction}) async {
    if (sound != null) Sounds.play(sound);
    if (!enabled) return;
    if (await _pattern(
      <int>[45, 45, 60],
      <int>[255, 255, 255],
      <int>[100, 100],
    )) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      return;
    }
    for (int i = 0; i < 3; i++) {
      await HapticFeedback.heavyImpact();
      if (i < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
    }
  }

  /// Roulement d'intensité croissante — suspense avant une révélation.
  /// Les impulsions se resserrent et se renforcent.
  static Future<void> roll() async {
    Sounds.play(Sfx.drumroll);
    if (!enabled) return;
    const List<int> gaps = <int>[190, 160, 130, 100, 80, 60];
    if (await _pattern(
      <int>[18, 20, 22, 24, 28, 32, 90],
      <int>[140, 160, 180, 200, 220, 240, 255],
      gaps,
    )) {
      // Le motif joue en natif : on attend sa fin pour enchaîner l'effet.
      await Future<void>.delayed(const Duration(milliseconds: 920));
      return;
    }
    for (final int gap in gaps) {
      await HapticFeedback.selectionClick();
      await Future<void>.delayed(Duration(milliseconds: gap));
    }
    await HapticFeedback.heavyImpact();
  }

  /// Signature de succès : une impulsion nette suivie d'une plus légère.
  static Future<void> success() async {
    Sounds.play(Sfx.success);
    if (!enabled) return;
    if (await _pattern(<int>[50, 30], <int>[255, 170], <int>[80])) return;
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 90));
    await HapticFeedback.lightImpact();
  }

  /// Signature d'échec : deux impulsions lourdes et lentes.
  static Future<void> failure() async {
    Sounds.play(Sfx.fail);
    if (!enabled) return;
    if (await _pattern(<int>[90, 90], <int>[255, 255], <int>[170])) return;
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 180));
    await HapticFeedback.heavyImpact();
  }

  /// Diagnostic affiché par le bouton « Tester » des réglages.
  static Future<String> diagnose() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return 'Vibrations iOS : retour haptique du système.';
    }
    try {
      final Map<Object?, Object?>? info =
          await _channel.invokeMapMethod<Object?, Object?>('diagnose');
      if (info == null) return 'Vibreur : aucune réponse.';
      if (info['hasVibrator'] != true) {
        return 'Ce téléphone ne déclare aucun vibreur.';
      }
      return 'Vibreur détecté (${info['brand']}, Android SDK ${info['sdk']}).';
    } on MissingPluginException {
      return 'Canal natif introuvable : MainActivity.kt n’est pas à jour '
          '(vérifie son emplacement et sa ligne package).';
    } on PlatformException catch (e) {
      return 'Erreur du vibreur : ${e.message}';
    }
  }

  /// Test depuis les réglages : motif long et identifiable.
  static Future<void> demo() async {
    if (!enabled) return;
    await roll();
    await Future<void>.delayed(const Duration(milliseconds: 220));
    await triple();
  }
}