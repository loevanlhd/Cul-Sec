import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Sons du jeu, joués par Android via le canal natif `cul_sec/sounds`
/// (`SoundPool` dans `MainActivity.kt`) : aucun plugin à ajouter.
///
/// Désactivés par défaut ; le joueur les active dans les réglages.
/// Sur iOS (pas de canal natif), les sons sont simplement ignorés.
enum Sfx {
  tick('tick', 0.35),
  pop('pop', 0.6),
  reveal('reveal', 0.7),
  success('success', 0.7),
  fail('fail', 0.7),
  sanction('sanction', 0.7),
  event('event', 0.85),
  drumroll('drumroll', 0.8),
  land('land', 0.8),
  fanfare('fanfare', 0.85);

  const Sfx(this.file, this.volume);

  final String file;
  final double volume;

  String get asset => 'assets/sounds/$file.ogg';
}

class Sounds {
  const Sounds._();

  static const MethodChannel _channel = MethodChannel('cul_sec/sounds');

  static bool _enabled = false;
  static bool _available = defaultTargetPlatform == TargetPlatform.android;
  static bool _preloaded = false;

  static bool get enabled => _enabled;

  /// Active ou coupe les sons. Le premier allumage précharge les fichiers.
  static set enabled(bool value) {
    _enabled = value;
    if (value) preload();
  }

  static Future<void> preload() async {
    if (!_available || _preloaded) return;
    _preloaded = true;
    try {
      await _channel.invokeMethod<bool>('preload', <String, Object>{
        'assets': Sfx.values.map((Sfx s) => s.asset).toList(),
      });
    } on MissingPluginException {
      _available = false;
    } on PlatformException {
      _preloaded = false;
    }
  }

  static void play(Sfx sfx) {
    if (!_enabled || !_available) return;
    _channel.invokeMethod<bool>('play', <String, Object>{
      'asset': sfx.asset,
      'volume': sfx.volume,
    }).catchError((Object _) {
      return false;
    });
  }
}
