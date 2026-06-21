// lib/features/chat_flow/presentation/pages/sale_settings_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../providers/sale_settings_provider.dart';

class SaleSettingsPage extends ConsumerWidget {
  const SaleSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(saleSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sale Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Sale Type',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: AppColors.textSecondaryLight)),
          const SizedBox(height: 8),
          AppCard(
            child: Column(
              children: [
                RadioListTile<String>(
                  title: const Text('Retail / General'),
                  subtitle: const Text('Ask for customer, items, quantity, price, payment'),
                  value: 'retail',
                  groupValue: settings.saleType,
                  onChanged: (v) => _update(ref, settings.copyWith(saleType: v)),
                ),
                const Divider(height: 1),
                RadioListTile<String>(
                  title: const Text('Supermarket / Quick Sale'),
                  subtitle: const Text('Scan barcodes, skip optional fields, fast checkout'),
                  value: 'supermarket',
                  groupValue: settings.saleType,
                  onChanged: (v) => _update(ref, settings.copyWith(saleType: v)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Fields to Show During Sale',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: AppColors.textSecondaryLight)),
          const SizedBox(height: 8),
          AppCard(
            child: Column(
              children: [
                _SwitchTile(
                  icon: Icons.people,
                  title: 'Ask for Customer',
                  subtitle: 'Show customer selection step',
                  value: settings.askCustomer,
                  onChanged: (v) => _update(ref, settings.copyWith(askCustomer: v)),
                ),
                const Divider(height: 1),
                _SwitchTile(
                  icon: Icons.badge,
                  title: 'Ask for Staff',
                  subtitle: 'Show staff selection step',
                  value: settings.askStaff,
                  onChanged: (v) => _update(ref, settings.copyWith(askStaff: v)),
                ),
                const Divider(height: 1),
                _SwitchTile(
                  icon: Icons.numbers,
                  title: 'Ask for Quantity',
                  subtitle: 'Prompt for quantity per item (default: ${settings.defaultQty.toStringAsFixed(0)})',
                  value: settings.askQty,
                  onChanged: (v) => _update(ref, settings.copyWith(askQty: v)),
                ),
                const Divider(height: 1),
                _SwitchTile(
                  icon: Icons.currency_rupee,
                  title: 'Ask for Price',
                  subtitle: 'Prompt for unit price per item',
                  value: settings.askPrice,
                  onChanged: (v) => _update(ref, settings.copyWith(askPrice: v)),
                ),
                const Divider(height: 1),
                _SwitchTile(
                  icon: Icons.percent,
                  title: 'Ask for GST Rate',
                  subtitle: 'Prompt for GST rate (default: ${settings.defaultGst.toStringAsFixed(0)}%)',
                  value: settings.askGst,
                  onChanged: (v) => _update(ref, settings.copyWith(askGst: v)),
                ),
                const Divider(height: 1),
                _SwitchTile(
                  icon: Icons.discount,
                  title: 'Ask for Discount',
                  subtitle: 'Prompt for discount on total bill',
                  value: settings.askDiscount,
                  onChanged: (v) => _update(ref, settings.copyWith(askDiscount: v)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Features',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: AppColors.textSecondaryLight)),
          const SizedBox(height: 8),
          AppCard(
            child: Column(
              children: [
                _SwitchTile(
                  icon: Icons.qr_code_scanner,
                  title: 'Barcode Scanning',
                  subtitle: 'Show barcode scanner button in item selection',
                  value: settings.enableBarcode,
                  onChanged: (v) => _update(ref, settings.copyWith(enableBarcode: v)),
                ),
                if (settings.enableBarcode) ...[
                  const Divider(height: 1),
                  _SwitchTile(
                    icon: Icons.swap_horiz,
                    title: 'Continuous Scan',
                    subtitle: 'After scanning, auto-open scanner for next item (supermarket flow)',
                    value: settings.continuousScan,
                    onChanged: (v) => _update(ref, settings.copyWith(continuousScan: v)),
                  ),
                ],
                const Divider(height: 1),
                _SwitchTile(
                  icon: Icons.inventory_2,
                  title: 'Item Catalog',
                  subtitle: 'Show saved catalog items as quick options',
                  value: settings.enableCatalog,
                  onChanged: (v) => _update(ref, settings.copyWith(enableCatalog: v)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Defaults',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: AppColors.textSecondaryLight)),
          const SizedBox(height: 8),
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DefaultField(
                    label: 'Default Quantity',
                    value: settings.defaultQty,
                    onChanged: (v) => _update(ref, settings.copyWith(defaultQty: v)),
                  ),
                  const SizedBox(height: 12),
                  _DefaultField(
                    label: 'Default GST Rate (%)',
                    value: settings.defaultGst,
                    onChanged: (v) => _update(ref, settings.copyWith(defaultGst: v)),
                  ),
                  const SizedBox(height: 12),
                  _DefaultField(
                    label: 'Default Discount (%)',
                    value: settings.defaultDiscount,
                    onChanged: (v) => _update(ref, settings.copyWith(defaultDiscount: v)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _update(WidgetRef ref, SaleSettings s) {
    ref.read(saleSettingsProvider.notifier).save(s);
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

class _DefaultField extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const _DefaultField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        const Spacer(),
        SizedBox(
          width: 80,
          child: TextField(
            controller: TextEditingController(text: value.toStringAsFixed(0)),
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(),
            ),
            onSubmitted: (v) {
              final parsed = double.tryParse(v);
              if (parsed != null) onChanged(parsed);
            },
          ),
        ),
      ],
    );
  }
}
