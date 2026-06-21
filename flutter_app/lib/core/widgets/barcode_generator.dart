// lib/core/widgets/barcode_generator.dart

import 'package:barcode/barcode.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Renders a scannable barcode (EAN-13 or Code128) for an item.
class BarcodeGenerator extends StatelessWidget {
  final String data;
  final double height;
  final double width;

  const BarcodeGenerator({
    super.key,
    required this.data,
    this.height = 50,
    this.width = 200,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Clipboard.setData(ClipboardData(text: data)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            size: Size(width, height),
            painter: _BarcodePainter(data: data),
          ),
          const SizedBox(height: 4),
          Text(data, style: const TextStyle(fontSize: 10, fontFamily: 'monospace', letterSpacing: 1)),
        ],
      ),
    );
  }
}

class _BarcodePainter extends CustomPainter {
  final String data;
  _BarcodePainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    final bc = Barcode.code128();
    final elements = bc.make(data, width: size.width, height: size.height);
    final bars = elements.whereType<BarcodeBar>().toList();
    if (bars.isEmpty) return;

    final paint = Paint()..color = Colors.black;

    for (final bar in bars) {
      if (bar.black) {
        canvas.drawRect(
          Rect.fromLTWH(bar.left, bar.top, bar.width, bar.height),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Generates a unique EAN-13-compatible barcode number for items without one.
class BarcodeGeneratorUtil {
  static String generateEan13(int id) {
    // Use item id as base, pad to 12 digits, calculate check digit
    final base = id.toString().padLeft(12, '0');
    if (base.length > 12) return base.substring(0, 12);
    var sum = 0;
    for (int i = 0; i < 12; i++) {
      final digit = int.parse(base[i]);
      sum += (i % 2 == 0) ? digit : digit * 3;
    }
    final check = (10 - (sum % 10)) % 10;
    return '$base$check';
  }

  /// Generate a simpler short code (8 chars) for items
  static String generateShortCode(int id) {
    return 'ITEM${id.toString().padLeft(5, '0')}';
  }
}
