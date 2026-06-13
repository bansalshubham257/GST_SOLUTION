import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../providers/staff_provider.dart';
import '../../domain/entities/staff_entity.dart';

class StaffListPage extends ConsumerWidget {
  const StaffListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffList = ref.watch(staffListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Staff Performance',
            onPressed: () => _showPerformanceSheet(context, ref),
          ),
        ],
      ),
      body: staffList.when(
        data: (staff) => staff.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.people_outline,
                        size: 64, color: AppColors.textTertiaryLight),
                    const SizedBox(height: 16),
                    const Text('No staff members yet',
                        style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondaryLight)),
                    const SizedBox(height: 8),
                    const Text('Add your staff to track commissions',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textTertiaryLight)),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () => context.push(AppRoutes.addStaff),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Staff'),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: staff.length,
                itemBuilder: (context, index) {
                  final member = staff[index];
                  final initials = member.name.isNotEmpty
                      ? member.name[0].toUpperCase()
                      : '?';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      onTap: () => context.push(AppRoutes.staff + '/edit',
                          extra: member),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: AppColors.primarySurface,
                            child: Text(initials,
                                style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(member.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16)),
                                const SizedBox(height: 2),
                                Text(
                                  member.role ?? 'Staff',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondaryLight),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.accentSurface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${member.commissionPercentage.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accentDark,
                                  fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('₹${_fmt(member.totalRevenue)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: AppColors.primary)),
                              Text('rev',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textTertiaryLight)),
                            ],
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right,
                              color: AppColors.textTertiaryLight, size: 18),
                        ],
                      ),
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.addStaff),
        label: const Text('Add Staff'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  void _showPerformanceSheet(BuildContext context, WidgetRef ref) {
    final staff = ref.read(staffListProvider).valueOrNull ?? [];
    if (staff.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StaffPerformanceSheet(staff: staff),
    );
  }

  String _fmt(double amount) {
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(0);
  }
}

class _StaffPerformanceSheet extends StatelessWidget {
  final List<StaffEntity> staff;

  const _StaffPerformanceSheet({required this.staff});

  @override
  Widget build(BuildContext context) {
    final sorted = List<StaffEntity>.from(staff)
      ..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Staff Performance',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Revenue generated by each staff member',
              style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondaryLight)),
          const SizedBox(height: 20),
          ...sorted.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(s.name,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.primarySurface,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: sorted.first.totalRevenue > 0
                                  ? (s.totalRevenue / sorted.first.totalRevenue)
                                      .clamp(0.05, 1.0)
                                  : 0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('₹${_fmt(s.totalRevenue)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.primary)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  String _fmt(double amount) {
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(0);
  }
}
