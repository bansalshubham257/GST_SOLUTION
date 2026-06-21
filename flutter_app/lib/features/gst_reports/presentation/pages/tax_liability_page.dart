import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/local_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_widgets.dart';

class TaxLiabilityPage extends ConsumerWidget {
  const TaxLiabilityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoices = LocalStorage.getAllCachedInvoices();
    final purchases = LocalStorage.getAllCachedPurchases();

    double outputCgst = 0, outputSgst = 0, outputIgst = 0, outputTotalGst = 0;
    double inputCgst = 0, inputSgst = 0, inputIgst = 0, inputTotalGst = 0;
    double totalSales = 0, totalPurchases = 0;

    for (final raw in invoices) {
      final inv = Map<String, dynamic>.from(raw);
      outputCgst += (inv['totalCgst'] ?? 0).toDouble();
      outputSgst += (inv['totalSgst'] ?? 0).toDouble();
      outputIgst += (inv['totalIgst'] ?? 0).toDouble();
      outputTotalGst += (inv['totalTax'] ?? 0).toDouble();
      totalSales += (inv['grandTotal'] ?? 0).toDouble();
    }

    for (final raw in purchases) {
      final pur = Map<String, dynamic>.from(raw);
      if ((pur['status'] ?? '') == 'cancelled') continue;
      inputCgst += (pur['totalCgst'] ?? 0).toDouble();
      inputSgst += (pur['totalSgst'] ?? 0).toDouble();
      inputIgst += (pur['totalIgst'] ?? 0).toDouble();
      inputTotalGst += (pur['totalTax'] ?? 0).toDouble();
      totalPurchases += (pur['grandTotal'] ?? 0).toDouble();
    }

    final netCgst = outputCgst - inputCgst;
    final netSgst = outputSgst - inputSgst;
    final netIgst = outputIgst - inputIgst;
    final netTotal = outputTotalGst - inputTotalGst;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tax Liability'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Output Tax Card
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.arrow_upward, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text('Output Tax (Sales)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _taxRow('Taxable Sales', '₹${_format(totalSales)}', null),
                  const Divider(height: 16),
                  _taxRow('CGST', '₹${_format(outputCgst)}', AppColors.primary),
                  _taxRow('SGST', '₹${_format(outputSgst)}', AppColors.primary),
                  _taxRow('IGST', '₹${_format(outputIgst)}', AppColors.primary),
                  const Divider(height: 16),
                  _taxRow('Total Output GST', '₹${_format(outputTotalGst)}', AppColors.primary, bold: true),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Input Tax Credit Card
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.successLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.arrow_downward, color: AppColors.success, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text('Input Tax Credit (Purchases)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _taxRow('Taxable Purchases', '₹${_format(totalPurchases)}', null),
                  const Divider(height: 16),
                  _taxRow('CGST', '₹${_format(inputCgst)}', AppColors.success),
                  _taxRow('SGST', '₹${_format(inputSgst)}', AppColors.success),
                  _taxRow('IGST', '₹${_format(inputIgst)}', AppColors.success),
                  const Divider(height: 16),
                  _taxRow('Total ITC', '₹${_format(inputTotalGst)}', AppColors.success, bold: true),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Net Tax Liability Card
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: netTotal > 0 ? AppColors.warningLight : AppColors.successLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          netTotal > 0 ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                          color: netTotal > 0 ? AppColors.warning : AppColors.success,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(netTotal > 0 ? 'Net Tax Payable' : 'Excess ITC (Credit)',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _taxRow('Net CGST', '₹${_format(netCgst)}',
                      netCgst > 0 ? AppColors.warning : AppColors.success),
                  _taxRow('Net SGST', '₹${_format(netSgst)}',
                      netSgst > 0 ? AppColors.warning : AppColors.success),
                  _taxRow('Net IGST', '₹${_format(netIgst)}',
                      netIgst > 0 ? AppColors.warning : AppColors.success),
                  const Divider(height: 16),
                  _taxRow(
                    netTotal > 0 ? 'Total Payable' : 'Total Credit',
                    '₹${_format(netTotal.abs())}',
                    netTotal > 0 ? AppColors.danger : AppColors.success,
                    bold: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _taxRow(String label, String value, Color? valueColor, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            fontSize: 14,
            fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
            color: AppColors.textSecondaryLight,
          )),
          Text(value, style: TextStyle(
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            fontSize: 14,
            color: valueColor ?? AppColors.textPrimaryLight,
          )),
        ],
      ),
    );
  }

  String _format(double v) => v.toStringAsFixed(2);
}
