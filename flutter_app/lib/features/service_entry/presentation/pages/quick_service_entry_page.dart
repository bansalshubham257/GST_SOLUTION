import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/plan_limits.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../features/invoice/presentation/providers/item_catalog_provider.dart';
import '../../../../features/invoice/data/models/item_catalog_entry.dart';
import '../../../../features/staff/presentation/providers/staff_provider.dart';
import '../../../../features/staff/domain/entities/staff_entity.dart';
import '../../../../features/customer/presentation/providers/customer_provider.dart';
import '../../../../features/dashboard/presentation/providers/dashboard_provider.dart';
import '../providers/service_entry_provider.dart';

class QuickServiceEntryPage extends ConsumerStatefulWidget {
  const QuickServiceEntryPage({super.key});

  @override
  ConsumerState<QuickServiceEntryPage> createState() =>
      _QuickServiceEntryPageState();
}

class _QuickServiceEntryPageState
    extends ConsumerState<QuickServiceEntryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(serviceEntryProvider.notifier).reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(serviceEntryProvider);
    final staffAsync = ref.watch(staffListProvider);
    final servicesAsync = ref.watch(itemCatalogProvider);
    final customersAsync = ref.watch(customerListProvider);

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
            _buildStaffSection(state, staffAsync),
            const SizedBox(height: 16),
            _buildServicesSection(state, servicesAsync),
            const SizedBox(height: 16),
            _buildPaymentSection(state),
            const SizedBox(height: 16),
            _buildCustomerSection(state, customersAsync),
            const SizedBox(height: 16),
            _buildTotalSection(state),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(state),
    );
  }

  Widget _buildStepIndicator(ServiceEntryState state) {
    final steps = ['Staff', 'Items', 'Payment', 'Customer'];
    int currentStep = 1;
    if (state.services.isNotEmpty) currentStep = 2;
    if (state.paymentMode.isNotEmpty) currentStep = 3;
    if (state.customerName != null) currentStep = 4;

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
      ServiceEntryState state, List<ItemCatalogEntry> services) {
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
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Item'),
              onPressed: () => _showServicePicker(services),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (state.services.isEmpty)
          GestureDetector(
            onTap: () => _showServicePicker(services),
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
            _confirmRow('Customer', state.customerName ?? 'Walk-in'),
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

  void _showServicePicker(List<ItemCatalogEntry> services) {
    final allServices =
        services.where((s) => s.isService).toList();
    final products =
        services.where((s) => !s.isService).toList();

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

class _ServicePickerSheet extends StatefulWidget {
  final List<ItemCatalogEntry> services;
  final List<ItemCatalogEntry> products;
  final Function(ItemCatalogEntry) onSelect;
  final VoidCallback onAddNew;

  const _ServicePickerSheet({
    required this.services,
    required this.products,
    required this.onSelect,
    required this.onAddNew,
  });

  @override
  State<_ServicePickerSheet> createState() => _ServicePickerSheetState();
}

class _ServicePickerSheetState extends State<_ServicePickerSheet> {
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
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New'),
                  onPressed: widget.onAddNew,
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
            child: ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                if (filteredServices.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.content_cut,
                            size: 14, color: AppColors.secondary),
                        const SizedBox(width: 6),
                        Text('SERVICES',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.secondary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredServices.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => _ServiceItem(
                          item: filteredServices[i],
                          onTap: () => widget.onSelect(filteredServices[i])),
                    ),
                  ),
                ],
                if (filteredProducts.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.inventory_2_outlined,
                            size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text('PRODUCTS',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredProducts.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => _ServiceItem(
                          item: filteredProducts[i],
                          onTap: () =>
                              widget.onSelect(filteredProducts[i])),
                    ),
                  ),
                ],
                if (filteredServices.isEmpty && filteredProducts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 48, color: AppColors.textTertiaryLight),
                        SizedBox(height: 12),
                        Text('No items found',
                            style: TextStyle(
                                color: AppColors.textSecondaryLight)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
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
