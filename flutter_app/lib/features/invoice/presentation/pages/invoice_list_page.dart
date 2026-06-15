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
import '../../domain/entities/invoice_entity.dart';
import '../providers/invoice_provider.dart';

enum DatePeriod { today, week, month, quarter, year, all }

class InvoiceListPage extends ConsumerStatefulWidget {
  const InvoiceListPage({super.key});

  @override
  ConsumerState<InvoiceListPage> createState() => _InvoiceListPageState();
}

class _InvoiceListPageState extends ConsumerState<InvoiceListPage> {
  final _searchController = TextEditingController();
  DatePeriod _selectedPeriod = DatePeriod.month;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filterInvoices(List<Map<String, dynamic>> all) {
    final now = DateTime.now();
    final query = _searchController.text.trim().toLowerCase();

    return all.where((inv) {
      final dateStr = inv['invoiceDate'] ?? '';
      final invDate = DateTime.tryParse(dateStr);
      if (invDate == null) return false;

      // Date period filter
      switch (_selectedPeriod) {
        case DatePeriod.today:
          if (!_isSameDay(invDate, now)) return false;
        case DatePeriod.week:
          final weekStart = now.subtract(Duration(days: now.weekday - 1));
          if (invDate.isBefore(weekStart) || invDate.isAfter(now)) return false;
        case DatePeriod.month:
          if (invDate.month != now.month || invDate.year != now.year) return false;
        case DatePeriod.quarter:
          final qStartMonth = ((now.month - 1) ~/ 3) * 3 + 1;
          final qStart = DateTime(now.year, qStartMonth);
          final qEnd = DateTime(now.year, qStartMonth + 3);
          if (invDate.isBefore(qStart) || invDate.isAfter(qEnd.subtract(const Duration(days: 1)))) return false;
        case DatePeriod.year:
          if (invDate.year != now.year) return false;
        case DatePeriod.all:
          break;
      }

      // Search filter
      if (query.isNotEmpty) {
        final customerName = (inv['customerName'] ?? '').toString().toLowerCase();
        final invoiceNum = (inv['invoiceNumber'] ?? '').toString().toLowerCase();
        if (!customerName.contains(query) && !invoiceNum.contains(query)) return false;
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
      buffer.writeln('Invoice#,Date,Customer,Payment Mode,Items,Subtotal,Tax,Grand Total');

      for (final inv in filtered) {
        final items = (inv['lineItems'] as List? ?? []);
        final itemNames = items.map((i) => i['description'] ?? '').join('; ');
        final line = [
          inv['invoiceNumber'] ?? '',
          inv['invoiceDate']?.toString().substring(0, 10) ?? '',
          inv['customerName'] ?? '',
          inv['paymentMode'] ?? '',
          itemNames,
          (inv['subTotal'] ?? 0).toStringAsFixed(2),
          (inv['totalTax'] ?? 0).toStringAsFixed(2),
          (inv['grandTotal'] ?? 0).toStringAsFixed(2),
        ].join(',');
        buffer.writeln(line);
      }

      final filename = 'Sales_History_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
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
          const SnackBar(content: Text('Sales report saved to Downloads'), backgroundColor: AppColors.success),
        );
      }
      try {
        await Share.shareXFiles([XFile(file.path)], text: 'Sales History');
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
    final allInvoices = LocalStorage.getAllCachedInvoices()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final filtered = _filterInvoices(allInvoices);
    final totalAmount = filtered.fold(0.0, (s, i) => s + (i['grandTotal'] ?? 0).toDouble());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
        actions: [
          if (filtered.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: 'Export filtered sales',
              onPressed: () => _exportFiltered(filtered),
            ),
        ],
      ),
      body: Column(
        children: [
          // Period chips
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: DatePeriod.values.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final period = DatePeriod.values[i];
                  final label = switch (period) {
                    DatePeriod.today => 'Today',
                    DatePeriod.week => 'Week',
                    DatePeriod.month => 'Month',
                    DatePeriod.quarter => 'Quarter',
                    DatePeriod.year => 'Year',
                    DatePeriod.all => 'All',
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
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: AppTextField(
              hint: 'Search by customer or invoice no...',
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
          // Summary bar
          if (filtered.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text('${filtered.length} transactions',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight)),
                  const Spacer(),
                  Text('Total: ₹${totalAmount.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.success)),
                ],
              ),
            ),
          const SizedBox(height: 4),
          // Invoice list
          Expanded(
            child: filtered.isEmpty
                ? const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No transactions found',
                    subtitle: 'Try a different period or create a new sale',
                  )
                : RefreshIndicator(
                    onRefresh: () async => setState(() {}),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _buildInvoiceCard(filtered[i]),
                    ),
                  ),
          ),
        ],
      ),

    );
  }

  Widget _buildInvoiceCard(Map<String, dynamic> inv) {
    final dateStr = inv['invoiceDate'] ?? '';
    final invDate = DateTime.tryParse(dateStr);
    final lineItems = (inv['lineItems'] as List? ?? []);
    final itemDesc = lineItems.take(2).map((i) => i['description'] ?? '').join(', ');
    final more = lineItems.length > 2 ? ' +${lineItems.length - 2} more' : '';

    return AppCard(
      onTap: () {
        final id = inv['id'] ?? '';
        if (id.isEmpty) return;
        InvoiceEntity? entity;
        try {
          final converted = Map<String, dynamic>.from(inv);
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
          entity = InvoiceEntityJson.fromJson(converted);
        } catch (e) {
          debugPrint('[InvoiceList] Parse failed for $id: $e');
        }
        context.push('${AppRoutes.serviceHistory}/$id', extra: entity);
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
            child: const Icon(Icons.receipt_outlined, color: AppColors.primary, size: 22),
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
                        inv['customerName'] ?? 'Walk-in Customer',
                        style: Theme.of(context).textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '₹${_fmt((inv['grandTotal'] ?? 0).toDouble())}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(inv['invoiceNumber'] ?? '', style: Theme.of(context).textTheme.bodySmall),
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
          PopupMenuButton<String>(
            onSelected: (v) async {
              final id = inv['id'] ?? '';
              if (id.isEmpty) return;
              if (v == 'edit') {
                context.push('${AppRoutes.serviceHistory}/${id}/edit');
              } else if (v == 'delete') {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Sale'),
                    content: Text(
                      'Delete sale ${inv['invoiceNumber'] ?? ''}? This cannot be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete',
                            style: TextStyle(color: AppColors.danger)),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ref
                      .read(invoiceListProvider.notifier)
                      .removeInvoice(id.toString());
                  setState(() {});
                }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading:
                        Icon(Icons.edit_outlined, size: 18),
                    title: Text('Edit'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  )),
              const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline,
                        size: 18, color: AppColors.danger),
                    title: Text('Delete',
                        style: TextStyle(color: AppColors.danger)),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  )),
            ],
            icon: const Icon(Icons.more_vert,
                color: AppColors.textTertiaryLight, size: 20),
          ),
        ],
      ),
    );
  }
}
