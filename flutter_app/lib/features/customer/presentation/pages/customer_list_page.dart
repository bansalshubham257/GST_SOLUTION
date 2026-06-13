// lib/features/customer/presentation/pages/customer_list_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../providers/customer_provider.dart';

class CustomerListPage extends ConsumerStatefulWidget {
  const CustomerListPage({super.key});

  @override
  ConsumerState<CustomerListPage> createState() => _CustomerListPageState();
}

class _CustomerListPageState extends ConsumerState<CustomerListPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customerListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: AppTextField(
              hint: 'Search customers...',
              controller: _searchController,
              prefix: const Icon(Icons.search, size: 20),
              suffix: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(customerListProvider.notifier).search('');
                      },
                    )
                  : null,
              onChanged: (q) => ref.read(customerListProvider.notifier).search(q),
            ),
          ),
        ),
      ),
      body: customers.when(
        data: (list) => list.isEmpty
            ? EmptyState(
                icon: Icons.people_outline,
                title: 'No customers yet',
                subtitle: 'Add your first customer to get started',
                actionLabel: 'Add Customer',
                onAction: () => context.push(AppRoutes.addCustomer),
              )
            : RefreshIndicator(
                onRefresh: () => ref.read(customerListProvider.notifier).refresh(),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _CustomerTile(customer: list[i]),
                ),
              ),
        loading: () => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: 6,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, __) => const _CustomerSkeleton(),
        ),
        error: (_, __) => const Center(child: Text('Failed to load customers')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.addCustomer),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Add Customer', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _CustomerTile extends StatelessWidget {
  final CustomerEntity customer;

  const _CustomerTile({required this.customer});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push('${AppRoutes.customers}/${customer.id}'),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: _getAvatarColor(customer.name),
            child: Text(
              customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customer.name, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                if (customer.gstin != null)
                  Text('GSTIN: ${customer.gstin}', style: Theme.of(context).textTheme.bodySmall),
                if (customer.phone != null)
                  Text(customer.phone!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${customer.invoiceCount} inv',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (customer.totalBusiness > 0)
                AmountText(amount: customer.totalBusiness, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: AppColors.textTertiaryLight, size: 20),
        ],
      ),
    );
  }

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFF2563EB), const Color(0xFF059669), const Color(0xFFDC2626),
      const Color(0xFF7C3AED), const Color(0xFFF59E0B), const Color(0xFF0891B2),
    ];
    return colors[name.length % colors.length];
  }
}

class _CustomerSkeleton extends StatelessWidget {
  const _CustomerSkeleton();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          const CircleAvatar(radius: 22, backgroundColor: Color(0xFFE2E8F0)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 14, width: 120, color: const Color(0xFFE2E8F0)),
                const SizedBox(height: 4),
                Container(height: 12, width: 80, color: const Color(0xFFE2E8F0)),
              ],
            ),
          ),
          Container(height: 12, width: 50, color: const Color(0xFFE2E8F0)),
        ],
      ),
    );
  }
}

