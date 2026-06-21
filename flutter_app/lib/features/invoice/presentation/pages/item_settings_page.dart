// lib/features/invoice/presentation/pages/item_settings_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../providers/item_settings_provider.dart';

class ItemSettingsPage extends ConsumerWidget {
  const ItemSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(itemSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Item Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Fields to Show in Item Form',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: AppColors.textSecondaryLight)),
          const SizedBox(height: 8),
          AppCard(
            child: Column(
              children: [
                _SwitchTile(
                  icon: Icons.shopping_cart_outlined,
                  title: 'Purchase Price',
                  subtitle: 'Show purchase price field for profit tracking',
                  value: settings.showPurchasePrice,
                  onChanged: (v) => _update(ref, settings.copyWith(showPurchasePrice: v)),
                ),
                const Divider(height: 1),
                _SwitchTile(
                  icon: Icons.warehouse_outlined,
                  title: 'Stock Quantity',
                  subtitle: 'Show current stock field',
                  value: settings.showStock,
                  onChanged: (v) => _update(ref, settings.copyWith(showStock: v)),
                ),
                const Divider(height: 1),
                _SwitchTile(
                  icon: Icons.notifications_outlined,
                  title: 'Low Stock Alert',
                  subtitle: 'Show low stock threshold field in item form',
                  value: settings.showLowStockAlert,
                  onChanged: (v) => _update(ref, settings.copyWith(showLowStockAlert: v)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.trending_down, color: AppColors.primary, size: 22),
                  title: const Text('Default Alert Threshold', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  subtitle: Text('Items below ${settings.defaultLowStockThreshold.toStringAsFixed(0)} qty trigger alert',
                      style: const TextStyle(fontSize: 12)),
                  trailing: SizedBox(
                    width: 60,
                    child: TextField(
                      controller: TextEditingController(text: settings.defaultLowStockThreshold.toStringAsFixed(0)),
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        isDense: true,
                      ),
                      onSubmitted: (v) {
                        final val = double.tryParse(v);
                        if (val != null && val > 0) {
                          _update(ref, settings.copyWith(defaultLowStockThreshold: val));
                        }
                      },
                    ),
                  ),
                ),
                const Divider(height: 1),
                _SwitchTile(
                  icon: Icons.calendar_today,
                  title: 'Manufacturing Date',
                  subtitle: 'Show manufacturing date picker',
                  value: settings.showManufacturingDate,
                  onChanged: (v) => _update(ref, settings.copyWith(showManufacturingDate: v)),
                ),
                const Divider(height: 1),
                _SwitchTile(
                  icon: Icons.event,
                  title: 'Expiry Date',
                  subtitle: 'Show expiry date picker',
                  value: settings.showExpiryDate,
                  onChanged: (v) => _update(ref, settings.copyWith(showExpiryDate: v)),
                ),
                const Divider(height: 1),
                _SwitchTile(
                  icon: Icons.date_range,
                  title: 'Best Before Date',
                  subtitle: 'Show best before date picker',
                  value: settings.showBestBeforeDate,
                  onChanged: (v) => _update(ref, settings.copyWith(showBestBeforeDate: v)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _update(WidgetRef ref, ItemSettings s) {
    ref.read(itemSettingsProvider.notifier).save(s);
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, color: AppColors.primary, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      value: value,
      onChanged: onChanged,
    );
  }
}
