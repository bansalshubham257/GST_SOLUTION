// lib/core/widgets/barcode_scanner_sheet.dart
//
// Reusable full-screen barcode / QR scanner.
// Opens as a modal bottom-sheet or as a standalone page.
// Returns the raw barcode value via [onDetected].

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../theme/app_colors.dart';

class BarcodeScannerSheet extends StatefulWidget {
  /// Called once when a code is successfully detected. The sheet auto-closes.
  final void Function(String value, BarcodeFormat format) onDetected;

  /// Optional helper text below the viewfinder
  final String hint;

  /// When `true`, keeps scanning after first detection (for multi-scan).
  final bool continuous;

  const BarcodeScannerSheet({
    super.key,
    required this.onDetected,
    this.hint = 'Point camera at a QR code or barcode',
    this.continuous = false,
  });

  /// Open as a bottom sheet, returns nothing (caller gets results via [onDetected]).
  static Future<void> show(
    BuildContext context, {
    required void Function(String, BarcodeFormat) onDetected,
    String hint = 'Point camera at a QR code or barcode',
    bool continuous = false,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BarcodeScannerSheet(
        onDetected: onDetected,
        hint: hint,
        continuous: continuous,
      ),
    );
  }

  @override
  State<BarcodeScannerSheet> createState() => _BarcodeScannerSheetState();
}

class _BarcodeScannerSheetState extends State<BarcodeScannerSheet> {
  late final MobileScannerController _controller;

  bool _detected = false;
  bool _torchOn = false;
  String? _confirmedValue;  // shows green "Detected" overlay

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      returnImage: false,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_detected) return;          // already accepted one — ignore noise
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final barcode = barcodes.first;
    final raw = barcode.rawValue;
    if (raw == null || raw.isEmpty) return;

    _detected = true;
    HapticFeedback.mediumImpact();

    // Stop camera immediately so no more frames are processed
    _controller.stop();

    if (!widget.continuous) {
      // Show green confirmation overlay for 900ms then close
      setState(() => _confirmedValue = raw);
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) Navigator.of(context).pop();
        widget.onDetected(raw, barcode.format);
      });
    } else {
      setState(() => _confirmedValue = raw);
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          setState(() {
            _confirmedValue = null;
            _detected = false;
          });
          _controller.start();
        }
        widget.onDetected(raw, barcode.format);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scanAreaSize = size.width * 0.7;

    return Container(
      height: size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Stack(
        children: [
          // Camera view
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
            ),
          ),

          // Dark overlay with scan window
          _ScanOverlay(scanAreaSize: scanAreaSize),

          // ── Confirmed overlay ──
          if (_confirmedValue != null)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle, color: Colors.white, size: 40),
                        const SizedBox(height: 10),
                        const Text('Scanned!', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(
                          _confirmedValue!.length > 40
                              ? '${_confirmedValue!.substring(0, 37)}…'
                              : _confirmedValue!,
                          style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Top bar
          if (_confirmedValue == null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Expanded(
                      child: Text(
                        'Scan Code',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _torchOn ? Icons.flash_on : Icons.flash_off,
                        color: _torchOn ? Colors.yellow : Colors.white,
                      ),
                      onPressed: () async {
                        await _controller.toggleTorch();
                        setState(() => _torchOn = !_torchOn);
                      },
                    ),
                  ],
                ),
              ),
            ),

          // Bottom hint
          if (_confirmedValue == null)
            Positioned(
              bottom: 40,
              left: 24,
              right: 24,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.hint,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _formatBadge('QR Code'),
                      const SizedBox(width: 8),
                      _formatBadge('EAN / UPC'),
                      const SizedBox(width: 8),
                      _formatBadge('Code 128'),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _formatBadge(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.primary.withOpacity(0.3),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.primary.withOpacity(0.5)),
    ),
    child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
  );
}

// ─── Scan Overlay ─────────────────────────────────────────────────────────────

class _ScanOverlay extends StatelessWidget {
  final double scanAreaSize;
  const _ScanOverlay({required this.scanAreaSize});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _OverlayPainter(scanAreaSize: scanAreaSize),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  final double scanAreaSize;
  _OverlayPainter({required this.scanAreaSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black54;
    final cx = size.width / 2;
    final cy = size.height / 2 - 30;
    final half = scanAreaSize / 2;
    final scanRect = Rect.fromLTRB(cx - half, cy - half, cx + half, cy + half);

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(scanRect, const Radius.circular(12)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);

    const cornerLen = 24.0;
    final bracketPaint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(scanRect.left, scanRect.top + cornerLen), Offset(scanRect.left, scanRect.top), bracketPaint);
    canvas.drawLine(Offset(scanRect.left, scanRect.top), Offset(scanRect.left + cornerLen, scanRect.top), bracketPaint);
    canvas.drawLine(Offset(scanRect.right - cornerLen, scanRect.top), Offset(scanRect.right, scanRect.top), bracketPaint);
    canvas.drawLine(Offset(scanRect.right, scanRect.top), Offset(scanRect.right, scanRect.top + cornerLen), bracketPaint);
    canvas.drawLine(Offset(scanRect.left, scanRect.bottom - cornerLen), Offset(scanRect.left, scanRect.bottom), bracketPaint);
    canvas.drawLine(Offset(scanRect.left, scanRect.bottom), Offset(scanRect.left + cornerLen, scanRect.bottom), bracketPaint);
    canvas.drawLine(Offset(scanRect.right - cornerLen, scanRect.bottom), Offset(scanRect.right, scanRect.bottom), bracketPaint);
    canvas.drawLine(Offset(scanRect.right, scanRect.bottom), Offset(scanRect.right, scanRect.bottom - cornerLen), bracketPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
