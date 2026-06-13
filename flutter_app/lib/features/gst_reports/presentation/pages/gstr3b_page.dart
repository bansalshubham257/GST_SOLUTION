// lib/features/gst_reports/presentation/pages/gstr3b_page.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../providers/gst_reports_provider.dart';

class Gstr3bPage extends ConsumerStatefulWidget {
  const Gstr3bPage({super.key});

  @override
  ConsumerState<Gstr3bPage> createState() => _Gstr3bPageState();
}

class _Gstr3bPageState extends ConsumerState<Gstr3bPage> {
  DateTime _selectedMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(gstMonthlySummaryProvider(_selectedMonth));

    return Scaffold(
      appBar: AppBar(
        title: const Text('GSTR-3B Draft'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('Export'),
            onPressed: () => _exportJson(context),
          ),
        ],
      ),
      body: summary.when(
        data: (data) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMonthPicker(context),
              const SizedBox(height: 20),
              _buildSectionTitle(context, '3.1 Details of Outward Supplies'),
              const SizedBox(height: 8),
              _buildOutwardSuppliesTable(context, data),
              const SizedBox(height: 20),
              _buildSectionTitle(context, '3.2 Of the supplies above, details of inter-state supplies'),
              const SizedBox(height: 8),
              _buildInterStateTable(context, data),
              const SizedBox(height: 20),
              _buildSectionTitle(context, '4. Eligible ITC'),
              const SizedBox(height: 8),
              _buildItcSection(context),
              const SizedBox(height: 20),
              _buildSectionTitle(context, '5. Values of exempt, nil rated and non-GST inward supplies'),
              const SizedBox(height: 8),
              _buildExemptSection(context),
              const SizedBox(height: 20),
              _buildTaxPayableSummary(context, data),
              const SizedBox(height: 80),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const EmptyState(icon: Icons.summarize_outlined, title: 'No data', subtitle: 'No GST data available'),
      ),
    );
  }

  Widget _buildMonthPicker(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1)),
        ),
        Text(
          'Period: ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _selectedMonth.month == DateTime.now().month ? null
              : () => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1)),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(8),
        border: const Border(left: BorderSide(color: AppColors.primary, width: 3)),
      ),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary, fontSize: 13)),
    );
  }

  Widget _buildOutwardSuppliesTable(BuildContext context, GstMonthlySummary data) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _tableHeader(['Nature', 'Taxable Value', 'IGST', 'CGST', 'SGST']),
          _tableRow('(a) Outward taxable supplies (other than zero rated, nil rated)', data.totalTaxable, data.totalIgst, data.totalCgst, data.totalSgst),
          _tableRow('(b) Outward taxable supplies (zero rated)', 0, 0, 0, 0),
          _tableRow('(c) Other outward supplies (nil rated, exempted)', 0, 0, 0, 0),
          _tableRow('(d) Inward supplies (liable to reverse charge)', 0, 0, 0, 0),
          _tableTotalRow('Total (A)', data.totalTaxable, data.totalIgst, data.totalCgst, data.totalSgst),
        ],
      ),
    );
  }

  Widget _buildInterStateTable(BuildContext context, GstMonthlySummary data) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _tableHeader(['Place of Supply', 'Taxable Value', 'IGST']),
          Container(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Inter-state supply details based on Place of Supply',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItcSection(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('ITC Available (Auto-populated)', style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 13)),
              const Text('₹ 0.00', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Note: Phase 1 does not capture purchase/inward invoices. ITC must be entered manually during actual filing.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.warning, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildExemptSection(BuildContext context) {
    return AppCard(
      child: Text(
        'No exempt/nil-rated supplies recorded for this period.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondaryLight),
      ),
    );
  }

  Widget _buildTaxPayableSummary(BuildContext context, GstMonthlySummary data) {
    return AppCard(
      color: AppColors.primarySurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tax Payable Summary', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _summaryRow('CGST Payable', data.totalCgst, AppColors.cgstColor),
          _summaryRow('SGST Payable', data.totalSgst, AppColors.sgstColor),
          _summaryRow('IGST Payable', data.totalIgst, AppColors.igstColor),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Tax Payable', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              Text(
                '₹${data.totalTax.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warningLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.warning, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This is a draft preparation. Please verify and file through the official GST portal.',
                    style: TextStyle(color: AppColors.warning, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double amount, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 14)),
          Text('₹${amount.toStringAsFixed(2)}', style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _tableHeader(List<String> headers) {
    return Container(
      color: AppColors.surfaceVariantLight,
      child: Row(
        children: headers.map((h) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Text(h, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondaryLight)),
          ),
        )).toList(),
      ),
    );
  }

  Widget _tableRow(String nature, double taxable, double igst, double cgst, double sgst) {
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.borderLight, width: 0.5))),
      child: Row(
        children: [
          Expanded(flex: 3, child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(nature, style: const TextStyle(fontSize: 11)),
          )),
          Expanded(child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text('₹${taxable.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11)),
          )),
          Expanded(child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text('₹${igst.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: AppColors.igstColor)),
          )),
          Expanded(child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text('₹${cgst.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: AppColors.cgstColor)),
          )),
          Expanded(child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text('₹${sgst.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: AppColors.sgstColor)),
          )),
        ],
      ),
    );
  }

  Widget _tableTotalRow(String label, double taxable, double igst, double cgst, double sgst) {
    return Container(
      color: AppColors.primarySurface,
      child: Row(
        children: [
          Expanded(flex: 3, child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
          )),
          Expanded(child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text('₹${taxable.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          )),
          Expanded(child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text('₹${igst.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          )),
          Expanded(child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text('₹${cgst.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          )),
          Expanded(child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text('₹${sgst.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          )),
        ],
      ),
    );
  }

  void _exportJson(BuildContext context) async {
    final summary = ref.read(gstMonthlySummaryProvider(_selectedMonth)).valueOrNull;
    if (summary == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No GSTR-3B data available'), backgroundColor: AppColors.warning),
      );
      return;
    }

    try {
      final jsonData = {
        'period': DateFormat('yyyy-MM').format(_selectedMonth),
        'outwardSupplies': {
          'taxable': summary.totalTaxable,
          'cgst': summary.totalCgst,
          'sgst': summary.totalSgst,
          'igst': summary.totalIgst,
          'totalTax': summary.totalTax,
        },
        'slabSummary': summary.slabSummaries.map((s) => {
          'rate': s.rate,
          'taxableAmount': s.taxableAmount,
          'cgst': s.cgst,
          'sgst': s.sgst,
          'igst': s.igst,
        }).toList(),
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonData);
      final dir = await getApplicationDocumentsDirectory();
      final filename = 'GSTR3B_${_selectedMonth.year}${_selectedMonth.month.toString().padLeft(2, '0')}.json';
      final file = File('${dir.path}/$filename');
      await file.writeAsString(jsonString);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('GSTR-3B saved: $filename'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }
}

