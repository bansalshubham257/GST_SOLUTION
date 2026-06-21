// lib/features/customer/presentation/pages/customer_detail_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../providers/customer_provider.dart';

class CustomerDetailPage extends ConsumerWidget {
  final String customerId;

  const CustomerDetailPage({super.key, required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(customerListProvider);
    final customer = customers.valueOrNull?.firstWhere(
      (c) => c.id == customerId,
      orElse: () => CustomerEntity(id: '', name: 'Unknown', createdAt: DateTime.now()),
    );

    if (customer == null || customer.id.isEmpty) {
      return Scaffold(appBar: AppBar(title: const Text('Customer')), body: const Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(customer.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'New Service',
            onPressed: () => context.push(AppRoutes.quickServiceEntry),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileCard(context, customer),
            const SizedBox(height: 16),
            _buildStatsRow(context, customer),
            const SizedBox(height: 16),
            SectionHeader(
              title: 'Visit History',
              actionLabel: 'New Service',
              onAction: () => context.push(AppRoutes.quickServiceEntry),
            ),
            const SizedBox(height: 8),
            const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No visits yet',
              subtitle: 'Add a service for this customer',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, CustomerEntity customer) {
    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.primarySurface,
                child: Text(
                  customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 22),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(customer.name, style: Theme.of(context).textTheme.headlineSmall, overflow: TextOverflow.ellipsis),
                    if (customer.gstin != null)
                      Text('GSTIN: ${customer.gstin}', style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (customer.phone != null) _infoRow(context, Icons.phone_outlined, customer.phone!),
          if (customer.email != null) _infoRow(context, Icons.email_outlined, customer.email!),
          if (customer.address != null) _infoRow(context, Icons.location_on_outlined, '${customer.address}${customer.city != null ? ', ${customer.city}' : ''}'),
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondaryLight),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, CustomerEntity customer) {
    return Row(
      children: [
        Expanded(child: StatCard(
          title: 'Visits',
          value: customer.invoiceCount.toString(),
          icon: Icons.receipt_long,
          iconColor: AppColors.primary,
          iconBgColor: AppColors.primarySurface,
        )),
        const SizedBox(width: 12),
        Expanded(child: StatCard(
          title: 'Total Business',
          value: '₹${_fmt(customer.totalBusiness)}',
          icon: Icons.trending_up,
          iconColor: AppColors.secondary,
          iconBgColor: AppColors.secondarySurface,
        )),
      ],
    );
  }

  String _fmt(double amount) {
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(0);
  }
}

