// lib/features/invoice/presentation/pages/item_catalog_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/barcode_scanner_sheet.dart';
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

  void _confirmDelete(ItemCatalogEntry item) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete "${item.name}"?'),
        content: const Text('This item will be removed from your catalog.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
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

  const _ItemTile(
      {required this.item, required this.onEdit, required this.onDelete});

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
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Actions
          Column(
            children: [
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

