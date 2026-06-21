import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/storage/local_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_widgets.dart';

class SalesRegisterPage extends ConsumerWidget {
  const SalesRegisterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoices = LocalStorage.getAllCachedInvoices();
    final sorted = invoices
        .map((m) => Map<String, dynamic>.from(m))
        .toList()
      ..sort((a, b) {
        final da = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime(2000);
        final db = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime(2000);
        return db.compareTo(da);
      });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Register'),
        actions: [
          if (sorted.isNotEmpty)
            TextButton(
              onPressed: () => _showSummary(context, sorted),
              child: const Text('Summary'),
            ),
        ],
      ),
      body: sorted.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.textTertiaryLight),
                  SizedBox(height: 8),
                  Text('No invoices found', style: TextStyle(color: AppColors.textSecondaryLight)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: sorted.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final inv = sorted[index];
                final date = DateTime.tryParse(inv['invoiceDate'] ?? inv['createdAt'] ?? '');
                final dateStr = date != null ? DateFormat('dd/MM/yy').format(date) : '--';
                final customer = inv['customerName'] ?? inv['customer'] ?? 'Walk-in';
                final taxable = (inv['totalTaxable'] ?? inv['grandTotal'] ?? 0).toDouble();
                final gst = (inv['totalTax'] ?? 0).toDouble();
                final grandTotal = (inv['grandTotal'] ?? 0).toDouble();
                final paymentMode = (inv['paymentMode'] ?? 'cash').toString().toUpperCase();
                final paymentStatus = (inv['paymentStatus'] ?? 'paid') as String;
                final invoiceNo = inv['invoiceNumber'] ?? inv['id'] ?? '--';

                final lineItems = (inv['lineItems'] as List? ?? []);
                final itemsSummary = lineItems
                    .map((i) => Map<String, dynamic>.from(i))
                    .map((i) => '${i['description'] ?? '?'} x${i['quantity'] ?? 1}')
                    .join(', ');

                return AppCard(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text('#$invoiceNo',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: paymentStatus == 'unpaid'
                                    ? AppColors.dangerLight
                                    : AppColors.successLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(paymentStatus == 'unpaid' ? 'Unpaid' : 'Paid',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: paymentStatus == 'unpaid'
                                          ? AppColors.danger
                                          : AppColors.success)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(dateStr,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                        const SizedBox(height: 4),
                        Text(customer.toString(),
                            style: const TextStyle(fontWeight: FontWeight.w500)),
                        if (itemsSummary.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(itemsSummary,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                        ],
                        const Divider(height: 16),
                        Row(
                          children: [
                            Text('Taxable: ₹${_format(taxable)}',
                                style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 12),
                            Text('GST: ₹${_format(gst)}',
                                style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 12),
                            Text('₹${_format(grandTotal)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimaryLight)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(paymentMode,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showSummary(BuildContext context, List<Map<String, dynamic>> sorted) {
    double taxable = 0;
    double gst = 0;
    double amount = 0;
    for (final inv in sorted) {
      taxable += (inv['totalTaxable'] ?? inv['grandTotal'] ?? 0).toDouble();
      gst += (inv['totalTax'] ?? 0).toDouble();
      amount += (inv['grandTotal'] ?? 0).toDouble();
    }

    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Sales Register Summary',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _summaryRow('Total Invoices', '${sorted.length}'),
            _summaryRow('Total Taxable', '₹${_format(taxable)}'),
            _summaryRow('Total GST', '₹${_format(gst)}'),
            const Divider(),
            _summaryRow('Grand Total', '₹${_format(amount)}',
                isBold: true),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, fontWeight: isBold ? FontWeight.w600 : FontWeight.normal)),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.w700 : FontWeight.w600)),
        ],
      ),
    );
  }

  String _format(double v) => v.toStringAsFixed(2);
}
