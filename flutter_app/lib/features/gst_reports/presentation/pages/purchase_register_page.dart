import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_widgets.dart';

class PurchaseRegisterPage extends ConsumerStatefulWidget {
  const PurchaseRegisterPage({super.key});

  @override
  ConsumerState<PurchaseRegisterPage> createState() => _PurchaseRegisterPageState();
}

class _PurchaseRegisterPageState extends ConsumerState<PurchaseRegisterPage> {
  DateTime _selectedMonth = DateTime.now();
  int _currentPage = 0;
  final int _pageSize = AppConstants.defaultPageSize;

  List<Map<String, dynamic>> get _filteredPurchases {
    final all = LocalStorage.getAllCachedPurchases()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();

    final filtered = all.where((p) {
      final dateStr = p['invoiceDate'] ?? p['createdAt'] ?? '';
      final date = DateTime.tryParse(dateStr.toString());
      if (date == null) return false;
      return date.month == _selectedMonth.month && date.year == _selectedMonth.year;
    }).toList();

    filtered.sort((a, b) {
      final da = DateTime.tryParse(a['invoiceDate'] ?? a['createdAt'] ?? '') ?? DateTime(2000);
      final db = DateTime.tryParse(b['invoiceDate'] ?? b['createdAt'] ?? '') ?? DateTime(2000);
      return db.compareTo(da);
    });

    return filtered;
  }

  List<Map<String, dynamic>> get _paginatedPurchases {
    final all = _filteredPurchases;
    final start = _currentPage * _pageSize;
    if (start >= all.length) return [];
    final end = (start + _pageSize).clamp(0, all.length);
    return all.sublist(start, end);
  }

  int get _totalPages => (_filteredPurchases.length / _pageSize).ceil().clamp(1, 1);

  @override
  Widget build(BuildContext context) {
    final purchases = _filteredPurchases;
    final page = _paginatedPurchases;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Register'),
        actions: [
          if (purchases.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.file_download_outlined, size: 18),
              label: const Text('Export'),
              onPressed: () => _showExportOptions(context),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildMonthPicker(context),
          _buildSummaryCards(context, purchases),
          Expanded(
            child: page.isEmpty
                ? const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No purchases',
                    subtitle: 'No purchases found for selected month',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: page.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 12, endIndent: 12),
                    itemBuilder: (_, i) => _buildPurchaseCard(context, page[i]),
                  ),
          ),
          if (_totalPages > 1) _buildPagination(context, purchases.length),
        ],
      ),
    );
  }

  Widget _buildMonthPicker(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() {
              _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
              _currentPage = 0;
            }),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _pickMonth(context),
              child: Column(
                children: [
                  Text(
                    DateFormat('MMMM yyyy').format(_selectedMonth),
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    '${DateFormat('dd MMM').format(DateTime(_selectedMonth.year, _selectedMonth.month, 1))} - ${DateFormat('dd MMM yyyy').format(DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0))}',
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
                : () => setState(() {
                      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
                      _currentPage = 0;
                    }),
          ),
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
    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month);
        _currentPage = 0;
      });
    }
  }

  Widget _buildSummaryCards(BuildContext context, List<Map<String, dynamic>> purchases) {
    double totalTaxable = 0;
    double totalGst = 0;
    double totalAmount = 0;
    double totalCgst = 0;
    double totalSgst = 0;
    double totalIgst = 0;

    for (final p in purchases) {
      totalTaxable += (p['subTotal'] ?? 0).toDouble();
      totalGst += (p['totalTax'] ?? 0).toDouble();
      totalAmount += (p['grandTotal'] ?? 0).toDouble();
      totalCgst += (p['totalCgst'] ?? 0).toDouble();
      totalSgst += (p['totalSgst'] ?? 0).toDouble();
      totalIgst += (p['totalIgst'] ?? 0).toDouble();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: StatCard(
                title: 'Total Purchases',
                value: '₹${_fmt(totalAmount)}',
                icon: Icons.shopping_cart_outlined,
                iconColor: AppColors.primary,
                iconBgColor: AppColors.primarySurface,
              )),
              const SizedBox(width: 12),
              Expanded(child: StatCard(
                title: 'Total Taxable',
                value: '₹${_fmt(totalTaxable)}',
                icon: Icons.calculate_outlined,
                iconColor: AppColors.secondary,
                iconBgColor: AppColors.secondarySurface,
              )),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: StatCard(
                title: 'Total GST',
                value: '₹${_fmt(totalGst)}',
                icon: Icons.account_balance_outlined,
                iconColor: AppColors.accent,
                iconBgColor: AppColors.accentSurface,
              )),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariantLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Invoices', style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 4),
                      Text('${purchases.length}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _miniBadge('C', totalCgst, AppColors.cgstColor),
                          const SizedBox(width: 4),
                          _miniBadge('S', totalSgst, AppColors.sgstColor),
                          const SizedBox(width: 4),
                          _miniBadge('I', totalIgst, AppColors.igstColor),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _miniBadge(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text('$label ₹${_fmt(amount)}',
          style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildPurchaseCard(BuildContext context, Map<String, dynamic> purchase) {
    final dateStr = purchase['invoiceDate'] ?? purchase['createdAt'] ?? '';
    final date = DateTime.tryParse(dateStr.toString());
    final displayDate = date != null ? DateFormat('dd/MM/yy').format(date) : '--';
    final supplier = purchase['supplierName'] ?? 'Unknown Supplier';
    final invoiceNo = purchase['purchaseNumber'] ?? purchase['id'] ?? '--';
    final taxable = (purchase['subTotal'] ?? 0).toDouble();
    final gst = (purchase['totalTax'] ?? 0).toDouble();
    final grandTotal = (purchase['grandTotal'] ?? 0).toDouble();
    final paymentStatus = (purchase['paymentStatus'] ?? 'unpaid').toString();
    final gstin = purchase['supplierGstin']?.toString() ?? '';

    final lineItems = (purchase['lineItems'] as List? ?? []);
    final itemsSummary = lineItems
        .map((i) => Map<String, dynamic>.from(i))
        .map((i) => '${i['description'] ?? '?'} x${i['quantity'] ?? 1}')
        .join(', ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(invoiceNo.toString(),
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
              Text(displayDate,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
              const SizedBox(height: 4),
              Text(supplier.toString(),
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              if (gstin.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text('GSTIN: $gstin',
                    style: const TextStyle(fontSize: 11, color: AppColors.textTertiaryLight)),
              ],
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
                  const Spacer(),
                  Text('₹${_format(grandTotal)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimaryLight)),
                ],
              ),
              if (gst > 0) ...[
                const SizedBox(height: 4),
                _buildGstBreakdown(purchase),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGstBreakdown(Map<String, dynamic> purchase) {
    final cgst = (purchase['totalCgst'] ?? 0).toDouble();
    final sgst = (purchase['totalSgst'] ?? 0).toDouble();
    final igst = (purchase['totalIgst'] ?? 0).toDouble();

    return Row(
      children: [
        if (cgst > 0) ...[
          _gstChip('CGST ₹${_format(cgst)}', AppColors.cgstColor),
          const SizedBox(width: 4),
        ],
        if (sgst > 0) ...[
          _gstChip('SGST ₹${_format(sgst)}', AppColors.sgstColor),
          const SizedBox(width: 4),
        ],
        if (igst > 0) ...[
          _gstChip('IGST ₹${_format(igst)}', AppColors.igstColor),
        ],
      ],
    );
  }

  Widget _gstChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildPagination(BuildContext context, int totalItems) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.borderLight, width: 1)),
        color: Colors.white,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$totalItems entries', style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                onPressed: _currentPage > 0
                    ? () => setState(() => _currentPage--)
                    : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              Text('${_currentPage + 1} / $_totalPages',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                onPressed: _currentPage < _totalPages - 1
                    ? () => setState(() => _currentPage++)
                    : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Export ─────────────────────────────────────────────────────────────

  void _showExportOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Export Purchase Register', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.danger),
              title: const Text('Export as PDF'),
              subtitle: const Text('Summary PDF with all entries'),
              onTap: () { Navigator.pop(ctx); _exportPdf(context); },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined, color: AppColors.secondary),
              title: const Text('Export as Excel'),
              subtitle: const Text('CSV format with full details'),
              onTap: () { Navigator.pop(ctx); _exportExcel(context); },
            ),
            ListTile(
              leading: const Icon(Icons.data_object_outlined, color: AppColors.primary),
              title: const Text('Export as JSON'),
              subtitle: const Text('Structured data for GSTR-2 like format'),
              onTap: () { Navigator.pop(ctx); _exportJson(context); },
            ),
          ],
        ),
      ),
    );
  }

  void _exportPdf(BuildContext context) async {
    final purchases = _filteredPurchases;
    if (purchases.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No data to export'), backgroundColor: AppColors.warning));
      }
      return;
    }

    try {
      final buffer = StringBuffer();
      buffer.writeln('Purchase Register Report');
      buffer.writeln('Period: ${DateFormat('MMMM yyyy').format(_selectedMonth)}');
      buffer.writeln('Generated: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}');
      buffer.writeln('');
      buffer.writeln('Summary');
      double totalTaxable = 0, totalGst = 0, totalAmount = 0;
      for (final p in purchases) {
        totalTaxable += (p['subTotal'] ?? 0).toDouble();
        totalGst += (p['totalTax'] ?? 0).toDouble();
        totalAmount += (p['grandTotal'] ?? 0).toDouble();
      }
      buffer.writeln('Total Purchases,$totalAmount');
      buffer.writeln('Total Taxable,$totalTaxable');
      buffer.writeln('Total GST,$totalGst');
      buffer.writeln('Invoice Count,${purchases.length}');
      buffer.writeln('');
      buffer.writeln('Purchase Details');
      buffer.writeln('Invoice No,Supplier Name,Date,Taxable,GST,Grand Total,Payment Status');
      for (final p in purchases) {
        final invNo = p['purchaseNumber'] ?? p['id'] ?? '';
        final supplier = p['supplierName'] ?? '';
        final date = p['invoiceDate'] ?? '';
        final tax = (p['subTotal'] ?? 0).toDouble();
        final gst = (p['totalTax'] ?? 0).toDouble();
        final total = (p['grandTotal'] ?? 0).toDouble();
        final status = (p['paymentStatus'] ?? 'unpaid').toString();
        buffer.writeln('$invNo,$supplier,$date,$tax,$gst,$total,$status');
      }

      final filename = 'Purchase_Register_${_selectedMonth.year}${_selectedMonth.month.toString().padLeft(2, '0')}.csv';
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
          const SnackBar(content: Text('Purchase register saved'), backgroundColor: AppColors.success),
        );
      }
      try {
        await Share.shareXFiles([XFile(file.path)], text: 'Purchase Register - ${DateFormat('MMMM yyyy').format(_selectedMonth)}');
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
    final purchases = _filteredPurchases;
    if (purchases.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No data to export'), backgroundColor: AppColors.warning));
      }
      return;
    }

    try {
      final buffer = StringBuffer();
      buffer.writeln('Purchase Register,${DateFormat('MMMM yyyy').format(_selectedMonth)}');
      buffer.writeln('');
      double totalTaxable = 0, totalCgst = 0, totalSgst = 0, totalIgst = 0, totalGst = 0, totalAmount = 0;
      for (final p in purchases) {
        totalTaxable += (p['subTotal'] ?? 0).toDouble();
        totalCgst += (p['totalCgst'] ?? 0).toDouble();
        totalSgst += (p['totalSgst'] ?? 0).toDouble();
        totalIgst += (p['totalIgst'] ?? 0).toDouble();
        totalGst += (p['totalTax'] ?? 0).toDouble();
        totalAmount += (p['grandTotal'] ?? 0).toDouble();
      }
      buffer.writeln('Metric,Value');
      buffer.writeln('Total Purchases,$totalAmount');
      buffer.writeln('Total Taxable,$totalTaxable');
      buffer.writeln('Total CGST,$totalCgst');
      buffer.writeln('Total SGST,$totalSgst');
      buffer.writeln('Total IGST,$totalIgst');
      buffer.writeln('Total GST,$totalGst');
      buffer.writeln('Invoice Count,${purchases.length}');
      buffer.writeln('');
      buffer.writeln('Invoice No,Supplier Name,Supplier GSTIN,Date,Taxable,CGST,SGST,IGST,GST,Grand Total,Payment Status');
      for (final p in purchases) {
        buffer.writeln(
          '${p['purchaseNumber'] ?? p['id'] ?? ''},'
          '${p['supplierName'] ?? ''},'
          '${p['supplierGstin'] ?? ''},'
          '${p['invoiceDate'] ?? ''},'
          '${(p['subTotal'] ?? 0).toDouble()},'
          '${(p['totalCgst'] ?? 0).toDouble()},'
          '${(p['totalSgst'] ?? 0).toDouble()},'
          '${(p['totalIgst'] ?? 0).toDouble()},'
          '${(p['totalTax'] ?? 0).toDouble()},'
          '${(p['grandTotal'] ?? 0).toDouble()},'
          '${p['paymentStatus'] ?? 'unpaid'}'
        );
      }

      final filename = 'Purchase_Excel_${_selectedMonth.year}${_selectedMonth.month.toString().padLeft(2, '0')}.csv';
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
          const SnackBar(content: Text('Purchase Excel saved'), backgroundColor: AppColors.success),
        );
      }
      try {
        await Share.shareXFiles([XFile(file.path)], text: 'Purchase Excel - ${DateFormat('MMMM yyyy').format(_selectedMonth)}');
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
    final purchases = _filteredPurchases;
    if (purchases.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No data to export'), backgroundColor: AppColors.warning));
      return;
    }

    try {
      double totalTaxable = 0, totalCgst = 0, totalSgst = 0, totalIgst = 0, totalTax = 0;

      final slabMap = <int, Map<String, dynamic>>{};
      final purchaseList = purchases.map((p) {
        totalTaxable += (p['subTotal'] ?? 0).toDouble();
        totalCgst += (p['totalCgst'] ?? 0).toDouble();
        totalSgst += (p['totalSgst'] ?? 0).toDouble();
        totalIgst += (p['totalIgst'] ?? 0).toDouble();
        totalTax += (p['totalTax'] ?? 0).toDouble();

        final slabs = (p['gstSlabs'] as List? ?? []);
        for (final s in slabs) {
          final slab = Map<String, dynamic>.from(s);
          final rate = (slab['rate'] ?? 0).toInt();
          final existing = slabMap[rate] ?? {'rate': rate, 'taxableAmount': 0.0, 'cgst': 0.0, 'sgst': 0.0, 'igst': 0.0};
          existing['taxableAmount'] = (existing['taxableAmount'] as double) + (slab['taxableAmount'] ?? 0).toDouble();
          existing['cgst'] = (existing['cgst'] as double) + (slab['cgst'] ?? 0).toDouble();
          existing['sgst'] = (existing['sgst'] as double) + (slab['sgst'] ?? 0).toDouble();
          existing['igst'] = (existing['igst'] as double) + (slab['igst'] ?? 0).toDouble();
          slabMap[rate] = existing;
        }

        return {
          'supplierName': p['supplierName'] ?? '',
          'supplierGstin': p['supplierGstin'] ?? '',
          'invoiceNumber': p['purchaseNumber'] ?? p['id'] ?? '',
          'invoiceDate': p['invoiceDate'] ?? '',
          'subTotal': (p['subTotal'] ?? 0).toDouble(),
          'totalCgst': (p['totalCgst'] ?? 0).toDouble(),
          'totalSgst': (p['totalSgst'] ?? 0).toDouble(),
          'totalIgst': (p['totalIgst'] ?? 0).toDouble(),
          'totalTax': (p['totalTax'] ?? 0).toDouble(),
          'grandTotal': (p['grandTotal'] ?? 0).toDouble(),
          'paymentStatus': p['paymentStatus'] ?? 'unpaid',
        };
      }).toList();

      final jsonData = {
        'period': DateFormat('yyyy-MM').format(_selectedMonth),
        'type': 'PURCHASE_REGISTER',
        'summary': {
          'totalPurchases': purchaseList.length,
          'totalTaxable': totalTaxable,
          'totalCgst': totalCgst,
          'totalSgst': totalSgst,
          'totalIgst': totalIgst,
          'totalTax': totalTax,
        },
        'gstSlabs': slabMap.values.toList(),
        'purchases': purchaseList,
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonData);
      final dir = await getApplicationDocumentsDirectory();
      final filename = 'Purchase_Register_${_selectedMonth.year}${_selectedMonth.month.toString().padLeft(2, '0')}.json';
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

  String _fmt(double amount) {
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(2);
  }

  String _format(double v) => v.toStringAsFixed(2);
}
