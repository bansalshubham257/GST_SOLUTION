import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../providers/feature_settings_provider.dart';

class FeatureSettingsPage extends ConsumerWidget {
  const FeatureSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(featureSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Feature Visibility')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Show or hide features across the app. Disabled features will be hidden from navigation, menus, and all flows.',
            style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 13),
          ),
          const SizedBox(height: 20),
          AppCard(
            child: Column(
              children: [
                _buildSwitch(
                  context,
                  icon: Icons.people_outline,
                  title: 'Staff',
                  subtitle: 'Staff list, assignment in sales',
                  value: settings.showStaff,
                  onChanged: (v) => _save(ref, settings.copyWith(showStaff: v)),
                ),
                const Divider(height: 1),
                _buildSwitch(
                  context,
                  icon: Icons.people,
                  title: 'Customers',
                  subtitle: 'Customer list, customer selection in sales',
                  value: settings.showCustomers,
                  onChanged: (v) => _save(ref, settings.copyWith(showCustomers: v)),
                ),
                const Divider(height: 1),
                _buildSwitch(
                  context,
                  icon: Icons.shopping_cart_outlined,
                  title: 'Purchases',
                  subtitle: 'Purchase management, purchase summary on dashboard',
                  value: settings.showPurchases,
                  onChanged: (v) => _save(ref, settings.copyWith(showPurchases: v)),
                ),
                const Divider(height: 1),
                _buildSwitch(
                  context,
                  icon: Icons.receipt_long_outlined,
                  title: 'GST Reports',
                  subtitle: 'GST reports tab, monthly summaries',
                  value: settings.showGstReports,
                  onChanged: (v) => _save(ref, settings.copyWith(showGstReports: v)),
                ),
                const Divider(height: 1),
                _buildSwitch(
                  context,
                  icon: Icons.outbound,
                  title: 'Expenses',
                  subtitle: 'Expense entry on dashboard quick actions',
                  value: settings.showExpenses,
                  onChanged: (v) => _save(ref, settings.copyWith(showExpenses: v)),
                ),
                const Divider(height: 1),
                _buildSwitch(
                  context,
                  icon: Icons.inventory_2_outlined,
                  title: 'Items / Catalog',
                  subtitle: 'Item catalog, dashboard quick actions, bottom nav',
                  value: settings.showItems,
                  onChanged: (v) => _save(ref, settings.copyWith(showItems: v)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitch(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.primarySurface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
    );
  }

  Future<void> _save(WidgetRef ref, FeatureSettings updated) async {
    await ref.read(featureSettingsProvider.notifier).save(updated);
  }
}
