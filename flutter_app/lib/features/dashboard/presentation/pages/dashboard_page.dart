import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/ad_banner_widget.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../backup/data/services/backup_service.dart';
import '../../../backup/data/services/backup_settings_provider.dart';
import '../../../../features/settings/presentation/providers/feature_settings_provider.dart';
import '../../../invoice/presentation/providers/item_catalog_provider.dart';
import '../../../invoice/presentation/providers/item_settings_provider.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/recent_invoice_tile.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage>
    with WidgetsBindingObserver {
  bool _showPaymentBreakdown = false;
  bool _showPurchaseDetails = false;
  final Set<String> _dismissedAlerts = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDismissedAlerts();
  }

  void _loadDismissedAlerts() {
    // Load dismissed alerts from disk (stored with stock/expiry state)
    final box = LocalStorage.settingsBox;
    final list = box.get('dismissed_alerts', defaultValue: <String>[]) as List;
    _dismissedAlerts.addAll(list.cast<String>());
  }

  void _dismissAlert(String id, String stateKey) {
    final key = '$id|$stateKey';
    setState(() => _dismissedAlerts.add(key));
    final box = LocalStorage.settingsBox;
    final list = box.get('dismissed_alerts', defaultValue: <String>[]) as List;
    box.put('dismissed_alerts', [...list.cast<String>(), key]);
  }

  void _clearDismissedAlerts() {
    _dismissedAlerts.clear();
    LocalStorage.settingsBox.delete('dismissed_alerts');
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
      _tryAutoBackup();
    }
  }

  void _tryAutoBackup() {
    final settings = ref.read(backupSettingsProvider);
    if (settings.isDue) {
      BackupService.saveLocalBackup();
      ref.read(backupSettingsProvider.notifier).markBackupDone();
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
              _buildStockAlerts(),
              const SizedBox(height: 16),
              stats.when(
                data: (data) {
                  final features = ref.watch(featureSettingsProvider);
                  return Column(
                    children: [
                      _buildDailySummary(context, data),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _MetricCard(
                              label: 'Orders',
                              value: '${data.totalOrders}',
                              icon: Icons.receipt_long,
                              color: AppColors.secondary,
                              bgColor: AppColors.primarySurface,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MetricCard(
                              label: 'Pending Payments',
                              value: '${data.pendingPaymentCount}',
                              icon: Icons.pending_actions,
                              color: AppColors.warning,
                              bgColor: AppColors.warningLight,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MetricCard(
                              label: data.pendingPaymentAmount > 0 ? 'Due Amount' : 'No Dues',
                              value: data.pendingPaymentAmount > 0 ? '₹${_formatAmount(data.pendingPaymentAmount)}' : '₹0',
                              icon: Icons.currency_rupee,
                              color: data.pendingPaymentAmount > 0 ? AppColors.danger : AppColors.success,
                              bgColor: data.pendingPaymentAmount > 0 ? AppColors.dangerLight : AppColors.successLight,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (data.purchaseCount > 0 && features.showPurchases) ...[
                        const SizedBox(height: 16),
                        _buildPurchaseSummary(context, data),
                      ],
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: AppColors.textTertiaryLight),
                        const SizedBox(height: 12),
                        Text('Could not load dashboard data',
                            style: TextStyle(color: AppColors.textSecondaryLight)),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _refreshStats,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
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
              AdBannerWidget(),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStockAlerts() {
    final items = ref.watch(itemCatalogProvider);
    final itemSettings = ref.watch(itemSettingsProvider);
    final defaultThreshold = itemSettings.defaultLowStockThreshold;
    debugPrint('[StockAlerts] items=${items.length} settings={stock:${itemSettings.showStock}, alert:${itemSettings.showLowStockAlert}, threshold:$defaultThreshold}');
    for (final i in items) {
      debugPrint('[StockAlerts] item=${i.name} stock=${i.stock} threshold=${i.lowStockThreshold} isService=${i.isService} isOutOfStock=${i.isOutOfStock} isLowStock=${i.isLowStock}');
    }
    // Direct computation to catch any item needing attention
    final lowStock = items.where((i) {
      final dismissKey = 'stock_${i.id}|v${i.stock}';
      if (_dismissedAlerts.contains(dismissKey)) return false;
      if (i.isService) return false;
      if (i.stock == 0) return true;
      final threshold = i.lowStockThreshold ?? defaultThreshold;
      if (i.stock <= threshold) return true;
      return false;
    }).toList();
    final expired = items.where((i) {
      final dismissKey = 'expiry_${i.id}|v${i.expiryDate?.millisecondsSinceEpoch ?? 0}';
      return i.isExpired && !_dismissedAlerts.contains(dismissKey);
    }).toList();

    final trackable = items.where((i) => !i.isService && (i.stock > 0 || i.lowStockThreshold != null)).length;
    final totalNonService = items.where((i) => !i.isService).length;

    final alerts = <Widget>[];

    if (lowStock.isNotEmpty) {
      alerts.add(
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.inventory, size: 18, color: AppColors.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('${lowStock.length} item${lowStock.length > 1 ? 's' : ''} need attention',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      color: AppColors.textTertiaryLight,
                      onPressed: () {
                        for (final i in lowStock) _dismissAlert('stock_${i.id}', 'v${i.stock}');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...lowStock.take(3).map((i) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(i.stock == 0 ? Icons.error_outline : Icons.warning_amber_rounded,
                              size: 14, color: i.stock == 0 ? AppColors.danger : AppColors.warning),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text('${i.name} — ${i.stock == 0 ? "Out of stock" : "Stock: ${i.stock.toStringAsFixed(0)}"}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight))),
                          if (i.lowStockThreshold != null)
                            Text('min: ${i.lowStockThreshold!.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 10, color: AppColors.textTertiaryLight)),
                        ],
                      ),
                    )),
                if (lowStock.length > 3)
                  Text('+${lowStock.length - 3} more',
                      style: const TextStyle(fontSize: 11, color: AppColors.primary)),
              ],
            ),
          ),
        ),
      );
    }

    if (expired.isNotEmpty) {
      alerts.add(const SizedBox(height: 8));
      alerts.add(
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.event_busy, size: 18, color: AppColors.danger),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('${expired.length} item${expired.length > 1 ? 's' : ''} expired',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      color: AppColors.textTertiaryLight,
                      onPressed: () {
                        for (final i in expired) _dismissAlert('expiry_${i.id}', 'v${i.expiryDate?.millisecondsSinceEpoch ?? 0}');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...expired.take(3).map((i) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.block, size: 14, color: AppColors.danger),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(i.name,
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight))),
                          if (i.expiryDate != null)
                            Text('Exp: ${DateFormat('dd/MM/yy').format(i.expiryDate!)}',
                                style: const TextStyle(fontSize: 10, color: AppColors.textTertiaryLight)),
                        ],
                      ),
                    )),
                if (expired.length > 3)
                  Text('+${expired.length - 3} more',
                      style: const TextStyle(fontSize: 11, color: AppColors.primary)),
              ],
            ),
          ),
        ),
      );
    }

    // Always show a stock summary so the section is visible
    if (alerts.isEmpty) {
      alerts.add(
        AppCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, size: 16, color: AppColors.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('$totalNonService items · $trackable tracked  —  all stocked',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(children: alerts);
  }

  Widget _buildDailySummary(BuildContext context, DashboardStats data) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: "Today's Sales",
                value: '₹${_formatAmount(data.todaySales)}',
                icon: Icons.today,
                color: AppColors.primary,
                bgColor: AppColors.primarySurface,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                label: 'Gross Profit',
                value: '₹${_formatAmount(data.grossProfit)}',
                icon: data.grossProfit >= 0 ? Icons.trending_up : Icons.trending_down,
                color: data.grossProfit >= 0 ? AppColors.success : AppColors.danger,
                bgColor: data.grossProfit >= 0 ? AppColors.successLight : const Color(0xFFFEF2F2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                label: 'Tax Liability',
                value: '₹${_formatAmount(data.netTaxLiability)}',
                icon: data.netTaxLiability >= 0 ? Icons.account_balance : Icons.arrow_downward,
                color: data.netTaxLiability >= 0 ? AppColors.info : AppColors.success,
                bgColor: data.netTaxLiability >= 0 ? AppColors.infoLight : AppColors.successLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Customers',
                value: '${data.customerCount}',
                icon: Icons.people,
                color: AppColors.info,
                bgColor: AppColors.infoLight,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                label: 'Staff',
                value: '${data.staffCount}',
                icon: Icons.badge,
                color: AppColors.secondary,
                bgColor: AppColors.secondarySurface,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                label: 'GST Collected',
                value: '₹${_formatAmount(data.totalGstCollected)}',
                icon: Icons.account_balance,
                color: AppColors.warning,
                bgColor: AppColors.warningLight,
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
                InkWell(
                  onTap: () => setState(() => _showPaymentBreakdown = !_showPaymentBreakdown),
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Sales',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('₹${_formatAmount(data.totalSales)}',
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
                          const SizedBox(width: 8),
                          AnimatedRotation(
                            turns: _showPaymentBreakdown ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: const Icon(Icons.expand_more, color: AppColors.textTertiaryLight, size: 20),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Text('${data.invoiceCount} transactions',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                            const Spacer(),
                          ],
                        ),
                        const SizedBox(height: 12),
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
                                  style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight)),
                              Text('₹${_formatAmount(data.totalGstCollected)}',
                                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
                            ],
                          ),
                        ],
                        if (data.costOfGoodsSold > 0) ...[
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Cost of Goods Sold',
                                  style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight)),
                              Text('₹${_formatAmount(data.costOfGoodsSold)}',
                                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondaryLight)),
                            ],
                          ),
                        ],
                        if (data.totalDiscounts > 0) ...[
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Discounts',
                                  style: TextStyle(fontSize: 13, color: AppColors.danger)),
                              Text('-₹${_formatAmount(data.totalDiscounts)}',
                                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.danger)),
                            ],
                          ),
                        ],
                        if (data.totalExpenses > 0) ...[
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Expenses',
                                  style: TextStyle(fontSize: 13, color: AppColors.danger)),
                              Text('₹${_formatAmount(data.totalExpenses)}',
                                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.danger)),
                            ],
                          ),
                        ],
                        if (data.totalCommission > 0) ...[
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Commission',
                                  style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight)),
                              Text('₹${_formatAmount(data.totalCommission)}',
                                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondaryLight)),
                            ],
                          ),
                        ],
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Net Profit before Tax',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                            Text('₹${_formatAmount(data.grossProfit - data.totalExpenses - data.totalCommission)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: (data.grossProfit - data.totalExpenses - data.totalCommission) >= 0
                                      ? AppColors.success
                                      : AppColors.danger,
                                )),
                          ],
                        ),
                        if (data.incomeTax > 0) ...[
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Income Tax (estimated @ 10%)',
                                  style: TextStyle(fontSize: 13, color: AppColors.warning)),
                              Text('-₹${_formatAmount(data.incomeTax)}',
                                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.warning)),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Net Profit After Tax',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                              Text('₹${_formatAmount(data.grossProfit - data.totalExpenses - data.totalCommission - data.incomeTax)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: (data.grossProfit - data.totalExpenses - data.totalCommission - data.incomeTax) >= 0
                                        ? AppColors.success
                                        : AppColors.danger,
                                  )),
                            ],
                          ),
                        ],
                        if (data.pendingPaymentAmount > 0) ...[
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${data.pendingPaymentCount} Pending Payments',
                                  style: const TextStyle(fontSize: 13, color: AppColors.warning)),
                              Text('₹${_formatAmount(data.pendingPaymentAmount)}',
                                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.warning)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  crossFadeState: _showPaymentBreakdown ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 250),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPurchaseSummary(BuildContext context, DashboardStats data) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => _showPurchaseDetails = !_showPurchaseDetails),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.shopping_cart_outlined, color: AppColors.primary, size: 20),
                      SizedBox(width: 8),
                      Text('Purchase Summary', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('₹${_formatAmount(data.totalPurchases)}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimaryLight)),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: _showPurchaseDetails ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(Icons.expand_more, color: AppColors.textTertiaryLight, size: 20),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text('${data.purchaseCount} purchases',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                        if (data.pendingPurchaseAmount > 0) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.warningLight, borderRadius: BorderRadius.circular(12)),
                            child: Text('₹${_formatAmount(data.pendingPurchaseAmount)} pending',
                                style: const TextStyle(fontSize: 10, color: AppColors.warning, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('GST on Purchases', style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                              const SizedBox(height: 4),
                              Text('₹${_formatAmount(data.purchaseGst)}',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary)),
                            ],
                          ),
                        ),
                        if (data.pendingPurchaseAmount > 0)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Pending Payment', style: TextStyle(fontSize: 12, color: AppColors.warning)),
                                const SizedBox(height: 4),
                                Text('₹${_formatAmount(data.pendingPurchaseAmount)}',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.warning)),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      label: 'View All Purchases',
                      isOutlined: true,
                      icon: Icons.shopping_cart_outlined,
                      onPressed: () => context.push(AppRoutes.purchases),
                    ),
                  ],
                ),
              ),
              crossFadeState: _showPurchaseDetails ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final features = ref.watch(featureSettingsProvider);
    final row1 = <Widget>[
      Expanded(
        child: _ActionButton(
          label: 'New Sale',
          icon: Icons.add_shopping_cart,
          color: AppColors.primary,
          onTap: () => context.push(AppRoutes.quickServiceEntry),
        ),
      ),
      if (features.showExpenses) ...[
        const SizedBox(width: 10),
        Expanded(
          child: _ActionButton(
            label: 'Add Expense',
            icon: Icons.outbound,
            color: AppColors.danger,
            onTap: () => context.push(AppRoutes.addExpense),
          ),
        ),
      ],
      if (features.showItems) ...[
        const SizedBox(width: 10),
        Expanded(
          child: _ActionButton(
            label: 'Items',
            icon: Icons.inventory_2,
            color: AppColors.secondary,
            onTap: () => context.push(AppRoutes.serviceCatalog),
          ),
        ),
      ],
    ];
    final row2 = <Widget>[
      Expanded(
        child: _ActionButton(
          label: 'Customers',
          icon: Icons.people,
          color: AppColors.info,
          onTap: () => context.push(AppRoutes.customers),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _ActionButton(
          label: 'Staff',
          icon: Icons.badge,
          color: AppColors.secondary,
          onTap: () => context.push(AppRoutes.staff),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _ActionButton(
          label: 'GST',
          icon: Icons.account_balance,
          color: AppColors.warning,
          onTap: () => context.push(AppRoutes.gst),
        ),
      ),
    ];

    return Column(
      children: [
        Row(children: row1),
        const SizedBox(height: 10),
        Row(children: row2),
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
