import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../providers/purchase_provider.dart';

enum PurchaseDatePeriod { today, week, month, quarter, year, all }

class PurchaseListPage extends ConsumerStatefulWidget {
  const PurchaseListPage({super.key});

  @override
  ConsumerState<PurchaseListPage> createState() => _PurchaseListPageState();
}

class _PurchaseListPageState extends ConsumerState<PurchaseListPage> {
  final _searchController = TextEditingController();
  PurchaseDatePeriod _selectedPeriod = PurchaseDatePeriod.month;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filterPurchases(List<Map<String, dynamic>> all) {
    final now = DateTime.now();
    final query = _searchController.text.trim().toLowerCase();

    return all.where((p) {
      final dateStr = p['invoiceDate'] ?? '';
      final invDate = DateTime.tryParse(dateStr);
      if (invDate == null) return false;

      switch (_selectedPeriod) {
        case PurchaseDatePeriod.today:
          if (!_isSameDay(invDate, now)) return false;
        case PurchaseDatePeriod.week:
          final weekStart = now.subtract(Duration(days: now.weekday - 1));
          if (invDate.isBefore(weekStart) || invDate.isAfter(now)) return false;
        case PurchaseDatePeriod.month:
          if (invDate.month != now.month || invDate.year != now.year) return false;
        case PurchaseDatePeriod.quarter:
          final qStartMonth = ((now.month - 1) ~/ 3) * 3 + 1;
          final qStart = DateTime(now.year, qStartMonth);
          final qEnd = DateTime(now.year, qStartMonth + 3);
          if (invDate.isBefore(qStart) || invDate.isAfter(qEnd.subtract(const Duration(days: 1)))) return false;
        case PurchaseDatePeriod.year:
          if (invDate.year != now.year) return false;
        case PurchaseDatePeriod.all:
          break;
      }

      if (query.isNotEmpty) {
        final supplierName = (p['supplierName'] ?? '').toString().toLowerCase();
        final purchaseNum = (p['purchaseNumber'] ?? '').toString().toLowerCase();
        if (!supplierName.contains(query) && !purchaseNum.contains(query)) return false;
      }

      return true;
    }).toList();
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _fmt(double amount) {
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(0);
  }

  Future<void> _exportFiltered(List<Map<String, dynamic>> filtered) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preparing export...'), behavior: SnackBarBehavior.floating),
    );

    try {
      final buffer = StringBuffer();
      buffer.writeln('Purchase#,Date,Supplier,Items,Subtotal,Tax,Grand Total');

      for (final p in filtered) {
        final items = (p['lineItems'] as List? ?? []);
        final itemNames = items.map((i) => i['description'] ?? '').join('; ');
        final line = [
          p['purchaseNumber'] ?? '',
          p['invoiceDate']?.toString().substring(0, 10) ?? '',
          p['supplierName'] ?? '',
          itemNames,
          (p['subTotal'] ?? 0).toStringAsFixed(2),
          (p['totalTax'] ?? 0).toStringAsFixed(2),
          (p['grandTotal'] ?? 0).toStringAsFixed(2),
        ].join(',');
        buffer.writeln(line);
      }

      final filename = 'Purchase_History_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
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
          const SnackBar(content: Text('Purchase report saved to Downloads'), backgroundColor: AppColors.success),
        );
      }
      try {
        await Share.shareXFiles([XFile(file.path)], text: 'Purchase History');
      } catch (_) {}
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allPurchases = LocalStorage.getAllCachedPurchases()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final filtered = _filterPurchases(allPurchases);
    final totalAmount = filtered.fold(0.0, (s, i) => s + (i['grandTotal'] ?? 0).toDouble());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase History'),
        actions: [
          if (filtered.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: 'Export filtered purchases',
              onPressed: () => _exportFiltered(filtered),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: PurchaseDatePeriod.values.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final period = PurchaseDatePeriod.values[i];
                  final label = switch (period) {
                    PurchaseDatePeriod.today => 'Today',
                    PurchaseDatePeriod.week => 'Week',
                    PurchaseDatePeriod.month => 'Month',
                    PurchaseDatePeriod.quarter => 'Quarter',
                    PurchaseDatePeriod.year => 'Year',
                    PurchaseDatePeriod.all => 'All',
                  };
                  return FilterChip(
                    label: Text(label, style: const TextStyle(fontSize: 13)),
                    selected: _selectedPeriod == period,
                    onSelected: (_) => setState(() => _selectedPeriod = period),
                    selectedColor: AppColors.primarySurface,
                    checkmarkColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: _selectedPeriod == period ? AppColors.primary : AppColors.textSecondaryLight,
                      fontWeight: _selectedPeriod == period ? FontWeight.w600 : FontWeight.w400,
                    ),
                    side: BorderSide(
                      color: _selectedPeriod == period ? AppColors.primary : AppColors.borderLight,
                    ),
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: AppTextField(
              hint: 'Search by supplier or purchase no...',
              controller: _searchController,
              prefix: const Icon(Icons.search, size: 20),
              suffix: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (filtered.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text('${filtered.length} purchases',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight)),
                  const Spacer(),
                  Text('Total: ₹${totalAmount.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.success)),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Expanded(
            child: filtered.isEmpty
                ? const EmptyState(
                    icon: Icons.shopping_cart_outlined,
                    title: 'No purchases found',
                    subtitle: 'Try a different period or create a new purchase',
                  )
                : RefreshIndicator(
                    onRefresh: () async => setState(() {}),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _buildPurchaseCard(filtered[i]),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/purchases/create'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildPurchaseCard(Map<String, dynamic> p) {
    final dateStr = p['invoiceDate'] ?? '';
    final invDate = DateTime.tryParse(dateStr);
    final lineItems = (p['lineItems'] as List? ?? []);
    final itemDesc = lineItems.take(2).map((i) => i['description'] ?? '').join(', ');
    final more = lineItems.length > 2 ? ' +${lineItems.length - 2} more' : '';

    return AppCard(
      onTap: () {
        final id = p['id'] ?? '';
        if (id.isEmpty) return;
        try {
          final converted = Map<String, dynamic>.from(p);
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
          final entity = PurchaseEntityJson.fromJson(converted);
          context.push('/purchases/$id', extra: entity);
        } catch (e) {
          debugPrint('[PurchaseList] Parse failed for $id: $e');
        }
      },
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.shopping_cart_outlined, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        p['supplierName'] ?? 'Unknown Supplier',
                        style: Theme.of(context).textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '₹${_fmt((p['grandTotal'] ?? 0).toDouble())}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(p['purchaseNumber'] ?? '', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(width: 8),
                    if (invDate != null)
                      Text(DateFormat('dd MMM yy').format(invDate), style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                if (itemDesc.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '$itemDesc$more',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
