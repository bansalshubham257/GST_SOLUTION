// lib/features/invoice/presentation/pages/invoice_preview_page.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../providers/invoice_provider.dart';
import '../../domain/entities/invoice_entity.dart';
import '../../data/services/invoice_pdf_service.dart';

class InvoicePreviewPage extends ConsumerWidget {
  final String invoiceId;

  const InvoicePreviewPage({super.key, required this.invoiceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoiceAsync = ref.watch(invoiceDetailProvider(invoiceId));

    return invoiceAsync.when(
      data: (invoice) => invoice == null
          ? const Scaffold(body: Center(child: Text('Invoice not found')))
          : _InvoicePreviewView(invoice: invoice),
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const Scaffold(body: Center(child: Text('Error loading invoice'))),
    );
  }
}

class _InvoicePreviewView extends StatefulWidget {
  final InvoiceEntity invoice;

  const _InvoicePreviewView({required this.invoice});

  @override
  State<_InvoicePreviewView> createState() => _InvoicePreviewViewState();
}

class _InvoicePreviewViewState extends State<_InvoicePreviewView> {
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Preview: ${widget.invoice.invoiceNumber}'),
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
          pdfFileName: '${widget.invoice.invoiceNumber}.pdf',
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
      InvoicePdfService.generatePdf(widget.invoice, format: format);

  Future<void> _printInvoice() =>
      InvoicePdfService.printInvoice(widget.invoice);

  Future<void> _sharePdf() async {
    await InvoicePdfService.downloadAndShare(
      widget.invoice,
      context,
      onLoading: (v) => setState(() => _isGenerating = v),
    );
  }

  Future<void> _downloadPdf(BuildContext context) async {
    await InvoicePdfService.downloadAndShare(
      widget.invoice,
      context,
      onLoading: (v) => setState(() => _isGenerating = v),
    );
  }
}

