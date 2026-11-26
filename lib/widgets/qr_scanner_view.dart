import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_theme.dart';

class QrScannerView extends StatefulWidget {
  const QrScannerView({
    super.key,
    required this.onDetect,
    this.title = 'Scanner le QR Code',
    this.color = AppColors.accent,
  });

  final void Function(BarcodeCapture) onDetect;
  final String title;
  final Color color;

  @override
  State<QrScannerView> createState() => _QrScannerViewState();
}

class _QrScannerViewState extends State<QrScannerView> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetectInternal(BarcodeCapture capture) {
    if (_handled) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty || barcodes.first.rawValue == null) return;
    
    _handled = true;
    widget.onDetect(capture);
  }

  @override
  Widget build(BuildContext context) {
    // Taille du carré de scan (70% de la largeur de l'écran max 300px)
    final double scanSize = MediaQuery.sizeOf(context).width * 0.7;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. La caméra plein écran
          MobileScanner(
            controller: _controller,
            onDetect: _onDetectInternal,
          ),

          // 2. L'overlay sombre avec le trou au milieu
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.75),
              BlendMode.srcOut,
            ),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Center(
                  child: Container(
                    width: scanSize,
                    height: scanSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Le cadre délimitant tout le tour et la ligne animée
          Center(
            child: SizedBox(
              width: scanSize,
              height: scanSize,
              child: Stack(
                children: [
                  // Le cadre complet
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: widget.color,
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: widget.color.withValues(alpha: 0.3),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Ligne de scan animée
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Container(
                            height: 2,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  widget.color.withValues(alpha: 0),
                                  widget.color,
                                  widget.color.withValues(alpha: 0),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: widget.color,
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          )
                              .animate(onPlay: (c) => c.repeat())
                              .moveY(
                                begin: 0,
                                end: constraints.maxHeight - 2,
                                duration: 2.seconds,
                                curve: Curves.easeInOut,
                              );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Texte d'aide en bas
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Text(
              'Placez le QR Code dans le cadre',
              textAlign: TextAlign.center,
              style: context.text.titleMedium?.copyWith(
                color: Colors.white,
                shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}