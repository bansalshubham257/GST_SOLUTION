import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/plan_limits.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/barcode_scanner_sheet.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../features/invoice/presentation/providers/item_catalog_provider.dart';
import '../../../../features/invoice/data/models/item_catalog_entry.dart';
import '../../../../features/staff/presentation/providers/staff_provider.dart';
import '../../../../features/staff/domain/entities/staff_entity.dart';
import '../../../../features/customer/presentation/providers/customer_provider.dart';
import '../../../../features/dashboard/presentation/providers/dashboard_provider.dart';
import '../../../chat_flow/presentation/providers/sale_settings_provider.dart';
import '../../../settings/presentation/providers/feature_settings_provider.dart';
import '../providers/service_entry_provider.dart';

class QuickServiceEntryPage extends ConsumerStatefulWidget {
  const QuickServiceEntryPage({super.key});

  @override
  ConsumerState<QuickServiceEntryPage> createState() =>
      _QuickServiceEntryPageState();
}

class _QuickServiceEntryPageState
    extends ConsumerState<QuickServiceEntryPage> {
  final _discountController = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(serviceEntryProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _discountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(serviceEntryProvider);
    final staffAsync = ref.watch(staffListProvider);
    final servicesAsync = ref.watch(itemCatalogProvider);
    final customersAsync = ref.watch(customerListProvider);
    final settings = ref.watch(saleSettingsProvider);
    final features = ref.watch(featureSettingsProvider);

    ref.listen(serviceEntryProvider, (_, next) {
      if (next.isSuccess) {
        ref.invalidate(dashboardStatsProvider);
        ref.invalidate(recentInvoicesProvider);
        ref.invalidate(staffListProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sale completed!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${next.error}'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      // Sync discount controller when state resets
      if (next.discountPercent !=
          double.tryParse(_discountController.text)) {
        _discountController.text = next.discountPercent.toStringAsFixed(0);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Sale'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: state.services.isEmpty
                ? null
                : () => _confirmAndSave(state),
            child: const Text('Complete',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepIndicator(state),
            const SizedBox(height: 20),
            if (settings.askStaff && features.showStaff) _buildStaffSection(state, staffAsync),
            if (settings.askStaff && features.showStaff) const SizedBox(height: 16),
            _buildServicesSection(state, servicesAsync, settings),
            const SizedBox(height: 16),
            _buildPaymentSection(state),
            const SizedBox(height: 16),
            if (settings.askDiscount) _buildDiscountSection(state),
            if (settings.askDiscount) const SizedBox(height: 16),
            if (settings.askCustomer && features.showCustomers) _buildCustomerSection(state, customersAsync),
            if (settings.askCustomer && features.showCustomers) const SizedBox(height: 16),
            _buildTotalSection(state),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(state),
    );
  }

  Widget _buildStepIndicator(ServiceEntryState state) {
    final settings = ref.watch(saleSettingsProvider);
    final features = ref.watch(featureSettingsProvider);
    var currentStep = 0;
    final steps = <String>[];
    if (settings.askStaff && features.showStaff) {
      steps.add('Staff');
      if (state.selectedStaffId != null) currentStep = steps.indexOf('Staff') + 1;
    }
    steps.add('Items');
    if (state.services.isNotEmpty) currentStep = steps.indexOf('Items') + 1;
    steps.add('Payment');
    if (state.paymentMode.isNotEmpty) currentStep = steps.indexOf('Payment') + 1;
    if (settings.askCustomer && features.showCustomers) {
      steps.add('Customer');
      if (state.customerName != null) currentStep = steps.indexOf('Customer') + 1;
    }

    return Row(
      children: List.generate(steps.length, (i) {
        final isActive = i <= currentStep;
        final isLast = i == steps.length - 1;
        return Expanded(
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : AppColors.borderLight,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isActive
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : Text('${i + 1}',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiaryLight)),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    height: 2,
                    color: isActive
                        ? AppColors.primary
                        : AppColors.borderLight,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildStaffSection(
      ServiceEntryState state, AsyncValue<List<StaffEntity>> staffAsync) {
    return staffAsync.when(
      data: (staff) {
        if (staff.isEmpty) {
          return AppCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.person_add, color: AppColors.warning),
                  const SizedBox(width: 12),
                  const Expanded(
                      child: Text('Add staff members first',
                          style: TextStyle(color: AppColors.textSecondaryLight))),
                  TextButton(
                    onPressed: () => context.push(AppRoutes.addStaff),
                    child: const Text('Add'),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Assign Staff (optional)',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondaryLight)),
            const SizedBox(height: 10),
            SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: staff.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final s = staff[i];
                  final isSelected = state.selectedStaffId == s.id;
                  return GestureDetector(
                    onTap: () =>
                        ref.read(serviceEntryProvider.notifier).selectStaff(s),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.surfaceVariantLight,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.borderLight,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          s.name,
                          style: TextStyle(
                            color:
                                isSelected ? Colors.white : AppColors.textPrimaryLight,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildServicesSection(
      ServiceEntryState state, List<ItemCatalogEntry> services, SaleSettings settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Items',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondaryLight)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (settings.enableBarcode && settings.continuousScan)
                  TextButton.icon(
                    icon: const Icon(Icons.qr_code_scanner, size: 16),
                    label: const Text('Scan'),
                    onPressed: () => _startContinuousScan(),
                  ),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Item'),
                  onPressed: () => _showServicePicker(services, settings),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (state.services.isEmpty)
          GestureDetector(
            onTap: () => _showServicePicker(services, settings),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border.all(
                    color: AppColors.borderLight, style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(12),
                color: AppColors.surfaceVariantLight,
              ),
              child: const Column(
                children: [
                  Icon(Icons.add_shopping_cart, size: 40,
                      color: AppColors.textTertiaryLight),
                  SizedBox(height: 8),
                  Text('Tap to add an item',
                      style: TextStyle(color: AppColors.textSecondaryLight)),
                ],
              ),
            ),
          ),
        ...state.services.map((s) => _buildServiceChip(state, s)),
      ],
    );
  }

  Widget _buildServiceChip(ServiceEntryState state, ServiceEntryItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.serviceName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('₹${item.unitPrice.toStringAsFixed(0)} × ${item.quantity.toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: AppColors.textSecondaryLight, fontSize: 13)),
                ],
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  onPressed: item.quantity > 0.5
                      ? () => ref
                          .read(serviceEntryProvider.notifier)
                          .updateQuantity(item.serviceId, item.quantity - 1)
                      : null,
                ),
                Text(item.quantity.toStringAsFixed(0),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  onPressed: () => ref
                      .read(serviceEntryProvider.notifier)
                      .updateQuantity(item.serviceId, item.quantity + 1),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: AppColors.danger),
              onPressed: () => ref
                  .read(serviceEntryProvider.notifier)
                  .removeService(item.serviceId),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentSection(ServiceEntryState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Payment method',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondaryLight)),
        const SizedBox(height: 10),
        Row(
          children: [
            _paymentButton(state, 'cash', Icons.money, 'Cash'),
            const SizedBox(width: 10),
            _paymentButton(state, 'upi', Icons.qr_code_scanner, 'UPI'),
            const SizedBox(width: 10),
            _paymentButton(state, 'card', Icons.credit_card, 'Card'),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Payment status',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondaryLight)),
        const SizedBox(height: 10),
        Row(
          children: [
            _statusButton(state, 'paid', Icons.check_circle, 'Paid'),
            const SizedBox(width: 10),
            _statusButton(state, 'unpaid', Icons.pending, 'Unpaid'),
          ],
        ),
      ],
    );
  }

  Widget _statusButton(
      ServiceEntryState state, String value, IconData icon, String label) {
    final isSelected = state.paymentStatus == value;
    return Expanded(
      child: GestureDetector(
        onTap: () =>
            ref.read(serviceEntryProvider.notifier).setPaymentStatus(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primarySurface : Colors.white,
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.borderLight,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondaryLight,
                  size: 28),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondaryLight,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiscountSection(ServiceEntryState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Discount',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondaryLight)),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.discount, size: 20, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _discountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  suffixText: '%',
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  final parsed = double.tryParse(v);
                  if (parsed != null) {
                    ref
                        .read(serviceEntryProvider.notifier)
                        .setDiscount(parsed);
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _paymentButton(
      ServiceEntryState state, String value, IconData icon, String label) {
    final isSelected = state.paymentMode == value;
    return Expanded(
      child: GestureDetector(
        onTap: () =>
            ref.read(serviceEntryProvider.notifier).setPaymentMode(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primarySurface : Colors.white,
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.borderLight,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondaryLight,
                  size: 28),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondaryLight,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerSection(
      ServiceEntryState state, AsyncValue<List<CustomerEntity>> customersAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Customer (optional)',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondaryLight)),
            if (state.customerName != null)
              TextButton.icon(
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Remove'),
                onPressed: () =>
                    ref.read(serviceEntryProvider.notifier).clearCustomer(),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (state.customerName == null)
          GestureDetector(
            onTap: () => _showCustomerPicker(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.borderLight),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.person_add_outlined,
                      color: AppColors.textSecondaryLight),
                  SizedBox(width: 10),
                  Text('Select customer (optional)',
                      style: TextStyle(color: AppColors.textSecondaryLight)),
                ],
              ),
            ),
          )
        else
          AppCard(
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primarySurface,
                  radius: 18,
                  child: Text(
                    state.customerName![0].toUpperCase(),
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(state.customerName!,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (state.customerPhone != null)
                        Text(state.customerPhone!,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondaryLight)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTotalSection(ServiceEntryState state) {
    if (state.services.isEmpty) return const SizedBox.shrink();

    return AppCard(
      color: AppColors.primarySurface,
      child: Column(
        children: [
          _totalRow('Subtotal', state.subTotal, null),
          if (state.totalGst > 0)
            _totalRow('GST', state.totalGst, AppColors.primary),
          if (state.discountPercent > 0)
            _totalRow('Discount (${state.discountPercent.toStringAsFixed(0)}%)', -state.discountAmount, AppColors.danger),
          if (state.totalCommission > 0)
            _totalRow(
                'Commission (${state.staffCommissionPercentage.toStringAsFixed(0)}%)',
                state.totalCommission,
                AppColors.accent),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              Text('₹${state.grandTotal.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double amount, Color? color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: color ?? AppColors.textSecondaryLight, fontSize: 14)),
          Text('₹${amount.toStringAsFixed(0)}',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: color,
                  fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildBottomBar(ServiceEntryState state) {
    final canComplete = state.services.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.borderLight)),
      ),
      child: SafeArea(
        child: AppButton(
          label: state.grandTotal > 0
              ? 'Complete — ₹${state.grandTotal.toStringAsFixed(0)}'
              : 'Complete Sale',
          icon: Icons.check_circle_outline,
          onPressed: canComplete && !state.isSaving
              ? () => _confirmAndSave(state)
              : null,
          isLoading: state.isSaving,
          backgroundColor: AppColors.success,
        ),
      ),
    );
  }

  void _confirmAndSave(ServiceEntryState state) {
    // Plan limit check for sales
    final authState = ref.read(authStateProvider).valueOrNull;
    final maxSales = authState?.user?.maxSales ?? 999;
    final salesCount = LocalStorage.getAllCachedInvoices().length;
    if (PlanLimits.isLimitReached(salesCount, maxSales)) {
      PlanLimits.showLimitDialog(context, 'sales/invoices', salesCount, maxSales);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete Sale?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _confirmRow('Staff', state.selectedStaffName ?? '-'),
            _confirmRow(
                'Items',
                state.services
                    .map((s) =>
                        '${s.serviceName} × ${s.quantity.toStringAsFixed(0)}')
                    .join(', ')),
            _confirmRow('Payment', state.paymentMode.toUpperCase()),
            _confirmRow('Status', state.paymentStatus == 'paid' ? 'Paid' : 'Unpaid'),
            _confirmRow('Customer', state.customerName ?? 'Walk-in'),
            if (state.discountPercent > 0)
              _confirmRow('Discount', '${state.discountPercent.toStringAsFixed(0)}% (-₹${state.discountAmount.toStringAsFixed(0)})'),
            const Divider(),
            _confirmRow('Total', '₹${state.grandTotal.toStringAsFixed(0)}',
                bold: true),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(serviceEntryProvider.notifier).saveServiceEntry();
            },
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Complete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _confirmRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$label: ',
              style: const TextStyle(color: AppColors.textSecondaryLight)),
          Text(value,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
        ],
      ),
    );
  }

  void _startContinuousScan() {
    BarcodeScannerSheet.show(
      context,
      continuous: true,
      onDetected: (value, format) {
        final notifier = ref.read(itemCatalogProvider.notifier);
        final found = notifier.findByBarcode(value);
        if (found != null) {
          ref.read(serviceEntryProvider.notifier).addService(
            ItemCatalogEntry(
              id: found.id,
              name: found.name,
              unit: found.unit,
              unitPrice: found.unitPrice,
              gstRate: found.gstRate,
              hsnCode: found.hsnCode,
              isService: found.isService,
              barcode: found.barcode,
            ),
          );
          HapticFeedback.lightImpact();
        } else {
          HapticFeedback.heavyImpact();
        }
      },
      hint: 'Scan barcodes continuously — close when done',
    );
  }

  void _showServicePicker(List<ItemCatalogEntry> services, SaleSettings settings) {
    final allServices =
        settings.enableCatalog ? services.where((s) => s.isService).toList() : <ItemCatalogEntry>[];
    final products =
        settings.enableCatalog ? services.where((s) => !s.isService).toList() : <ItemCatalogEntry>[];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ServicePickerSheet(
        services: allServices,
        products: products,
        onSelect: (item) {
          ref.read(serviceEntryProvider.notifier).addService(item);
          Navigator.pop(context);
        },
        onAddNew: () {
          context.push('${AppRoutes.quickServiceEntry}/add-item');
        },
        enableBarcode: settings.enableBarcode,
      ),
    );
  }

  void _showCustomerPicker() async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _QuickCustomerPicker(),
    );

    if (result != null) {
      ref.read(serviceEntryProvider.notifier).setCustomer(
        result['id']!,
        result['name']!,
        result['phone'] ?? '',
        gstin: result['gstin'],
        stateName: result['state'],
      );
    }
  }
}

// ─── Service Picker Bottom Sheet ─────────────────────────────────────────────

class _ServicePickerSheet extends ConsumerStatefulWidget {
  final List<ItemCatalogEntry> services;
  final List<ItemCatalogEntry> products;
  final Function(ItemCatalogEntry) onSelect;
  final VoidCallback onAddNew;
  final bool enableBarcode;

  const _ServicePickerSheet({
    required this.services,
    required this.products,
    required this.onSelect,
    required this.onAddNew,
    this.enableBarcode = false,
  });

  @override
  ConsumerState<_ServicePickerSheet> createState() => _ServicePickerSheetState();
}

class _ServicePickerSheetState extends ConsumerState<_ServicePickerSheet> {
  final _searchController = TextEditingController();
  var _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ItemCatalogEntry> _filter(List<ItemCatalogEntry> items) {
    if (_searchQuery.isEmpty) return items;
    final q = _searchQuery.toLowerCase();
    return items.where((i) =>
        i.name.toLowerCase().contains(q) ||
        (i.hsnCode ?? '').toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredServices = _filter(widget.services);
    final filteredProducts = _filter(widget.products);

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Select Item',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.enableBarcode)
                      IconButton(
                        icon: const Icon(Icons.qr_code_scanner, size: 22),
                        tooltip: 'Scan Barcode',
                        onPressed: () {
                          BarcodeScannerSheet.show(context, onDetected: (value, format) {
                            final notifier = ref.read(itemCatalogProvider.notifier);
                            final found = notifier.findByBarcode(value);
                            if (found != null && mounted) {
                              widget.onSelect(found);
                            } else if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Item not found for barcode: $value')),
                              );
                            }
                          });
                        },
                      ),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('New'),
                      onPressed: widget.onAddNew,
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
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search items...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.borderLight)),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: _computeItemCount(filteredServices, filteredProducts),
              itemBuilder: (_, i) => _buildSearchListItem(i, filteredServices, filteredProducts),
            ),
          ),
        ],
      ),
    );
  }

  int _computeItemCount(List filteredServices, List filteredProducts) {
    int count = 0;
    if (filteredServices.isNotEmpty) count += filteredServices.length + 2; // header + spacer
    if (filteredProducts.isNotEmpty) count += filteredProducts.length + 2; // header + spacer
    if (filteredServices.isEmpty && filteredProducts.isEmpty) count = 1; // empty state
    return count;
  }

  Widget _buildSearchListItem(int i, List filteredServices, List filteredProducts) {
    int offset = 0;
    if (filteredServices.isNotEmpty) {
      if (i == 0) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.content_cut, size: 14, color: AppColors.secondary),
              const SizedBox(width: 6),
              Text('SERVICES',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.secondary)),
            ],
          ),
        );
      }
      if (i == 1) return const SizedBox(height: 4);
      offset = 2;
      final si = i - offset;
      if (si < filteredServices.length) {
        return _ServiceItemVertical(
            item: filteredServices[si], onTap: () => widget.onSelect(filteredServices[si] as dynamic));
      }
      offset += filteredServices.length;
    }
    if (filteredProducts.isNotEmpty) {
      if (i == offset) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.inventory_2_outlined, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Text('PRODUCTS',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
            ],
          ),
        );
      }
      if (i == offset + 1) return const SizedBox(height: 4);
      offset += 2;
      final pi = i - offset;
      if (pi < filteredProducts.length) {
        return _ServiceItemVertical(
            item: filteredProducts[pi], onTap: () => widget.onSelect(filteredProducts[pi] as dynamic));
      }
    }
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.textTertiaryLight),
          SizedBox(height: 12),
          Text('No items found', style: TextStyle(color: AppColors.textSecondaryLight)),
        ],
      ),
    );
  }
}

class _ServiceItemVertical extends StatelessWidget {
  final ItemCatalogEntry item;
  final VoidCallback onTap;

  const _ServiceItemVertical({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: item.isService
                ? AppColors.secondarySurface
                : AppColors.primarySurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            children: [
              Icon(
                item.isService
                    ? Icons.content_cut
                    : Icons.inventory_2_outlined,
                size: 20,
                color:
                    item.isService ? AppColors.secondary : AppColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    if (item.hsnCode != null)
                      Text('HSN: ${item.hsnCode}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textTertiaryLight)),
                  ],
                ),
              ),
              Text('₹${item.unitPrice.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('${item.gstRate.toStringAsFixed(0)}%',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceItem extends StatelessWidget {
  final ItemCatalogEntry item;
  final VoidCallback onTap;

  const _ServiceItem({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: item.isService
              ? AppColors.secondarySurface
              : AppColors.primarySurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              item.isService
                  ? Icons.content_cut
                  : Icons.inventory_2_outlined,
              size: 20,
              color:
                  item.isService ? AppColors.secondary : AppColors.primary,
            ),
            const SizedBox(height: 6),
            Text(item.name,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text('₹${item.unitPrice.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
          ],
        ),
      ),
    );
  }
}

// ─── Quick Customer Picker ──────────────────────────────────────────────────

class _QuickCustomerPicker extends ConsumerStatefulWidget {
  const _QuickCustomerPicker();

  @override
  ConsumerState<_QuickCustomerPicker> createState() =>
      _QuickCustomerPickerState();
}

class _QuickCustomerPickerState extends ConsumerState<_QuickCustomerPicker> {
  final _searchController = TextEditingController();
  var _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customerListProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Select Customer (Optional)',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.person_add, size: 16),
                  label: const Text('Add'),
                  onPressed: () async {
                    final result = await context.push(
                      AppRoutes.addCustomer,
                    );
                    if (result is CustomerEntity && mounted) {
                      Navigator.pop(context, {
                        'id': result.id,
                        'name': result.name,
                        'phone': result.phone ?? '',
                        'gstin': result.gstin ?? '',
                        'state': result.state ?? '',
                      });
                    }
                  },
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Skip'),
                ),
              ],
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search customers...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.borderLight)),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: customersAsync.when(
              data: (list) {
                final filtered = _searchQuery.isEmpty
                    ? list
                    : list.where((c) {
                        final q = _searchQuery.toLowerCase();
                        return c.name.toLowerCase().contains(q) ||
                            (c.phone ?? '').contains(_searchQuery) ||
                            (c.gstin ?? '').toLowerCase().contains(q);
                      }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No customers found'));
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primarySurface,
                      child: Text(filtered[i].name[0].toUpperCase(),
                          style:
                              const TextStyle(color: AppColors.primary)),
                    ),
                    title: Text(filtered[i].name),
                    subtitle: Text([filtered[i].phone, filtered[i].gstin]
                        .whereType<String>()
                        .where((s) => s.isNotEmpty)
                        .join(' • ')),
                    onTap: () => Navigator.pop(context, {
                      'id': filtered[i].id,
                      'name': filtered[i].name,
                      'phone': filtered[i].phone ?? '',
                      'gstin': filtered[i].gstin ?? '',
                      'state': filtered[i].state ?? '',
                    }),
                  ),
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(child: Text('Error')),
            ),
          ),
        ],
      ),
    );
  }
}
