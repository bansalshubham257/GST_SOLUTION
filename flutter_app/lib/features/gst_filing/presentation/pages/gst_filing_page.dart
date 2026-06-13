// lib/features/gst_filing/presentation/pages/gst_filing_page.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/storage/local_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/indian_states.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../gst_reports/presentation/providers/gst_reports_provider.dart';
import '../providers/gst_filing_provider.dart';

class GstFilingPage extends ConsumerStatefulWidget {
  const GstFilingPage({super.key});

  @override
  ConsumerState<GstFilingPage> createState() => _GstFilingPageState();
}

class _GstFilingPageState extends ConsumerState<GstFilingPage> {
  DateTime _selectedMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final checklist = ref.watch(filingChecklistProvider(_selectedMonth));

    return Scaffold(
      appBar: AppBar(title: const Text('GST Filing Assistance')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoBanner(context),
            const SizedBox(height: 16),
            _buildMonthSelector(context),
            const SizedBox(height: 16),
            checklist.when(
              data: (data) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildValidationSummary(context, data),
                  const SizedBox(height: 16),
                  _buildChecklistCard(context, data),
                  const SizedBox(height: 16),
                  _buildExportSection(context, data),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const EmptyState(icon: Icons.error_outline, title: 'Error', subtitle: 'Could not load filing data'),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(10),
        border: const Border(left: BorderSide(color: AppColors.primary, width: 4)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.primary, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'GST filing preparation mode. Export data and upload manually to the GST portal at gstn.gov.in',
              style: TextStyle(fontSize: 13, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Filing Period', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Selected Month', style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
                      Text(
                        DateFormat('MMMM yyyy').format(_selectedMonth),
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              AppButton(
                label: 'Change',
                width: 100,
                height: 44,
                isOutlined: true,
                onPressed: () => _pickMonth(context),
                icon: Icons.calendar_today,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildValidationSummary(BuildContext context, FilingChecklist checklist) {
    final total = checklist.checks.length;
    final passed = checklist.checks.where((c) => c.isPassed).length;
    final failed = total - passed;
    final progress = total > 0 ? passed / total : 0.0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Validation Status', style: Theme.of(context).textTheme.titleMedium)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: failed == 0 ? AppColors.successLight : AppColors.warningLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  failed == 0 ? '✅ Ready to File' : '⚠️ $failed Issue${failed > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: failed == 0 ? AppColors.success : AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.borderLight,
              color: failed == 0 ? AppColors.success : AppColors.warning,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text('$passed/$total checks passed', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _statPill('Invoices', checklist.invoiceCount.toString(), AppColors.primary)),
              const SizedBox(width: 8),
              Expanded(child: _statPill('Valid', passed.toString(), AppColors.success)),
              const SizedBox(width: 8),
              Expanded(child: _statPill('Issues', failed.toString(), failed > 0 ? AppColors.warning : AppColors.success)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 16)),
          Text(label, style: TextStyle(color: color, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildChecklistCard(BuildContext context, FilingChecklist checklist) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Validation Checklist', style: Theme.of(context).textTheme.titleMedium),
          ),
          const Divider(height: 1),
          ...checklist.checks.map((check) => _buildCheckItem(context, check)),
        ],
      ),
    );
  }

  Widget _buildCheckItem(BuildContext context, FilingCheck check) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.borderLight, width: 0.5))),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: check.isPassed ? AppColors.successLight : (check.isError ? AppColors.dangerLight : AppColors.warningLight),
              shape: BoxShape.circle,
            ),
            child: Icon(
              check.isPassed ? Icons.check : (check.isError ? Icons.error_outline : Icons.warning_outlined),
              size: 16,
              color: check.isPassed ? AppColors.success : (check.isError ? AppColors.danger : AppColors.warning),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(check.title, style: Theme.of(context).textTheme.bodyMedium),
                if (check.message != null)
                  Text(check.message!, style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: check.isPassed ? AppColors.success : AppColors.warning,
                  )),
              ],
            ),
          ),
          if (!check.isPassed && check.count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.dangerLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('${check.count} found', style: const TextStyle(color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  Widget _buildExportSection(BuildContext context, FilingChecklist checklist) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Export for GST Portal', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _exportButton(
              context,
              'GSTR-1\nJSON',
              Icons.data_object_outlined,
              AppColors.primary,
              () => _exportGstr1Json(context),
            )),
            const SizedBox(width: 8),
            Expanded(child: _exportButton(
              context,
              'GSTR-3B\nJSON',
              Icons.summarize_outlined,
              AppColors.secondary,
              () => _exportGstr3bJson(context),
            )),
            const SizedBox(width: 8),
            Expanded(child: _exportButton(
              context,
              'Sales\nExcel',
              Icons.table_chart_outlined,
              AppColors.accent,
              () => _exportExcel(context),
            )),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.infoLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('How to file using exported JSON:', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.info, fontSize: 13)),
              SizedBox(height: 6),
              Text('1. Export GSTR-1 JSON from above\n2. Login to gstn.gov.in\n3. Go to Returns → GSTR-1 → Upload JSON\n4. Submit and file the return', style: TextStyle(color: AppColors.info, fontSize: 12, height: 1.6)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _exportButton(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
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

  String _stateNameToCode(String stateName) {
    if (stateName.isEmpty) return '';
    for (final s in indianStates) {
      if (s['name'] == stateName) return s['code'] ?? '';
    }
    return '';
  }

  String _gstinToStateCode(String gstin) {
    if (gstin.length >= 2) return gstin.substring(0, 2);
    return '';
  }

  String _businessStateCode() {
    final biz = LocalStorage.businessBox.get('state') as String?;
    if (biz != null && biz.isNotEmpty) return _stateNameToCode(biz);
    final bizGstin = LocalStorage.businessBox.get('gstin') as String?;
    if (bizGstin != null && bizGstin.isNotEmpty) return _gstinToStateCode(bizGstin);
    return '';
  }

  String _businessGstin() {
    return LocalStorage.businessBox.get('gstin') as String? ?? '';
  }

  Future<void> _exportGstr1Json(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generating GSTR-1 JSON...'), behavior: SnackBarBehavior.floating),
    );

    try {
      final invoices = LocalStorage.getAllCachedInvoices();
      final filtered = <Map<String, dynamic>>[];
      for (final raw in invoices) {
        final inv = Map<String, dynamic>.from(raw);
        final dateStr = inv['invoiceDate'] ?? '';
        final invDate = DateTime.tryParse(dateStr);
        if (invDate == null ||
            invDate.month != _selectedMonth.month ||
            invDate.year != _selectedMonth.year) {
          continue;
        }
        filtered.add(inv);
      }

      if (filtered.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No data to export'), backgroundColor: AppColors.warning),
          );
        }
        return;
      }

      final businessGstin = _businessGstin();
      final businessStateCode = _businessStateCode();

      final List<Map<String, dynamic>> b2bList = [];
      final List<Map<String, dynamic>> b2csList = [];
      final Map<String, Map<String, dynamic>> hsnMap = {};

      for (final inv in filtered) {
        final customerGstin = inv['customerGstin']?.toString() ?? '';
        final state = inv['state']?.toString() ?? '';
        final invoiceNumber = inv['invoiceNumber']?.toString() ?? '';
        final invoiceDateStr = inv['invoiceDate']?.toString() ?? '';
        final invoiceDate = DateTime.tryParse(invoiceDateStr) ?? DateTime.now();
        final grandTotal = (inv['grandTotal'] ?? 0).toDouble();
        final lineItems = (inv['lineItems'] as List? ?? []);

        // Determine place of supply
        String pos;
        if (customerGstin.isNotEmpty) {
          pos = _gstinToStateCode(customerGstin);
        } else if (state.isNotEmpty) {
          pos = _stateNameToCode(state);
        } else {
          pos = businessStateCode;
        }

        if (customerGstin.isNotEmpty) {
          // B2B invoice
          final List<Map<String, dynamic>> itms = [];
          int itemNum = 1;
          for (final item in lineItems) {
            final itemMap = Map<String, dynamic>.from(item);
            final txval = (itemMap['taxableAmount'] ?? 0).toDouble();
            final rt = (itemMap['gstRate'] ?? 0).toDouble();
            final camt = (itemMap['cgst'] ?? 0).toDouble();
            final samt = (itemMap['sgst'] ?? 0).toDouble();
            final iamt = (itemMap['igst'] ?? 0).toDouble();
            final hsnSc = itemMap['hsnCode']?.toString() ?? '';
            final qty = (itemMap['quantity'] ?? 1).toDouble();
            final unitPrice = (itemMap['unitPrice'] ?? 0).toDouble();

            itms.add({
              'num': itemNum++,
              'itm_det': {
                'txval': txval,
                'rt': rt,
                'iamt': iamt,
                'camt': camt,
                'samt': samt,
                'csamt': 0.0,
              },
            });

            // Aggregate to HSN summary
            if (hsnSc.isNotEmpty) {
              hsnMap.putIfAbsent(hsnSc, () => {
                'hsn_sc': hsnSc,
                'desc': itemMap['description']?.toString() ?? '',
                'uqc': itemMap['unit']?.toString() ?? 'NOS',
                'qty': 0.0,
                'val': 0.0,
                'txval': 0.0,
                'iamt': 0.0,
                'camt': 0.0,
                'samt': 0.0,
                'csamt': 0.0,
              });
              hsnMap[hsnSc]!['qty'] = (hsnMap[hsnSc]!['qty'] as double) + qty;
              hsnMap[hsnSc]!['val'] = (hsnMap[hsnSc]!['val'] as double) + (qty * unitPrice);
              hsnMap[hsnSc]!['txval'] = (hsnMap[hsnSc]!['txval'] as double) + txval;
              hsnMap[hsnSc]!['iamt'] = (hsnMap[hsnSc]!['iamt'] as double) + iamt;
              hsnMap[hsnSc]!['camt'] = (hsnMap[hsnSc]!['camt'] as double) + camt;
              hsnMap[hsnSc]!['samt'] = (hsnMap[hsnSc]!['samt'] as double) + samt;
            }
          }

          // Find or create B2B entry for this customer
          var b2bEntry = b2bList.where((b) => b['ctin'] == customerGstin).firstOrNull;
          if (b2bEntry == null) {
            b2bEntry = {
              'ctin': customerGstin,
              'inv': <Map<String, dynamic>>[],
            };
            b2bList.add(b2bEntry);
          }

          (b2bEntry['inv'] as List).add({
            'inum': invoiceNumber,
            'idt': DateFormat('dd-MM-yyyy').format(invoiceDate),
            'val': grandTotal,
            'pos': pos,
            'rchrg': 'N',
            'etinum': '',
            'itms': itms,
          });
        } else {
          // B2C invoice
          final double txval = lineItems.fold(0.0, (sum, item) => sum + ((item['taxableAmount'] ?? 0).toDouble()));
          final double camt = lineItems.fold(0.0, (sum, item) => sum + ((item['cgst'] ?? 0).toDouble()));
          final double samt = lineItems.fold(0.0, (sum, item) => sum + ((item['sgst'] ?? 0).toDouble()));
          final double iamt = lineItems.fold(0.0, (sum, item) => sum + ((item['igst'] ?? 0).toDouble()));

          b2csList.add({
            'sply_ty': pos == businessStateCode ? 'INTRA' : 'INTER',
            'pos': pos,
            'txval': txval,
            'iamt': iamt,
            'camt': camt,
            'samt': samt,
            'csamt': 0.0,
          });

          // Also aggregate HSN for B2C items
          for (final item in lineItems) {
            final itemMap = Map<String, dynamic>.from(item);
            final hsnSc = itemMap['hsnCode']?.toString() ?? '';
            final qty = (itemMap['quantity'] ?? 1).toDouble();
            final unitPrice = (itemMap['unitPrice'] ?? 0).toDouble();
            final itemTxval = (itemMap['taxableAmount'] ?? 0).toDouble();
            final itemCamt = (itemMap['cgst'] ?? 0).toDouble();
            final itemSamt = (itemMap['sgst'] ?? 0).toDouble();
            final itemIamt = (itemMap['igst'] ?? 0).toDouble();

            if (hsnSc.isNotEmpty) {
              hsnMap.putIfAbsent(hsnSc, () => {
                'hsn_sc': hsnSc,
                'desc': itemMap['description']?.toString() ?? '',
                'uqc': itemMap['unit']?.toString() ?? 'NOS',
                'qty': 0.0,
                'val': 0.0,
                'txval': 0.0,
                'iamt': 0.0,
                'camt': 0.0,
                'samt': 0.0,
                'csamt': 0.0,
              });
              hsnMap[hsnSc]!['qty'] = (hsnMap[hsnSc]!['qty'] as double) + qty;
              hsnMap[hsnSc]!['val'] = (hsnMap[hsnSc]!['val'] as double) + (qty * unitPrice);
              hsnMap[hsnSc]!['txval'] = (hsnMap[hsnSc]!['txval'] as double) + itemTxval;
              hsnMap[hsnSc]!['iamt'] = (hsnMap[hsnSc]!['iamt'] as double) + itemIamt;
              hsnMap[hsnSc]!['camt'] = (hsnMap[hsnSc]!['camt'] as double) + itemCamt;
              hsnMap[hsnSc]!['samt'] = (hsnMap[hsnSc]!['samt'] as double) + itemSamt;
            }
          }
        }
      }

      // Merge B2CS with same POS
      final Map<String, Map<String, dynamic>> mergedB2cs = {};
      for (final entry in b2csList) {
        final key = '${entry['sply_ty']}_${entry['pos']}';
        if (mergedB2cs.containsKey(key)) {
          mergedB2cs[key]!['txval'] = (mergedB2cs[key]!['txval'] as double) + (entry['txval'] as double);
          mergedB2cs[key]!['iamt'] = (mergedB2cs[key]!['iamt'] as double) + (entry['iamt'] as double);
          mergedB2cs[key]!['camt'] = (mergedB2cs[key]!['camt'] as double) + (entry['camt'] as double);
          mergedB2cs[key]!['samt'] = (mergedB2cs[key]!['samt'] as double) + (entry['samt'] as double);
        } else {
          mergedB2cs[key] = Map.from(entry);
        }
      }

      final jsonMap = <String, dynamic>{
        'gstin': businessGstin,
        'fp': '${_selectedMonth.month.toString().padLeft(2, '0')}${_selectedMonth.year.toString().substring(2)}',
        'version': 'GST1.0',
        if (b2bList.isNotEmpty) 'b2b': b2bList,
        if (mergedB2cs.isNotEmpty) 'b2cs': mergedB2cs.values.toList(),
        if (hsnMap.isNotEmpty) 'hsn': hsnMap.values.toList(),
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonMap);
      final filename = 'GSTR1_${_selectedMonth.year}${_selectedMonth.month.toString().padLeft(2, '0')}.json';
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
      await file.writeAsString(jsonString);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('GSTR-1 saved to Downloads'), backgroundColor: AppColors.success),
        );
      }
      try {
        await Share.shareXFiles([XFile(file.path)], text: 'GSTR-1 - ${DateFormat('MMMM yyyy').format(_selectedMonth)}');
      } catch (_) {}
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _exportGstr3bJson(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generating GSTR-3B JSON...'), behavior: SnackBarBehavior.floating),
    );

      var summary = ref.read(gstMonthlySummaryProvider(_selectedMonth)).valueOrNull;
      if (summary == null) {
        summary = computeGstSummaryFromCache(_selectedMonth);
      }
      if (summary.invoiceCount == 0) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No data to export'), backgroundColor: AppColors.warning),
          );
        }
        return;
      }

      try {
        final jsonMap = <String, dynamic>{
          'gstin': _businessGstin(),
          'fp': '${_selectedMonth.month.toString().padLeft(2, '0')}${_selectedMonth.year.toString().substring(2)}',
          'version': 'GST3.0',
          'sup_details': {
            'osup_det': {
              'txval': summary.totalTaxable,
              'iamt': summary.totalIgst,
              'camt': summary.totalCgst,
              'samt': summary.totalSgst,
              'csamt': 0,
            },
          },
        };

        final jsonString = const JsonEncoder.withIndent('  ').convert(jsonMap);
        final filename = 'GSTR3B_${_selectedMonth.year}${_selectedMonth.month.toString().padLeft(2, '0')}.json';
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
        await file.writeAsString(jsonString);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('GSTR-3B saved to Downloads'), backgroundColor: AppColors.success),
          );
        }
        try {
          await Share.shareXFiles([XFile(file.path)], text: 'GSTR-3B - ${DateFormat('MMMM yyyy').format(_selectedMonth)}');
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
      const SnackBar(content: Text('Preparing sales register...'), behavior: SnackBarBehavior.floating),
    );

      var summary = ref.read(gstMonthlySummaryProvider(_selectedMonth)).valueOrNull;
      if (summary == null) {
        summary = computeGstSummaryFromCache(_selectedMonth);
      }
      if (summary.invoiceCount == 0) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No data to export'), backgroundColor: AppColors.warning),
          );
        }
        return;
      }

      try {
        final bizGstin = _businessGstin();
      final buffer = StringBuffer();
      buffer.writeln('Sales Register,${DateFormat('MMMM yyyy').format(_selectedMonth)}');
      if (bizGstin.isNotEmpty) buffer.writeln('GSTIN,$bizGstin');
      buffer.writeln('');
      buffer.writeln('Metric,Value');
      buffer.writeln('Total Invoices,${summary.invoiceCount}');
      buffer.writeln('Total Taxable Value,${summary.totalTaxable}');
      buffer.writeln('CGST Collected,${summary.totalCgst}');
      buffer.writeln('SGST Collected,${summary.totalSgst}');
      buffer.writeln('IGST Collected,${summary.totalIgst}');
      buffer.writeln('Total GST,${summary.totalTax}');
      buffer.writeln('');
      buffer.writeln('Rate Wise Breakdown');
      buffer.writeln('GST Rate (%),Taxable Amount,CGST,SGST,IGST');
      for (final slab in summary.slabSummaries) {
        buffer.writeln('${slab.rate.toInt()},${slab.taxableAmount},${slab.cgst},${slab.sgst},${slab.igst}');
      }

      final filename = 'Sales_Register_${_selectedMonth.year}${_selectedMonth.month.toString().padLeft(2, '0')}.csv';
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
          SnackBar(content: Text('Sales register saved to Downloads'), backgroundColor: AppColors.success),
        );
      }
      try {
        await Share.shareXFiles([XFile(file.path)], text: 'Sales Register - ${DateFormat('MMMM yyyy').format(_selectedMonth)}');
      } catch (_) {}
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }
}
