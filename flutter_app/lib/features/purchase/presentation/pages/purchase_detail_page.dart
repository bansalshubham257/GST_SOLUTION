import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/storage/local_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../providers/purchase_provider.dart';
import '../../domain/entities/purchase_entity.dart';
import '../../data/services/purchase_pdf_service.dart';

class PurchaseDetailPage extends ConsumerWidget {
  final String purchaseId;
  final PurchaseEntity? initialPurchase;

  const PurchaseDetailPage({super.key, required this.purchaseId, this.initialPurchase});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (initialPurchase != null) {
      return _PurchaseDetailView(purchase: initialPurchase!);
    }

    PurchaseEntity? loaded;
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
        loaded = PurchaseEntityJson.fromJson(converted);
      }
    } catch (e) {
      debugPrint('[PurchaseDetail] Load failed for $purchaseId: $e');
    }

    if (loaded == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Purchase')),
        body: const EmptyState(icon: Icons.shopping_cart_outlined, title: 'Purchase not found', subtitle: ''),
      );
    }

    return _PurchaseDetailView(purchase: loaded);
  }
}

class _PurchaseDetailView extends ConsumerStatefulWidget {
  final PurchaseEntity purchase;

  const _PurchaseDetailView({required this.purchase});

  @override
  ConsumerState<_PurchaseDetailView> createState() => _PurchaseDetailViewState();
}

class _PurchaseDetailViewState extends ConsumerState<_PurchaseDetailView> {
  bool _isGeneratingPdf = false;

  PurchaseEntity get purchase => widget.purchase;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(purchase.purchaseNumber),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () => _sharePurchase(context),
          ),
          PopupMenuButton<String>(
            onSelected: (action) => _handleAction(context, ref, action),
            itemBuilder: (_) => [
              if (purchase.isDraft)
                const PopupMenuItem(value: 'edit', child: ListTile(
                  leading: Icon(Icons.edit_outlined), title: Text('Edit'), contentPadding: EdgeInsets.zero,
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
              if (!purchase.isCancelled)
                const PopupMenuItem(value: 'cancel', child: ListTile(
                  leading: Icon(Icons.cancel_outlined, color: AppColors.danger), title: Text('Cancel Purchase', style: TextStyle(color: AppColors.danger)), contentPadding: EdgeInsets.zero,
                )),
            ],
          ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: _isGeneratingPdf,
        message: 'Generating PDF...',
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusBanner(context),
            const SizedBox(height: 16),
            _buildPurchaseMeta(context),
            const SizedBox(height: 16),
            _buildSupplierCard(context),
            const SizedBox(height: 16),
            _buildLineItemsCard(context),
            const SizedBox(height: 16),
            _buildTaxSummaryCard(context),
            const SizedBox(height: 16),
            _buildTotalsCard(context),
            if (purchase.notes != null) ...[
              const SizedBox(height: 16),
              _buildNotesCard(context),
            ],
            const SizedBox(height: 80),
          ],
        ),
      ),
      ),
      bottomNavigationBar: _buildActionBar(context),
    );
  }

  Widget _buildStatusBanner(BuildContext context) {
    Color bg, fg;
    IconData icon;

    switch (purchase.status.toLowerCase()) {
      case 'paid':
        bg = AppColors.successLight; fg = AppColors.success; icon = Icons.check_circle;
      case 'pending':
        bg = AppColors.infoLight; fg = AppColors.info; icon = Icons.schedule;
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
            purchase.status.toUpperCase(),
            style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const Spacer(),
          Text(
            'Created ${DateFormat('dd MMM yyyy').format(purchase.createdAt)}',
            style: TextStyle(color: fg.withOpacity(0.8), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseMeta(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: _metaItem(context, 'Purchase No.', purchase.purchaseNumber),
          ),
          const VerticalDivider(width: 24, indent: 8, endIndent: 8),
          Expanded(
            child: _metaItem(context, 'Invoice Date', DateFormat('dd MMM yyyy').format(purchase.invoiceDate)),
          ),
          if (purchase.dueDate != null) ...[
            const VerticalDivider(width: 24, indent: 8, endIndent: 8),
            Expanded(
              child: _metaItem(context, 'Due Date', DateFormat('dd MMM yyyy').format(purchase.dueDate!)),
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

  Widget _buildSupplierCard(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Supplier', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(purchase.supplierName, style: Theme.of(context).textTheme.titleMedium),
          if (purchase.supplierGstin != null) ...[
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.business, size: 14, color: AppColors.textSecondaryLight),
              const SizedBox(width: 4),
              Text('GSTIN: ${purchase.supplierGstin}', style: Theme.of(context).textTheme.bodySmall),
            ]),
          ],
          if (purchase.supplierPhone != null) ...[
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.phone_outlined, size: 14, color: AppColors.textSecondaryLight),
              const SizedBox(width: 4),
              Text(purchase.supplierPhone!, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ],
          if (purchase.supplierAddress != null) ...[
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondaryLight),
              const SizedBox(width: 4),
              Expanded(child: Text(purchase.supplierAddress!, style: Theme.of(context).textTheme.bodySmall)),
            ]),
          ],
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: purchase.isInterState ? AppColors.accentSurface : AppColors.primarySurface,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              purchase.isInterState ? 'Inter-state (IGST)' : 'Intra-state (CGST+SGST)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: purchase.isInterState ? AppColors.accent : AppColors.primary,
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
            child: Text('Items / Services', style: Theme.of(context).textTheme.titleMedium),
          ),
          const Divider(height: 1),
          ...purchase.lineItems.map((item) => _buildLineItem(context, item)),
        ],
      ),
    );
  }

  Widget _buildLineItem(BuildContext context, PurchaseLineItemEntity item) {
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
                        Text(item.description, style: Theme.of(context).textTheme.titleSmall),
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
    if (purchase.gstSlabs.isEmpty) return const SizedBox.shrink();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('GST Summary', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Table(
            columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1), 3: FlexColumnWidth(1)},
            children: [
              _tableHeader(['GST Rate', purchase.isInterState ? 'IGST' : 'CGST', purchase.isInterState ? '' : 'SGST', 'Taxable']),
              ...purchase.gstSlabs.map((slab) => _tableRow([
                '${slab.rate.toInt()}%',
                purchase.isInterState ? '₹${slab.igst.toStringAsFixed(2)}' : '₹${slab.cgst.toStringAsFixed(2)}',
                purchase.isInterState ? '' : '₹${slab.sgst.toStringAsFixed(2)}',
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
          _totalRow(context, 'Sub Total', purchase.subTotal),
          if (!purchase.isInterState) ...[
            _totalRow(context, 'CGST', purchase.totalCgst, color: AppColors.cgstColor),
            _totalRow(context, 'SGST', purchase.totalSgst, color: AppColors.sgstColor),
          ],
          if (purchase.isInterState)
            _totalRow(context, 'IGST', purchase.totalIgst, color: AppColors.igstColor),
          if (purchase.totalCess > 0) _totalRow(context, 'Cess', purchase.totalCess),
          const Divider(),
          if (purchase.roundOff != 0) _totalRow(context, 'Round Off', purchase.roundOff),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              Text(
                '₹${purchase.grandTotal.toStringAsFixed(2)}',
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
          Text(purchase.notes!, style: Theme.of(context).textTheme.bodyMedium),
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
                onPressed: () => context.push('/purchases/${purchase.id}/preview'),
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
        context.push('/purchases/${purchase.id}/edit');
      case 'preview':
        context.push('/purchases/${purchase.id}/preview');
      case 'download':
        _downloadPdf(context);
      case 'duplicate':
        break;
      case 'cancel':
        _confirmCancel(context, ref);
    }
  }

  Future<void> _downloadPdf(BuildContext context) async {
    await PurchasePdfService.downloadAndShare(
      purchase,
      context,
      onLoading: (loading) {
        if (mounted) setState(() => _isGeneratingPdf = loading);
      },
    );
  }

  Future<void> _sharePurchase(BuildContext context) async {
    await PurchasePdfService.downloadAndShare(purchase, context,
        onLoading: (loading) {
      if (mounted) setState(() => _isGeneratingPdf = loading);
    });
  }

  void _confirmCancel(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Purchase?'),
        content: const Text('This action cannot be undone. The purchase will be marked as cancelled.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Keep')),
          ElevatedButton(
            onPressed: () {
              ref.read(createPurchaseProvider.notifier).cancelPurchase(purchase.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Cancel Purchase'),
          ),
        ],
      ),
    );
  }
}
