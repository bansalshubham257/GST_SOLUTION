// lib/features/invoice/presentation/pages/invoice_detail_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../providers/invoice_provider.dart';
import '../../domain/entities/invoice_entity.dart';
import '../../data/services/invoice_pdf_service.dart';

class InvoiceDetailPage extends ConsumerWidget {
  final String invoiceId;
  final InvoiceEntity? initialInvoice;

  const InvoiceDetailPage({super.key, required this.invoiceId, this.initialInvoice});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If we have an invoice entity passed directly, display it (no provider lookup)
    if (initialInvoice != null) {
      debugPrint('[InvoiceDetail] Using initialInvoice id=${initialInvoice!.id}');
      return _InvoiceDetailView(invoice: initialInvoice!);
    }

    debugPrint('[InvoiceDetail] No initialInvoice, falling back to provider for $invoiceId');
    final invoiceAsync = ref.watch(invoiceDetailProvider(invoiceId));

    return invoiceAsync.when(
      data: (invoice) => invoice == null
          ? Scaffold(
              appBar: AppBar(title: const Text('Invoice')),
              body: const EmptyState(icon: Icons.receipt_long_outlined, title: 'Invoice not found', subtitle: ''),
            )
          : _InvoiceDetailView(invoice: invoice),
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Invoice')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Scaffold(
        appBar: AppBar(title: const Text('Invoice')),
        body: const EmptyState(icon: Icons.error_outline, title: 'Error', subtitle: 'Could not load invoice'),
      ),
    );
  }
}

class _InvoiceDetailView extends ConsumerStatefulWidget {
  final InvoiceEntity invoice;

  const _InvoiceDetailView({required this.invoice});

  @override
  ConsumerState<_InvoiceDetailView> createState() => _InvoiceDetailViewState();
}

class _InvoiceDetailViewState extends ConsumerState<_InvoiceDetailView> {
  bool _isGeneratingPdf = false;

  InvoiceEntity get invoice => widget.invoice;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(invoice.invoiceNumber),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () => _shareInvoice(context),
          ),
          PopupMenuButton<String>(
            onSelected: (action) => _handleAction(context, ref, action),
            itemBuilder: (_) => [
              if (invoice.isDraft)
                const PopupMenuItem(value: 'edit', child: ListTile(
                  leading: Icon(Icons.edit_outlined), title: Text('Edit'), contentPadding: EdgeInsets.zero,
                )),
               const PopupMenuItem(value: 'quickPrint', child: ListTile(
                 leading: Icon(Icons.print_outlined), title: Text('Quick Print'), contentPadding: EdgeInsets.zero,
               )),
               const PopupMenuItem(value: 'preview', child: ListTile(
                 leading: Icon(Icons.preview_outlined), title: Text('Preview & Print'), contentPadding: EdgeInsets.zero,
               )),
              const PopupMenuItem(value: 'download', child: ListTile(
                leading: Icon(Icons.download_outlined), title: Text('Download PDF'), contentPadding: EdgeInsets.zero,
              )),
              const PopupMenuItem(value: 'duplicate', child: ListTile(
                leading: Icon(Icons.copy_outlined), title: Text('Duplicate'), contentPadding: EdgeInsets.zero,
              )),
              if (!invoice.isCancelled)
                const PopupMenuItem(value: 'cancel', child: ListTile(
                  leading: Icon(Icons.cancel_outlined, color: AppColors.danger), title: Text('Cancel Invoice', style: TextStyle(color: AppColors.danger)), contentPadding: EdgeInsets.zero,
                )),
            ],
          ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: _isGeneratingPdf,
        message: 'Generating PDF...',
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusBanner(context),
                    const SizedBox(height: 16),
                    _buildInvoiceMeta(context),
                    const SizedBox(height: 16),
                    _buildCustomerCard(context),
                    const SizedBox(height: 16),
                    _buildLineItemsCard(context),
                    const SizedBox(height: 16),
                    _buildTaxSummaryCard(context),
                    const SizedBox(height: 16),
                    _buildTotalsCard(context),
                    if (invoice.notes != null) ...[
                      const SizedBox(height: 16),
                      _buildNotesCard(context),
                    ],
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
            _buildActionBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner(BuildContext context) {
    Color bg, fg;
    IconData icon;

    switch (invoice.status.toLowerCase()) {
      case 'paid':
        bg = AppColors.successLight; fg = AppColors.success; icon = Icons.check_circle;
      case 'sent':
        bg = AppColors.infoLight; fg = AppColors.info; icon = Icons.send;
      case 'overdue':
        bg = AppColors.dangerLight; fg = AppColors.danger; icon = Icons.warning;
      case 'cancelled':
        bg = AppColors.surfaceVariantLight; fg = AppColors.textSecondaryLight; icon = Icons.cancel;
      default:
        bg = AppColors.accentSurface; fg = AppColors.accent; icon = Icons.edit;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 20),
          const SizedBox(width: 8),
          Text(
            invoice.status.toUpperCase(),
            style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const Spacer(),
          Text(
            'Created ${DateFormat('dd MMM yyyy').format(invoice.createdAt)}',
            style: TextStyle(color: fg.withOpacity(0.8), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceMeta(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: _metaItem(context, 'Invoice No.', invoice.invoiceNumber),
          ),
          const VerticalDivider(width: 24, indent: 8, endIndent: 8),
          Expanded(
            child: _metaItem(context, 'Invoice Date', DateFormat('dd MMM yyyy').format(invoice.invoiceDate)),
          ),
          if (invoice.dueDate != null) ...[
            const VerticalDivider(width: 24, indent: 8, endIndent: 8),
            Expanded(
              child: _metaItem(context, 'Due Date', DateFormat('dd MMM yyyy').format(invoice.dueDate!)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metaItem(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(value, style: Theme.of(context).textTheme.titleSmall, overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _buildCustomerCard(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bill To', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(invoice.customerName, style: Theme.of(context).textTheme.titleMedium, overflow: TextOverflow.ellipsis),
          if (invoice.customerGstin != null) ...[
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.business, size: 14, color: AppColors.textSecondaryLight),
              const SizedBox(width: 4),
              Text('GSTIN: ${invoice.customerGstin}', style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis),
            ]),
          ],
          if (invoice.customerPhone != null) ...[
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.phone_outlined, size: 14, color: AppColors.textSecondaryLight),
              const SizedBox(width: 4),
              Text(invoice.customerPhone!, style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis),
            ]),
          ],
          if (invoice.customerAddress != null) ...[
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondaryLight),
              const SizedBox(width: 4),
              Expanded(child: Text(invoice.customerAddress!, style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis)),
            ]),
          ],
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: invoice.isInterState ? AppColors.accentSurface : AppColors.primarySurface,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              invoice.isInterState ? 'Inter-state (IGST)' : 'Intra-state (CGST+SGST)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: invoice.isInterState ? AppColors.accent : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineItemsCard(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Services', style: Theme.of(context).textTheme.titleMedium),
          ),
          const Divider(height: 1),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: invoice.lineItems.length,
            itemBuilder: (_, i) => _buildLineItem(context, invoice.lineItems[i]),
          ),
        ],
      ),
    );
  }

  Widget _buildLineItem(BuildContext context, InvoiceLineItemEntity item) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.description, style: Theme.of(context).textTheme.titleSmall, overflow: TextOverflow.ellipsis),
                        if (item.hsnSacCode != null)
                          Text('HSN/SAC: ${item.hsnSacCode}', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Text(
                    '₹${item.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _pill('${item.quantity} ${item.unit} × ₹${item.unitPrice}'),
                  const SizedBox(width: 6),
                  _pill('GST ${item.gstRate.toInt()}%'),
                  if (item.discountPercent > 0) ...[
                    const SizedBox(width: 6),
                    _pill('Disc ${item.discountPercent.toInt()}%'),
                  ],
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1, indent: 12, endIndent: 12),
      ],
    );
  }

  Widget _pill(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: AppColors.surfaceVariantLight, borderRadius: BorderRadius.circular(4)),
    child: Text(text, style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
  );

  Widget _buildTaxSummaryCard(BuildContext context) {
    if (invoice.gstSlabs.isEmpty) return const SizedBox.shrink();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('GST Summary', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Table(
            columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1), 3: FlexColumnWidth(1)},
            children: [
              _tableHeader(['GST Rate', invoice.isInterState ? 'IGST' : 'CGST', invoice.isInterState ? '' : 'SGST', 'Taxable']),
              ...invoice.gstSlabs.map((slab) => _tableRow([
                '${slab.rate.toInt()}%',
                invoice.isInterState ? '₹${slab.igst.toStringAsFixed(2)}' : '₹${slab.cgst.toStringAsFixed(2)}',
                invoice.isInterState ? '' : '₹${slab.sgst.toStringAsFixed(2)}',
                '₹${slab.taxableAmount.toStringAsFixed(2)}',
              ])),
            ],
          ),
        ],
      ),
    );
  }

  TableRow _tableHeader(List<String> cells) => TableRow(
    decoration: const BoxDecoration(color: AppColors.surfaceVariantLight),
    children: cells.map((c) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Text(c, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondaryLight)),
    )).toList(),
  );

  TableRow _tableRow(List<String> cells) => TableRow(
    children: cells.map((c) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Text(c, style: const TextStyle(fontSize: 12)),
    )).toList(),
  );

  Widget _buildTotalsCard(BuildContext context) {
    return AppCard(
      color: AppColors.primarySurface,
      child: Column(
        children: [
          _totalRow(context, 'Sub Total', invoice.subTotal),
          if (!invoice.isInterState) ...[
            _totalRow(context, 'CGST', invoice.totalCgst, color: AppColors.cgstColor),
            _totalRow(context, 'SGST', invoice.totalSgst, color: AppColors.sgstColor),
          ],
          if (invoice.isInterState)
            _totalRow(context, 'IGST', invoice.totalIgst, color: AppColors.igstColor),
          if (invoice.totalCess > 0) _totalRow(context, 'Cess', invoice.totalCess),
          if (invoice.discountAmount > 0) _totalRow(context, 'Discount', -invoice.discountAmount, color: AppColors.danger),
          const Divider(),
          if (invoice.roundOff != 0) _totalRow(context, 'Round Off', invoice.roundOff),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              Text(
                '₹${invoice.grandTotal.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _totalRow(BuildContext context, String label, double amount, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: color ?? AppColors.textSecondaryLight, fontSize: 14)),
          Text('₹${amount.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildNotesCard(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Notes', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(invoice.notes!, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildActionBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.borderLight)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Preview',
                isOutlined: true,
                icon: Icons.preview_outlined,
                onPressed: () => context.push('${AppRoutes.serviceHistory}/${invoice.id}/preview'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: AppButton(
                label: 'Download PDF',
                icon: Icons.download_outlined,
                onPressed: _isGeneratingPdf ? null : () => _downloadPdf(context),
                isLoading: _isGeneratingPdf,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'edit':
        context.push('${AppRoutes.serviceHistory}/${invoice.id}/edit');
      case 'preview':
        context.push('${AppRoutes.serviceHistory}/${invoice.id}/preview');
      case 'quickPrint':
        _quickPrint(context);
      case 'download':
        _downloadPdf(context);
      case 'duplicate':
        // TODO: duplicate
        break;
      case 'cancel':
        _confirmCancel(context, ref);
    }
  }

  Future<void> _quickPrint(BuildContext context) async {
    await InvoicePdfService.printInvoice(invoice);
  }

  Future<void> _downloadPdf(BuildContext context) async {
    await InvoicePdfService.downloadAndShare(
      invoice,
      context,
      onLoading: (loading) {
        if (mounted) setState(() => _isGeneratingPdf = loading);
      },
    );
  }

  Future<void> _shareInvoice(BuildContext context) async {
    // Share the actual PDF instead of plain text
    await InvoicePdfService.downloadAndShare(invoice, context,
        onLoading: (loading) {
      if (mounted) setState(() => _isGeneratingPdf = loading);
    });
  }

  void _confirmCancel(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Invoice?'),
        content: const Text('This action cannot be undone. The invoice will be marked as cancelled.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Keep')),
          ElevatedButton(
            onPressed: () {
              ref.read(createInvoiceProvider.notifier).cancelInvoice(invoice.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Cancel Invoice'),
          ),
        ],
      ),
    );
  }
}

