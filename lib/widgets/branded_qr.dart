import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// QR code brandé : bords arrondis, yeux ronds, points ronds, logo au
/// centre.
///
/// **Pourquoi le niveau H** : un logo central masque une partie des
/// modules du QR. Le niveau H tolère 30 % de dégradation — largement
/// suffisant pour un logo de 22 %.
///
/// **Pourquoi les yeux et points ronds** : sur les appareils photo
/// récents, les modules circulaires sont mieux détectés que les carrés
/// quand l'image est légèrement floue. C'est le style utilisé par les
/// générateurs de QR modernes (Google, Apple).
class BrandedQr extends StatelessWidget {
  const BrandedQr({
    super.key,
    required this.data,
    this.size = 220,
    this.backgroundColor = Colors.white,
    this.foregroundColor = const Color(0xFF0B0A12),
    this.cornerRadius = 24,
    this.logoCornerRadius = 999,
  });

  /// Contenu encodé dans le QR.
  final String data;

  /// Côté du QR en pixels logiques.
  final double size;

  final Color backgroundColor;
  final Color foregroundColor;

  /// Rayon des coins du fond blanc.
  final double cornerRadius;

  /// Rayon des coins du logo central. 999 = cercle parfait.
  final double logoCornerRadius;

  @override
  Widget build(BuildContext context) {
    // Le logo occupe 22 % du côté, soit ~5 % de la surface totale.
    // Bien en dessous de la marge de sécurité du niveau H.
    final double logoSize = size * 0.22;
    // Petit espace entre le logo et les modules : améliore la fiabilité
    // de lecture et donne un rendu plus propre.
    final double logoPadding = logoSize * 0.10;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(cornerRadius),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            // --- Le QR ---
            QrImageView(
              data: data,
              version: QrVersions.auto,
              size: size,
              // Niveau H : indispensable avec un logo au centre.
              errorCorrectionLevel: QrErrorCorrectLevel.H,
              backgroundColor: backgroundColor,

              // --- Yeux ronds (les 3 carrés des coins) ---
              eyeStyle: QrEyeStyle(
                eyeShape: QrEyeShape.circle,
                color: foregroundColor,
              ),

              // --- Points ronds (chaque module) ---
              dataModuleStyle: QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.circle,
                color: foregroundColor,
              ),
            ),

            // --- Le logo posé par-dessus ---
            Container(
              width: logoSize,
              height: logoSize,
              padding: EdgeInsets.all(logoPadding),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(logoCornerRadius),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  logoCornerRadius - logoPadding,
                ),
                child: Image.asset(
                  'assets/images/logo_cul_sec.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}