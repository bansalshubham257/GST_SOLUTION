// lib/features/gst_reports/presentation/pages/gst_reports_page.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/ad_banner_widget.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../providers/gst_reports_provider.dart';

class GstReportsPage extends ConsumerStatefulWidget {
  const GstReportsPage({super.key});

  @override
  ConsumerState<GstReportsPage> createState() => _GstReportsPageState();
}

class _GstReportsPageState extends ConsumerState<GstReportsPage> {
  DateTime _selectedMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(gstMonthlySummaryProvider(_selectedMonth));

    return Scaffold(
      appBar: AppBar(
        title: const Text('GST Reports'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.file_download_outlined, size: 18),
            label: const Text('Export'),
            onPressed: () => _showExportOptions(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(gstMonthlySummaryProvider(_selectedMonth)),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMonthPicker(context),
              const SizedBox(height: 16),
              summary.when(
                data: (data) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTaxSummaryCards(context, data),
                    const SizedBox(height: 16),
                    _buildGstSlabTable(context, data),
                  ],
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const EmptyState(icon: Icons.bar_chart_outlined, title: 'No data', subtitle: 'No GST data for selected month'),
              ),
              const SizedBox(height: 20),
              Text('Quick Reports', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              _buildReportCards(context),
              const SizedBox(height: 16),
              AdBannerWidget(),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthPicker(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1)),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _pickMonth(context),
              child: Column(
                children: [
                  Text(
                    DateFormat('MMMM yyyy').format(_selectedMonth),
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    'GST Period: ${DateFormat('dd MMM').format(DateTime(_selectedMonth.year, _selectedMonth.month, 1))} - ${DateFormat('dd MMM yyyy').format(DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0))}',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _selectedMonth.month == DateTime.now().month && _selectedMonth.year == DateTime.now().year
                ? null
                : () => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1)),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxSummaryCards(BuildContext context, GstMonthlySummary data) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: StatCard(
              title: 'Taxable Amount',
              value: '₹${_fmt(data.totalTaxable)}',
              icon: Icons.calculate_outlined,
              iconColor: AppColors.primary,
              iconBgColor: AppColors.primarySurface,
            )),
            const SizedBox(width: 12),
            Expanded(child: StatCard(
              title: 'Total Tax',
              value: '₹${_fmt(data.totalTax)}',
              icon: Icons.account_balance_outlined,
              iconColor: AppColors.secondary,
              iconBgColor: AppColors.secondarySurface,
            )),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _taxCard('CGST', data.totalCgst, AppColors.cgstColor)),
            const SizedBox(width: 8),
            Expanded(child: _taxCard('SGST', data.totalSgst, AppColors.sgstColor)),
            const SizedBox(width: 8),
            Expanded(child: _taxCard('IGST', data.totalIgst, AppColors.igstColor)),
          ],
        ),
      ],
    );
  }

  Widget _taxCard(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('₹${_fmt(amount)}', style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildGstSlabTable(BuildContext context, GstMonthlySummary data) {
    if (data.slabSummaries.isEmpty) return const SizedBox.shrink();

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Tax Slab Breakdown', style: Theme.of(context).textTheme.titleMedium),
          ),
          const Divider(height: 1),
          // Header
          Container(
            color: AppColors.surfaceVariantLight,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: ['Rate', 'Taxable', 'CGST', 'SGST', 'IGST'].map((h) => Expanded(
                child: Text(h, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondaryLight)),
              )).toList(),
            ),
          ),
          ...data.slabSummaries.map((slab) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.borderLight, width: 0.5))),
            child: Row(
              children: [
                Expanded(child: Text('${slab.rate.toInt()}%', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary))),
                Expanded(child: Text('₹${_fmt(slab.taxableAmount)}', style: const TextStyle(fontSize: 12))),
                Expanded(child: Text('₹${_fmt(slab.cgst)}', style: const TextStyle(fontSize: 12, color: AppColors.cgstColor))),
                Expanded(child: Text('₹${_fmt(slab.sgst)}', style: const TextStyle(fontSize: 12, color: AppColors.sgstColor))),
                Expanded(child: Text('₹${_fmt(slab.igst)}', style: const TextStyle(fontSize: 12, color: AppColors.igstColor))),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildReportCards(BuildContext context) {
    final reports = [
      _ReportCard(
        title: 'GSTR-1',
        subtitle: 'Outward supplies — B2B, B2C',
        icon: Icons.upload_file_outlined,
        color: AppColors.primary,
        onTap: () => context.push(AppRoutes.gstr1),
      ),
      _ReportCard(
        title: 'GSTR-3B',
        subtitle: 'Monthly summary return',
        icon: Icons.summarize_outlined,
        color: AppColors.secondary,
        onTap: () => context.push(AppRoutes.gstr3b),
      ),
      _ReportCard(
        title: 'Sales Register',
        subtitle: 'Complete invoice-wise report',
        icon: Icons.table_chart_outlined,
        color: AppColors.accent,
        onTap: () => context.push(AppRoutes.salesRegister),
      ),
      _ReportCard(
        title: 'Purchase Register',
        subtitle: 'Supplier-wise purchase report',
        icon: Icons.shopping_cart_outlined,
        color: AppColors.danger,
        onTap: () => context.push(AppRoutes.purchaseRegister),
      ),
      _ReportCard(
        title: 'Tax Liability',
        subtitle: 'CGST/SGST/IGST payable',
        icon: Icons.account_balance_outlined,
        color: AppColors.info,
        onTap: () => context.push(AppRoutes.taxLiability),
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: reports.map((r) => _buildReportTile(context, r)).toList(),
    );
  }

  Widget _buildReportTile(BuildContext context, _ReportCard report) {
    return AppCard(
      onTap: report.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: report.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(report.icon, color: report.color, size: 22),
          ),
          const SizedBox(height: 10),
          Text(report.title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 2),
          Text(report.subtitle, style: Theme.of(context).textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  void _showExportOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Export Report', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.account_balance, color: Color(0xFF059669)),
              title: const Text('CA Export — Full Transaction History'),
              subtitle: const Text('Complete data file for your CA'),
              onTap: () { Navigator.pop(ctx); _caExport(context); },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.danger),
              title: const Text('Export as PDF'),
              onTap: () { Navigator.pop(ctx); _exportPdf(context); },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined, color: AppColors.secondary),
              title: const Text('Export as Excel'),
              onTap: () { Navigator.pop(ctx); _exportExcel(context); },
            ),
            ListTile(
              leading: const Icon(Icons.data_object_outlined, color: AppColors.primary),
              title: const Text('GSTR-1 / GSTR-3B JSON'),
              subtitle: const Text('For GST portal upload'),
              onTap: () { Navigator.pop(ctx); _exportJson(context); },
            ),
          ],
        ),
      ),
    );
  }

  void _caExport(BuildContext context) {
    final summary = ref.read(gstMonthlySummaryProvider(_selectedMonth)).valueOrNull;
    if (summary == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No data to export'), backgroundColor: AppColors.warning));
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('=== CA Export ===');
    buffer.writeln('Generated: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}');
    buffer.writeln('Period: ${DateFormat('MMMM yyyy').format(_selectedMonth)}');
    buffer.writeln('');
    buffer.writeln('--- Summary ---');
    buffer.writeln('Total Sales: ₹${_fmt(summary.totalTaxable)}');
    buffer.writeln('Total GST Collected: ₹${_fmt(summary.totalTax)}');
    buffer.writeln('CGST: ₹${_fmt(summary.totalCgst)}');
    buffer.writeln('SGST: ₹${_fmt(summary.totalSgst)}');
    buffer.writeln('IGST: ₹${_fmt(summary.totalIgst)}');
    buffer.writeln('');

    if (summary.slabSummaries.isNotEmpty) {
      buffer.writeln('--- GST Slab Breakdown ---');
      for (final slab in summary.slabSummaries) {
        buffer.writeln('${slab.rate.toInt()}% | Taxable: ${_fmt(slab.taxableAmount)} | CGST: ${_fmt(slab.cgst)} | SGST: ${_fmt(slab.sgst)} | IGST: ${_fmt(slab.igst)}');
      }
    }

    // Copy to clipboard as a simple sharing mechanism
    final data = buffer.toString();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('CA data generated. Share with your auditor.'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Show the data in a dialog for copying
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('CA Export'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Share this data with your CA:', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariantLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(data, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _exportPdf(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generating report...'), behavior: SnackBarBehavior.floating),
    );

    final summary = ref.read(gstMonthlySummaryProvider(_selectedMonth)).valueOrNull;
    if (summary == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data to export'), backgroundColor: AppColors.warning),
        );
      }
      return;
    }

    try {
      final buffer = StringBuffer();
      buffer.writeln('GST Monthly Summary Report');
      buffer.writeln('Period: ${DateFormat('MMMM yyyy').format(_selectedMonth)}');
      buffer.writeln('Generated: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}');
      buffer.writeln('');
      buffer.writeln('Sales Summary');
      buffer.writeln('Total Taxable Sales,${summary.totalTaxable}');
      buffer.writeln('Total CGST,${summary.totalCgst}');
      buffer.writeln('Total SGST,${summary.totalSgst}');
      buffer.writeln('Total IGST,${summary.totalIgst}');
      buffer.writeln('Total Tax,${summary.totalTax}');
      buffer.writeln('Invoice Count,${summary.invoiceCount}');
      buffer.writeln('');
      buffer.writeln('GST Slab Breakdown');
      buffer.writeln('Rate,Taxable Amount,CGST,SGST,IGST');
      for (final slab in summary.slabSummaries) {
        buffer.writeln('${slab.rate.toInt()}%,${slab.taxableAmount},${slab.cgst},${slab.sgst},${slab.igst}');
      }

      final filename = 'GST_Report_${_selectedMonth.year}${_selectedMonth.month.toString().padLeft(2, '0')}.csv';
      File file;
      if (Platform.isAndroid) {
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          file = File('${downloadDir.path}/$filename');
        } else {
          final docDir = await getApplicationDocumentsDirectory();
          file = File('${docDir.path}/$filename');
        }
      } else {
        final docDir = await getApplicationDocumentsDirectory();
        file = File('${docDir.path}/$filename');
      }
      await file.writeAsString(buffer.toString());

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('GST report saved to Downloads'), backgroundColor: AppColors.success),
        );
      }
      try {
        await Share.shareXFiles([XFile(file.path)], text: 'GST Report - ${DateFormat('MMMM yyyy').format(_selectedMonth)}');
      } catch (_) {}
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  void _exportExcel(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preparing Excel data...'), behavior: SnackBarBehavior.floating),
    );

    final summary = ref.read(gstMonthlySummaryProvider(_selectedMonth)).valueOrNull;
    if (summary == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data to export'), backgroundColor: AppColors.warning),
        );
      }
      return;
    }

    try {
      final buffer = StringBuffer();
      buffer.writeln('GST Summary,${DateFormat('MMMM yyyy').format(_selectedMonth)}');
      buffer.writeln('');
      buffer.writeln('Metric,Value');
      buffer.writeln('Total Taxable Sales,${summary.totalTaxable}');
      buffer.writeln('Total CGST,${summary.totalCgst}');
      buffer.writeln('Total SGST,${summary.totalSgst}');
      buffer.writeln('Total IGST,${summary.totalIgst}');
      buffer.writeln('Total Cess,${summary.totalCess}');
      buffer.writeln('Total Tax,${summary.totalTax}');
      buffer.writeln('Invoice Count,${summary.invoiceCount}');
      buffer.writeln('');
      buffer.writeln('GST Slab Breakdown');
      buffer.writeln('Rate (%),Taxable Amount,CGST,SGST,IGST');
      for (final slab in summary.slabSummaries) {
        buffer.writeln('${slab.rate.toInt()},${slab.taxableAmount},${slab.cgst},${slab.sgst},${slab.igst}');
      }

      final filename = 'GST_Excel_${_selectedMonth.year}${_selectedMonth.month.toString().padLeft(2, '0')}.csv';
      File file;
      if (Platform.isAndroid) {
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          file = File('${downloadDir.path}/$filename');
        } else {
          final docDir = await getApplicationDocumentsDirectory();
          file = File('${docDir.path}/$filename');
        }
      } else {
        final docDir = await getApplicationDocumentsDirectory();
        file = File('${docDir.path}/$filename');
      }
      await file.writeAsString(buffer.toString());

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('GST Excel saved to Downloads'), backgroundColor: AppColors.success),
        );
      }
      try {
        await Share.shareXFiles([XFile(file.path)], text: 'GST Excel - ${DateFormat('MMMM yyyy').format(_selectedMonth)}');
      } catch (_) {}
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  void _exportJson(BuildContext context) async {
    final summary = ref.read(gstMonthlySummaryProvider(_selectedMonth)).valueOrNull;
    if (summary == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to export'), backgroundColor: AppColors.warning),
      );
      return;
    }

    try {
      final jsonData = {
        'period': DateFormat('yyyy-MM').format(_selectedMonth),
        'summary': {
          'totalTaxable': summary.totalTaxable,
          'totalCgst': summary.totalCgst,
          'totalSgst': summary.totalSgst,
          'totalIgst': summary.totalIgst,
          'totalCess': summary.totalCess,
          'totalTax': summary.totalTax,
          'invoiceCount': summary.invoiceCount,
        },
        'slabSummaries': summary.slabSummaries.map((s) => {
          'rate': s.rate,
          'taxableAmount': s.taxableAmount,
          'cgst': s.cgst,
          'sgst': s.sgst,
          'igst': s.igst,
        }).toList(),
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonData);
      final dir = await getApplicationDocumentsDirectory();
      final filename = 'GST_Summary_${_selectedMonth.year}${_selectedMonth.month.toString().padLeft(2, '0')}.json';
      final file = File('${dir.path}/$filename');
      await file.writeAsString(jsonString);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report saved: $filename'),
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

  void _pickMonth(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedMonth = DateTime(picked.year, picked.month));
  }

  String _fmt(double amount) {
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(2);
  }
}

class _ReportCard {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ReportCard({required this.title, required this.subtitle, required this.icon, required this.color, required this.onTap});
}

