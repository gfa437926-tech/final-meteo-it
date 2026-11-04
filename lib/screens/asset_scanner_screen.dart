import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class AssetScannerScreen extends StatefulWidget {
  const AssetScannerScreen({super.key});

  @override
  State<AssetScannerScreen> createState() => _AssetScannerScreenState();
}

class _AssetScannerScreenState extends State<AssetScannerScreen> {
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final value = capture.barcodes
        .map((barcode) => barcode.rawValue?.trim() ?? '')
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    if (value.isEmpty) return;
    _handled = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('مسح باركود / QR')),
        body: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(onDetect: _onDetect),
            Center(
              child: Container(
                width: 260,
                height: 180,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.tealAccent, width: 3),
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
            const Positioned(
              left: 20,
              right: 20,
              bottom: 32,
              child: Text(
                'وجّه الكاميرا نحو الرمز حتى تتم قراءته تلقائياً',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                ),
              ),
            ),
          ],
        ),
      );
}
