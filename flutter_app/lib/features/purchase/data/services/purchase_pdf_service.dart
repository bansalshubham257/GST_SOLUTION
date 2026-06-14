import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/entities/purchase_entity.dart';
import '../../../../core/storage/local_storage.dart';

class PurchasePdfService {
  PurchasePdfService._();

  static String? _businessName;
  static String? _gstinLine;
  static String? _businessAddressFull;

  static void _loadBusinessData() {
    if (_businessName != null) return;
    final box = LocalStorage.businessBox;
    final name = box.get('name', defaultValue: '') as String;
    final gstin = box.get('gstin', defaultValue: '') as String;
    final address = box.get('address', defaultValue: '') as String;
    final city = box.get('city', defaultValue: '') as String;
    final state = box.get('state', defaultValue: '') as String;
    final pincode = box.get('pincode', defaultValue: '') as String;

    _businessName = name;
    _gstinLine = gstin.isNotEmpty ? 'GSTIN: $gstin' : null;
    _businessAddressFull = [
      if (address.isNotEmpty) address,
      if (city.isNotEmpty) city,
      if (state.isNotEmpty) state,
      if (pincode.isNotEmpty) pincode,
    ].join(', ');
  }

  static Future<Uint8List> generatePdf(
    PurchaseEntity purchase, {
    PdfPageFormat format = PdfPageFormat.a4,
  }) async {
    _businessName = null;
    _gstinLine = null;
    _businessAddressFull = null;

    _loadBusinessData();

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          _buildHeader(purchase),
          pw.SizedBox(height: 20),
          pw.Divider(thickness: 2, color: PdfColor.fromHex('#2563EB')),
          pw.SizedBox(height: 16),
          _buildSupplierSection(purchase),
          pw.SizedBox(height: 20),
          _buildLineItems(purchase),
          pw.SizedBox(height: 16),
          _buildTaxSummary(purchase),
          pw.SizedBox(height: 16),
          _buildTotals(purchase),
          if (purchase.notes != null) ...[
            pw.SizedBox(height: 16),
            _buildNotes(purchase),
          ],
          pw.SizedBox(height: 40),
          _buildFooter(),
        ],
      ),
    );

    return pdf.save();
  }

  static Future<File?> downloadAndShare(
    PurchaseEntity purchase,
    BuildContext context, {
    void Function(bool isLoading)? onLoading,
  }) async {
    onLoading?.call(true);
    try {
      final Uint8List bytes;
      try {
        bytes = await generatePdf(purchase);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF generation failed: $e'),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return null;
      }

      final fileName = '${purchase.purchaseNumber}.pdf';

      File file;
      try {
        if (Platform.isAndroid) {
          final downloadDir = Directory('/storage/emulated/0/Download');
          if (await downloadDir.exists()) {
            file = File('${downloadDir.path}/$fileName');
          } else {
            final docDir = await getApplicationDocumentsDirectory();
            file = File('${docDir.path}/$fileName');
          }
        } else {
          final docDir = await getApplicationDocumentsDirectory();
          file = File('${docDir.path}/$fileName');
        }
        await file.writeAsBytes(bytes);
      } catch (e) {
        try {
          final docDir = await getApplicationDocumentsDirectory();
          file = File('${docDir.path}/$fileName');
          await file.writeAsBytes(bytes);
        } catch (e2) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Could not save PDF: $e2'),
                backgroundColor: Colors.red.shade600,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return null;
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('PDF saved to Downloads'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      try {
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/pdf')],
          subject: 'Purchase ${purchase.purchaseNumber}',
        );
      } catch (_) {
      }
      return file;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return null;
    } finally {
      onLoading?.call(false);
    }
  }

  static Future<void> printInvoice(PurchaseEntity purchase) async {
    final bytes = await generatePdf(purchase);
    await Printing.layoutPdf(onLayout: (_) => Future.value(bytes));
  }

  static pw.Widget _buildHeader(PurchaseEntity purchase) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'PURCHASE INVOICE',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#2563EB'),
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text('Purchase No: ${purchase.purchaseNumber}',
                style: const pw.TextStyle(fontSize: 12)),
            pw.Text(
                'Date: ${DateFormat('dd/MM/yyyy').format(purchase.invoiceDate)}',
                style: const pw.TextStyle(fontSize: 12)),
            if (purchase.dueDate != null)
              pw.Text(
                'Due Date: ${DateFormat('dd/MM/yyyy').format(purchase.dueDate!)}',
                style: const pw.TextStyle(
                    fontSize: 12, color: PdfColors.red),
              ),
          ],
        ),
        pw.Container(
          width: 140,
          height: 60,
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#EFF6FF'),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Center(
            child: pw.Text(
              _businessName ?? 'Business Name',
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#2563EB'),
                  fontSize: 12),
              textAlign: pw.TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildSupplierSection(PurchaseEntity purchase) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('FROM',
                    style: const pw.TextStyle(
                        fontSize: 10, color: PdfColors.grey600)),
                pw.Text(purchase.supplierName,
                    style:
                        pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                if (purchase.supplierGstin != null)
                  pw.Text('GSTIN: ${purchase.supplierGstin}',
                      style: const pw.TextStyle(fontSize: 10)),
                if (purchase.supplierAddress != null)
                  pw.Text(purchase.supplierAddress!,
                      style: const pw.TextStyle(fontSize: 10)),
                if (purchase.supplierPhone != null)
                  pw.Text('Ph: ${purchase.supplierPhone}',
                      style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 16),
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('BILL TO',
                    style: const pw.TextStyle(
                        fontSize: 10, color: PdfColors.grey600)),
                pw.Text(_businessName ?? 'Business Name',
                    style:
                        pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                if (_gstinLine != null)
                  pw.Text(_gstinLine!,
                      style: const pw.TextStyle(fontSize: 10)),
                pw.Text(_businessAddressFull ?? '',
                    style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildLineItems(PurchaseEntity purchase) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(4),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1),
        4: const pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(
          decoration:
              pw.BoxDecoration(color: PdfColor.fromHex('#2563EB')),
          children: ['Description', 'Qty', 'Rate', 'GST%', 'Amount']
              .map(
                (h) => pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(h,
                      style: pw.TextStyle(
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10)),
                ),
              )
              .toList(),
        ),
        ...purchase.lineItems.map(
          (item) => pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(item.description,
                        style: const pw.TextStyle(fontSize: 10)),
                    if (item.hsnSacCode != null)
                      pw.Text('HSN: ${item.hsnSacCode}',
                          style: const pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.grey600)),
                  ],
                ),
              ),
              pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text('${item.quantity}',
                      style: const pw.TextStyle(fontSize: 10))),
              pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text('Rs. ${item.unitPrice}',
                      style: const pw.TextStyle(fontSize: 10))),
              pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text('${item.gstRate.toInt()}%',
                      style: const pw.TextStyle(fontSize: 10))),
              pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                      'Rs. ${item.totalAmount.toStringAsFixed(2)}',
                      style: const pw.TextStyle(fontSize: 10))),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTaxSummary(PurchaseEntity purchase) {
    if (purchase.gstSlabs.isEmpty) return pw.SizedBox();

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('GST Summary',
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, fontSize: 11)),
          pw.SizedBox(height: 8),
          ...purchase.gstSlabs.map(
            (slab) => pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('GST @ ${slab.rate.toInt()}%',
                    style: const pw.TextStyle(fontSize: 10)),
                pw.Text(
                    'Taxable: Rs. ${slab.taxableAmount.toStringAsFixed(2)}',
                    style: const pw.TextStyle(fontSize: 10)),
                if (!purchase.isInterState) ...[
                  pw.Text('CGST: Rs. ${slab.cgst.toStringAsFixed(2)}',
                      style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('SGST: Rs. ${slab.sgst.toStringAsFixed(2)}',
                      style: const pw.TextStyle(fontSize: 10)),
                ] else
                  pw.Text('IGST: Rs. ${slab.igst.toStringAsFixed(2)}',
                      style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTotals(PurchaseEntity purchase) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          width: 240,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#EFF6FF'),
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(
                color: PdfColor.fromHex('#2563EB'), width: 0.5),
          ),
          child: pw.Column(
            children: [
              _totalRow('Sub Total', purchase.subTotal),
              if (!purchase.isInterState) ...[
                _totalRow('CGST', purchase.totalCgst),
                _totalRow('SGST', purchase.totalSgst),
              ],
              if (purchase.isInterState)
                _totalRow('IGST', purchase.totalIgst),
              pw.Divider(),
              if (purchase.roundOff != 0)
                _totalRow('Round Off', purchase.roundOff),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 14)),
                  pw.Text(
                      'Rs. ${purchase.grandTotal.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 16,
                          color: PdfColor.fromHex('#2563EB')),),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _totalRow(String label, double amount) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label,
                style: const pw.TextStyle(
                    fontSize: 11, color: PdfColors.grey700)),
            pw.Text('Rs. ${amount.toStringAsFixed(2)}',
                style: const pw.TextStyle(fontSize: 11)),
          ],
        ),
      );

  static pw.Widget _buildNotes(PurchaseEntity purchase) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Notes',
              style: const pw.TextStyle(
                  fontSize: 10, color: PdfColors.grey600)),
          pw.SizedBox(height: 4),
          pw.Text(purchase.notes!,
              style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Column(
      children: [
        pw.Divider(),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'This is a computer-generated invoice and does not require a signature.',
              style: const pw.TextStyle(
                  fontSize: 9, color: PdfColors.grey600),
            ),
            pw.Text('Generated by GST Solution',
                style: const pw.TextStyle(
                    fontSize: 9, color: PdfColors.grey600)),
          ],
        ),
      ],
    );
  }
}
