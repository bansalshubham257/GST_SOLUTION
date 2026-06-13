import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/recent_invoice_tile.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshStats();
    }
  }

  void _refreshStats() {
    ref.invalidate(dashboardStatsProvider);
    ref.invalidate(recentInvoicesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(dashboardStatsProvider);
    final recentInvoices = ref.watch(recentInvoicesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Daily Register',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text(DateFormat('EEEE, dd MMM').format(DateTime.now()),
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryLight,
                    fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Service History',
            onPressed: () => context.push(AppRoutes.serviceHistory),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refreshStats(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              stats.when(
                data: (data) => _buildDailySummary(context, data),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => _buildOfflineBanner(),
              ),
              const SizedBox(height: 20),
              _buildQuickActions(context),
              const SizedBox(height: 24),
              _buildGstCollectionCard(),
              const SizedBox(height: 16),
              _buildGstHealthCard(),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recent Transactions',
                      style: Theme.of(context).textTheme.titleMedium),
                  TextButton.icon(
                    onPressed: () => context.push(AppRoutes.serviceHistory),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('View All'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              recentInvoices.when(
                data: (invoices) => invoices.isEmpty
                    ? const Center(
                        child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Column(
                              children: [
                                Icon(Icons.receipt_long_outlined,
                                    size: 48,
                                    color: AppColors.textTertiaryLight),
                                SizedBox(height: 8),
                                Text('No transactions today',
                                    style: TextStyle(
                                        color: AppColors.textSecondaryLight)),
                              ],
                            )))
                    : Column(
                        children: invoices
                            .map((inv) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: RecentInvoiceTile(invoice: inv),
                                ))
                            .toList(),
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.cloud_off, color: AppColors.warning),
            const SizedBox(width: 12),
            const Expanded(
                child: Text('Offline — showing cached data',
                    style: TextStyle(color: AppColors.textSecondaryLight))),
            TextButton(
              onPressed: _refreshStats,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailySummary(BuildContext context, DashboardStats data) {
    final profit = data.totalSales - data.totalExpenses - data.totalCommission;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: "Today's Sales",
                value: '₹${_formatAmount(data.totalSales)}',
                icon: Icons.today,
                color: AppColors.primary,
                bgColor: AppColors.primarySurface,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                label: 'Expenses',
                value: '₹${_formatAmount(data.totalExpenses)}',
                icon: Icons.outbound,
                color: AppColors.danger,
                bgColor: AppColors.dangerLight,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                label: 'Profit',
                value: '₹${_formatAmount(profit < 0 ? 0 : profit)}',
                icon: Icons.trending_up,
                color: AppColors.success,
                bgColor: AppColors.successLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Payment Breakdown',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    Text('${data.invoiceCount} transactions',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryLight)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _PaymentBar(
                        label: 'Cash',
                        amount: data.cashSales,
                        total: data.totalSales,
                        color: const Color(0xFF059669)),
                    const SizedBox(width: 8),
                    _PaymentBar(
                        label: 'UPI',
                        amount: data.upiSales,
                        total: data.totalSales,
                        color: Colors.blue),
                    const SizedBox(width: 8),
                    _PaymentBar(
                        label: 'Card',
                        amount: data.cardSales,
                        total: data.totalSales,
                        color: AppColors.secondary),
                  ],
                ),
                if (data.totalGstCollected > 0) ...[
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('GST Collected',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondaryLight)),
                      Text('₹${_formatAmount(data.totalGstCollected)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            label: 'New Service',
            icon: Icons.content_cut,
            color: AppColors.primary,
            onTap: () => context.push(AppRoutes.quickServiceEntry),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionButton(
            label: 'Add Expense',
            icon: Icons.outbound,
            color: AppColors.danger,
            onTap: () => context.push(AppRoutes.addExpense),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionButton(
            label: 'Manage Services',
            icon: Icons.inventory_2,
            color: AppColors.secondary,
            onTap: () => context.push(AppRoutes.serviceCatalog),
          ),
        ),
      ],
    );
  }

  Widget _buildGstCollectionCard() {
    final stats = ref.watch(dashboardStatsProvider).valueOrNull;
    if (stats == null || stats.totalGstCollected == 0) return const SizedBox.shrink();

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.account_balance_rounded,
                      color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('GST Collected Today',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                ),
                Text('₹${_formatAmount(stats.totalGstCollected)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.primary)),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                _gstLine('CGST', stats.totalCgst),
                _gstLine('SGST', stats.totalSgst),
                _gstLine('IGST', stats.totalIgst),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _gstLine(String label, double amount) {
    return Expanded(
      child: Column(
        children: [
          Text('₹${_formatAmount(amount)}',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondaryLight)),
        ],
      ),
    );
  }

  Widget _buildGstHealthCard() {
    final stats = ref.watch(dashboardStatsProvider).valueOrNull;
    if (stats == null || stats.totalGstCollected == 0) {
      return const SizedBox.shrink();
    }

    final gstRatio = stats.totalGstCollected / stats.totalSales;
    final healthStatus = gstRatio > 0.15
        ? 'Good'
        : gstRatio > 0.05
            ? 'Review'
            : 'Low';

    return AppCard(
      onTap: () => context.push(AppRoutes.reports),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: healthStatus == 'Good'
                    ? AppColors.successLight
                    : AppColors.warningLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                healthStatus == 'Good'
                    ? Icons.verified
                    : Icons.info_outline,
                color: healthStatus == 'Good'
                    ? AppColors.success
                    : AppColors.warning,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('GST Health: $healthStatus',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(
                      '${_formatAmount(stats.totalGstCollected)} collected on ${_formatAmount(stats.totalSales)} sales',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryLight)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textTertiaryLight),
          ],
        ),
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 10000000) return '${(amount / 10000000).toStringAsFixed(1)}Cr';
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(0);
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondaryLight)),
        ],
      ),
    );
  }
}

class _PaymentBar extends StatelessWidget {
  final String label;
  final double amount;
  final double total;
  final Color color;

  const _PaymentBar({
    required this.label,
    required this.amount,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (amount / total * 100) : 0.0;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text('${pct.toStringAsFixed(0)}%',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: color)),
            const SizedBox(height: 2),
            Text('₹${amount.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondaryLight)),
            const SizedBox(height: 2),
            Container(
              height: 4,
              width: double.infinity,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: pct / 100,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
