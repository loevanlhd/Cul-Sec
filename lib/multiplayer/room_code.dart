import 'dart:math';

/// Génère un code de connexion à 6 caractères, lisible à voix haute.
///
/// L'alphabet exclut les caractères visuellement ambigus (0/O, 1/I/L)
/// pour éviter les erreurs de saisie quand quelqu'un dicte le code à
/// un autre joueur.
class RoomCode {
  const RoomCode._();

  static const String _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  static final Random _random = Random.secure();

  static String generate() => List<String>.generate(
        6,
        (_) => _alphabet[_random.nextInt(_alphabet.length)],
      ).join();

  /// Normalise une saisie utilisateur : majuscules, sans espaces ni tirets.
  static String normalize(String input) => input
      .toUpperCase()
      .replaceAll(RegExp(r'[\s\-]'), '')
      .split('')
      .where(_alphabet.contains)
      .join();

  static bool isValid(String code) => normalize(code).length == 6;
}