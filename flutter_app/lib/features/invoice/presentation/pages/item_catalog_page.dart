// lib/features/invoice/presentation/pages/item_catalog_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/barcode_scanner_sheet.dart';
import '../../../../core/widgets/barcode_generator.dart';
import '../../../../core/services/barcode_print_service.dart';
import '../../data/models/item_catalog_entry.dart';
import '../providers/item_catalog_provider.dart';

class ItemCatalogPage extends ConsumerStatefulWidget {
  const ItemCatalogPage({super.key});

  @override
  ConsumerState<ItemCatalogPage> createState() => _ItemCatalogPageState();
}

class _ItemCatalogPageState extends ConsumerState<ItemCatalogPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(itemCatalogProvider);
    final filtered = _searchQuery.isEmpty
        ? items
        : items
            .where((i) =>
                i.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                (i.hsnCode ?? '').contains(_searchQuery))
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print, size: 22),
            tooltip: 'Generate Barcodes',
            onPressed: () => _showPrintSheet(),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'expenses') context.push(AppRoutes.expenses);
              if (v == 'gst') context.push(AppRoutes.gstFiling);
              if (v == 'gstr1') context.push(AppRoutes.gstr1);
              if (v == 'gstr3b') context.push(AppRoutes.gstr3b);
              if (v == 'history') context.push(AppRoutes.serviceHistory);
              if (v == 'support') context.push(AppRoutes.chatSupport);
              if (v == 'profile') context.push(AppRoutes.profile);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'history', child: ListTile(
                leading: Icon(Icons.history), title: Text('Service History'), contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'expenses', child: ListTile(
                leading: Icon(Icons.outbound), title: Text('Expenses'), contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'gst', child: ListTile(
                leading: Icon(Icons.verified), title: Text('GST Filing'), contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'gstr1', child: ListTile(
                leading: Icon(Icons.description), title: Text('GSTR-1'), contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'gstr3b', child: ListTile(
                leading: Icon(Icons.summarize), title: Text('GSTR-3B'), contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'support', child: ListTile(
                leading: Icon(Icons.support), title: Text('Support'), contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'profile', child: ListTile(
                leading: Icon(Icons.settings), title: Text('Settings'), contentPadding: EdgeInsets.zero)),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: AppTextField(
              hint: 'Search services or products...',
              controller: _searchController,
              prefix: const Icon(Icons.search, size: 20),
              suffix: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              onChanged: (q) => setState(() => _searchQuery = q),
            ),
          ),
        ),
      ),
      body: items.isEmpty
          ? EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No services yet',
              subtitle: 'Add your services & products for faster billing',
              actionLabel: '+ Add Service',
              onAction: () => context.push(AppRoutes.addService),
            )
          : filtered.isEmpty
              ? const Center(
                  child: Text('No items match your search',
                      style: TextStyle(color: AppColors.textSecondaryLight)))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _ItemTile(
                    item: filtered[i],
                    onEdit: () => context.push(AppRoutes.editServiceItem, extra: filtered[i]),
                    onDelete: () => _confirmDelete(filtered[i]),
                    onGenerateBarcode: () => _generateBarcode(filtered[i]),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
            heroTag: 'add_item',
            onPressed: () => context.push(AppRoutes.addService),
            backgroundColor: AppColors.secondary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded, size: 22),
            label: const Text('Add Service', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
    );
  }

  void _generateBarcode(ItemCatalogEntry item) {
    if (item.barcode != null && item.barcode!.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.name} already has a barcode'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    final numericId = int.tryParse(item.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final barcodeValue = BarcodeGeneratorUtil.generateEan13(numericId);
    final updated = item.copyWith(barcode: barcodeValue);
    ref.read(itemCatalogProvider.notifier).updateItem(updated);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Barcode generated for ${item.name}'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _scanToFind() {
    BarcodeScannerSheet.show(
      context,
      onDetected: (value, _) {
        final notifier = ref.read(itemCatalogProvider.notifier);
        final found = notifier.findByBarcode(value);
        if (found != null) {
          setState(() => _searchController.text = found.name);
          setState(() => _searchQuery = found.name);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Found: ${found.name}'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Item not found. Add it to catalog.'),
              backgroundColor: AppColors.warning,
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Add',
                textColor: Colors.white,
                onPressed: () => context.push(AppRoutes.addService),
              ),
            ),
          );
        }
      },
      hint: 'Scan item barcode / QR to search',
    );
  }

  void _showPrintSheet() {
    final items = ref.read(itemCatalogProvider);
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    final quantities = <String, int>{for (final i in items) i.id: 0};
    final statusMessages = <String, String>{};
    var searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final filtered = searchQuery.isEmpty
              ? items
              : items.where((i) =>
                  i.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                  (i.hsnCode ?? '').toLowerCase().contains(searchQuery.toLowerCase())).toList();

          return Container(
          height: MediaQuery.of(ctx).size.height * 0.8,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Generate Barcodes',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.print, size: 16),
                          label: const Text('Print', style: TextStyle(fontSize: 13)),
                          onPressed: () {
                            final toPrint = <(String name, String code, int copies)>[];
                            for (final item in items) {
                              final qty = quantities[item.id] ?? 0;
                              if (qty <= 0) continue;
                              if (item.barcode == null || item.barcode!.isEmpty) {
                                statusMessages[item.id] = 'No barcode assigned';
                                continue;
                              }
                              toPrint.add((item.name, item.barcode!, qty));
                            }
                            if (toPrint.isEmpty) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('Selected items have no barcode. Tap "Generate" first.'), behavior: SnackBarBehavior.floating),
                              );
                              return;
                            }
                            Navigator.pop(ctx);
                            BarcodePrintService.printLabels(toPrint);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search items...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setSheetState(() => searchQuery = ''),
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  onChanged: (v) => setSheetState(() => searchQuery = v),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.auto_fix_high, size: 18),
                    label: const Text('Generate Barcodes for Selected Items'),
                    onPressed: () async {
                      final notifier = ref.read(itemCatalogProvider.notifier);
                      var generated = 0;
                      for (final item in items) {
                        final qty = quantities[item.id] ?? 0;
                        if (qty <= 0) continue;
                        if (item.barcode != null && item.barcode!.isNotEmpty) {
                          statusMessages[item.id] = '✓ Already has barcode';
                          continue;
                        }
                        final numericId = int.tryParse(item.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                        final barcode = BarcodeGeneratorUtil.generateEan13(numericId);
                        final updated = item.copyWith(barcode: barcode);
                        await notifier.updateItem(updated);
                        statusMessages[item.id] = '✓ $barcode';
                        generated++;
                      }
                      setSheetState(() {});
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text(generated > 0 ? '$generated barcodes generated!' : 'No new barcodes needed'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('No items match search', style: TextStyle(color: AppColors.textSecondaryLight)))
                    : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final item = filtered[i];
                    final qty = quantities[item.id] ?? 0;
                    final barcode = item.barcode ?? '-';
                    final status = statusMessages[item.id] ?? (item.barcode != null && item.barcode!.isNotEmpty ? '✓ $barcode' : '⚠ No barcode');
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: qty > 0 ? AppColors.primary : AppColors.borderLight,
                        radius: 18,
                        child: Text('${qty}',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: qty > 0 ? Colors.white : AppColors.textTertiaryLight)),
                      ),
                      title: Text(item.name,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text(status,
                          style: TextStyle(
                              fontSize: 11,
                              color: item.barcode != null && item.barcode!.isNotEmpty
                                  ? AppColors.textSecondaryLight
                                  : AppColors.warning)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, size: 20),
                            onPressed: qty > 0
                                ? () => setSheetState(() => quantities[item.id] = qty - 1)
                                : null,
                          ),
                          Container(
                            width: 36,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('$qty',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, size: 20),
                            onPressed: () => setSheetState(() => quantities[item.id] = qty + 1),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
      ),
    );
  }

  void _confirmDelete(ItemCatalogEntry item) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete "${item.name}"?'),
        content: const Text('This item will be removed from your catalog.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext, rootNavigator: true).pop(),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext, rootNavigator: true).pop();
              ref.read(itemCatalogProvider.notifier).removeItem(item.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('"${item.name}" removed'),
                  backgroundColor: AppColors.danger,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ─── Item Tile ────────────────────────────────────────────────────────────────

class _ItemTile extends StatelessWidget {
  final ItemCatalogEntry item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onGenerateBarcode;

  const _ItemTile({
    required this.item,
    required this.onEdit,
    required this.onDelete,
    this.onGenerateBarcode,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: item.isService
                  ? AppColors.secondarySurface
                  : AppColors.primarySurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              item.isService
                  ? Icons.miscellaneous_services_outlined
                  : Icons.inventory_2_outlined,
              color: item.isService ? AppColors.secondary : AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: AppColors.textPrimaryLight),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accentSurface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${item.gstRate.toStringAsFixed(0)}% GST',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accentDark),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '₹${item.unitPrice.toStringAsFixed(2)} / ${item.unit}',
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondaryLight,
                          fontWeight: FontWeight.w500),
                    ),
                    if (item.hsnCode != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        'HSN: ${item.hsnCode}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiaryLight),
                      ),
                    ],
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: item.isService
                            ? AppColors.secondarySurface
                            : AppColors.infoLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.isService ? 'Service' : 'Product',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: item.isService
                              ? AppColors.secondary
                              : AppColors.info,
                        ),
                      ),
                    ),
                  ],
                ),
                if (!item.isService && item.lowStockThreshold != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        item.isOutOfStock
                            ? Icons.error_outline
                            : item.isLowStock
                                ? Icons.warning_amber_rounded
                                : Icons.check_circle_outline,
                        size: 12,
                        color: item.isOutOfStock
                            ? AppColors.danger
                            : item.isLowStock
                                ? AppColors.warning
                                : AppColors.success,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.isOutOfStock
                            ? 'Out of stock'
                            : 'Stock: ${item.stock.toStringAsFixed(0)} / ${item.lowStockThreshold!.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: item.isOutOfStock
                              ? AppColors.danger
                              : item.isLowStock
                                  ? AppColors.warning
                                  : AppColors.success,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
                if (item.purchasePrice != null && item.purchasePrice! > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.trending_up, size: 12, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text(
                        'Profit: ₹${(item.unitPrice - item.purchasePrice!).toStringAsFixed(2)}/unit',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.success,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Actions
          Column(
            children: [
              if (onGenerateBarcode != null)
                InkWell(
                  onTap: onGenerateBarcode,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      item.barcode != null && item.barcode!.isNotEmpty
                          ? Icons.qr_code
                          : Icons.qr_code_2,
                      size: 18,
                      color: item.barcode != null && item.barcode!.isNotEmpty
                          ? AppColors.primary
                          : AppColors.textTertiaryLight,
                    ),
                  ),
                ),
              InkWell(
                onTap: onEdit,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.edit_outlined,
                      size: 18, color: AppColors.primary),
                ),
              ),
              InkWell(
                onTap: onDelete,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.delete_outline,
                      size: 18, color: AppColors.danger),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

