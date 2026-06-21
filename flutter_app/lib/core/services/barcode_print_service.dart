import 'dart:typed_data';

import 'package:barcode/barcode.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class BarcodePrintService {
  BarcodePrintService._();

  /// Generate a PDF with barcode labels and open the system print dialog.
  static Future<void> printLabels(
    List<(String name, String code, int copies)> items,
  ) async {
    final pdf = await _generatePdf(items);
    await Printing.layoutPdf(onLayout: (_) => Future.value(pdf));
  }

  static Future<Uint8List> _generatePdf(
    List<(String name, String code, int copies)> items,
  ) async {
    const labelWidth = 60.0;
    const labelHeight = 32.0;
    const margin = 8.0;
    const gap = 4.0;

    const pageWidth = 210.0;
    const pageHeight = 297.0;

    final cols = ((pageWidth - 2 * margin) / (labelWidth + gap)).floor();
    final rows = ((pageHeight - 2 * margin) / (labelHeight + gap)).floor();
    if (cols == 0 || rows == 0) return Uint8List(0);

    final doc = pw.Document();

    final labels = <(String name, String code)>[];
    for (final item in items) {
      for (int i = 0; i < item.$3; i++) {
        labels.add((item.$1, item.$2));
      }
    }

    for (int pageStart = 0;
        pageStart < labels.length;
        pageStart += cols * rows) {
      final end = (pageStart + cols * rows).clamp(0, labels.length);
      final pageLabels = labels.sublist(pageStart, end);

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(margin * PdfPageFormat.mm),
          build: (context) => [
            pw.Wrap(
              spacing: gap * PdfPageFormat.mm,
              runSpacing: gap * PdfPageFormat.mm,
              children: pageLabels.map((l) {
                return _buildLabel(l.$1, l.$2, labelWidth, labelHeight);
              }).toList(),
            ),
          ],
        ),
      );
    }

    return doc.save();
  }

  static pw.Widget _buildLabel(
    String name,
    String code,
    double wMm,
    double hMm,
  ) {
    return pw.Container(
      width: wMm * PdfPageFormat.mm,
      height: hMm * PdfPageFormat.mm,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            name,
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center,
            maxLines: 2,
          ),
          pw.SizedBox(height: 2),
          pw.SizedBox(
            width: wMm * 0.85 * PdfPageFormat.mm,
            height: 12 * PdfPageFormat.mm,
            child: pw.BarcodeWidget(
              data: code,
              barcode: Barcode.code128(),
              color: PdfColors.black,
              drawText: false,
            ),
          ),
          pw.SizedBox(height: 1),
          pw.Text(
            code,
            style: pw.TextStyle(fontSize: 6, font: pw.Font.courier()),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }
}
