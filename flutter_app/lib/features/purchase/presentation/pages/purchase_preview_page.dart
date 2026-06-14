import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../../core/storage/local_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../providers/purchase_provider.dart';
import '../../domain/entities/purchase_entity.dart';
import '../../data/services/purchase_pdf_service.dart';

class PurchasePreviewPage extends ConsumerWidget {
  final String purchaseId;

  const PurchasePreviewPage({super.key, required this.purchaseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    PurchaseEntity? purchase;
    try {
      final cached = LocalStorage.getCachedPurchase(purchaseId);
      if (cached != null) {
        final converted = Map<String, dynamic>.from(cached);
        if (converted['lineItems'] is List) {
          converted['lineItems'] = (converted['lineItems'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
        if (converted['gstSlabs'] is List) {
          converted['gstSlabs'] = (converted['gstSlabs'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
        purchase = PurchaseEntityJson.fromJson(converted);
      }
    } catch (e) {
      debugPrint('[PurchasePreview] Load failed for $purchaseId: $e');
    }

    if (purchase == null) {
      return const Scaffold(body: Center(child: Text('Purchase not found')));
    }

    return _PurchasePreviewView(purchase: purchase);
  }
}

class _PurchasePreviewView extends StatefulWidget {
  final PurchaseEntity purchase;

  const _PurchasePreviewView({required this.purchase});

  @override
  State<_PurchasePreviewView> createState() => _PurchasePreviewViewState();
}

class _PurchasePreviewViewState extends State<_PurchasePreviewView> {
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Preview: ${widget.purchase.purchaseNumber}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Print',
            onPressed: _printInvoice,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share PDF',
            onPressed: _sharePdf,
          ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: _isGenerating,
        message: 'Generating PDF...',
        child: PdfPreview(
          build: (format) => _generatePdf(format),
          pdfFileName: '${widget.purchase.purchaseNumber}.pdf',
          allowSharing: true,
          allowPrinting: true,
          canChangePageFormat: false,
          actions: const [],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.borderLight)),
        ),
        child: SafeArea(
          child: AppButton(
            label: 'Download PDF',
            icon: Icons.download_outlined,
            onPressed: () => _downloadPdf(context),
            isLoading: _isGenerating,
          ),
        ),
      ),
    );
  }

  Future<Uint8List> _generatePdf(PdfPageFormat format) =>
      PurchasePdfService.generatePdf(widget.purchase, format: format);

  Future<void> _printInvoice() =>
      PurchasePdfService.printInvoice(widget.purchase);

  Future<void> _sharePdf() async {
    await PurchasePdfService.downloadAndShare(
      widget.purchase,
      context,
      onLoading: (v) => setState(() => _isGenerating = v),
    );
  }

  Future<void> _downloadPdf(BuildContext context) async {
    await PurchasePdfService.downloadAndShare(
      widget.purchase,
      context,
      onLoading: (v) => setState(() => _isGenerating = v),
    );
  }
}
