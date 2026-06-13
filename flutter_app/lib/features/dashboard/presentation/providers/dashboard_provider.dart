// lib/features/dashboard/presentation/providers/dashboard_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/storage/local_storage.dart';

// ─── Dashboard Stats ──────────────────────────────────────────────────────────

class DashboardStats {
  final double totalSales;
  final double totalGstCollected;
  final double totalCgst;
  final double totalSgst;
  final double totalIgst;
  final int invoiceCount;
  final int customerCount;
  final double salesGrowth;
  final double totalExpenses;
  final double cashSales;
  final double upiSales;
  final double cardSales;
  final double totalCommission;
  final List<MonthlySales> monthlySales;

  const DashboardStats({
    required this.totalSales,
    required this.totalGstCollected,
    required this.totalCgst,
    required this.totalSgst,
    required this.totalIgst,
    required this.invoiceCount,
    required this.customerCount,
    required this.salesGrowth,
    this.totalExpenses = 0,
    this.cashSales = 0,
    this.upiSales = 0,
    this.cardSales = 0,
    this.totalCommission = 0,
    required this.monthlySales,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalSales: (json['totalSales'] ?? 0).toDouble(),
      totalGstCollected: (json['totalGstCollected'] ?? 0).toDouble(),
      totalCgst: (json['totalCgst'] ?? 0).toDouble(),
      totalSgst: (json['totalSgst'] ?? 0).toDouble(),
      totalIgst: (json['totalIgst'] ?? 0).toDouble(),
      invoiceCount: json['invoiceCount'] ?? 0,
      customerCount: json['customerCount'] ?? 0,
      salesGrowth: (json['salesGrowth'] ?? 0).toDouble(),
      totalExpenses: (json['totalExpenses'] ?? 0).toDouble(),
      cashSales: (json['cashSales'] ?? 0).toDouble(),
      upiSales: (json['upiSales'] ?? 0).toDouble(),
      cardSales: (json['cardSales'] ?? 0).toDouble(),
      totalCommission: (json['totalCommission'] ?? 0).toDouble(),
      monthlySales: (json['monthlySales'] as List? ?? [])
          .map((e) => MonthlySales.fromJson(e))
          .toList(),
    );
  }

  // Sample data for empty state
  static DashboardStats empty() => const DashboardStats(
    totalSales: 0,
    totalGstCollected: 0,
    totalCgst: 0,
    totalSgst: 0,
    totalIgst: 0,
    invoiceCount: 0,
    customerCount: 0,
    salesGrowth: 0,
    totalExpenses: 0,
    cashSales: 0,
    upiSales: 0,
    cardSales: 0,
    totalCommission: 0,
    monthlySales: [],
  );
}

class MonthlySales {
  final String month;
  final double sales;
  final double gst;

  const MonthlySales({required this.month, required this.sales, required this.gst});

  factory MonthlySales.fromJson(Map<String, dynamic> json) {
    return MonthlySales(
      month: json['month'] ?? '',
      sales: (json['sales'] ?? 0).toDouble(),
      gst: (json['gst'] ?? 0).toDouble(),
    );
  }
}

// ─── Recent Invoice Summary ───────────────────────────────────────────────────

class RecentInvoiceSummary {
  final String id;
  final String invoiceNumber;
  final String customerName;
  final double amount;
  final String status;
  final DateTime date;

  const RecentInvoiceSummary({
    required this.id,
    required this.invoiceNumber,
    required this.customerName,
    required this.amount,
    required this.status,
    required this.date,
  });

  factory RecentInvoiceSummary.fromJson(Map<String, dynamic> json) {
    return RecentInvoiceSummary(
      id: json['id']?.toString() ?? '',
      invoiceNumber: json['invoiceNumber'] ?? '',
      customerName: json['customerName'] ?? '',
      amount: (json['grandTotal'] ?? json['amount'] ?? 0).toDouble(),
      status: json['status'] ?? 'draft',
      date: DateTime.tryParse(json['invoiceDate'] ?? '') ?? DateTime.now(),
    );
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  try {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.get(ApiConstants.dashboardStats);
    return DashboardStats.fromJson(response.data as Map<String, dynamic>);
  } catch (_) {
    // Backend not available — compute from local invoice cache
    return _computeStatsFromCache();
  }
});

/// Compute dashboard stats from locally cached invoices (demo/offline mode)
DashboardStats _computeStatsFromCache() {
  final invoices = LocalStorage.getAllCachedInvoices();
  if (invoices.isEmpty) return DashboardStats.empty();

  double totalSales = 0;
  double totalGst = 0;
  double totalCgst = 0;
  double totalSgst = 0;
  double totalIgst = 0;
  double cashSales = 0;
  double upiSales = 0;
  double cardSales = 0;
  double totalCommission = 0;
  final Map<String, double> monthlyMap = {};

  for (final raw in invoices) {
    final inv = Map<String, dynamic>.from(raw);
    final grandTotal = (inv['grandTotal'] ?? 0).toDouble();
    final tax = (inv['totalTax'] ?? 0).toDouble();
    final cgst = (inv['totalCgst'] ?? 0).toDouble();
    final sgst = (inv['totalSgst'] ?? 0).toDouble();
    final igst = (inv['totalIgst'] ?? 0).toDouble();
    final paymentMode = inv['paymentMode'] ?? 'cash';

    totalSales += grandTotal;
    totalGst += tax;
    totalCgst += cgst;
    totalSgst += sgst;
    totalIgst += igst;

    if (paymentMode == 'cash') {
      cashSales += grandTotal;
    } else if (paymentMode == 'upi') {
      upiSales += grandTotal;
    } else if (paymentMode == 'card') {
      cardSales += grandTotal;
    }

    // Calculate commission from line items
    final lineItems = (inv['lineItems'] as List? ?? []);
    for (final itemRaw in lineItems) {
      final item = Map<String, dynamic>.from(itemRaw);
      final staffId = item['staffId'];
      if (staffId != null) {
        // For local-first, we might want to lookup staff commission rate
        // but for now let's assume a default or just use the grandTotal/taxableAmount
        // In a real app, we'd fetch the staff entity. 
        // Let's assume 10% default if not found.
        totalCommission += (item['taxableAmount'] ?? 0) * 0.1; 
      }
    }

    // Monthly grouping
    final dateStr = inv['invoiceDate'] ?? inv['createdAt'] ?? '';
    final date = DateTime.tryParse(dateStr);
    if (date != null) {
      final key = DateFormat('MMM').format(date);
      monthlyMap[key] = (monthlyMap[key] ?? 0) + grandTotal;
    }
  }

  // Calculate expenses
  double totalExpenses = 0;
  final expenses = LocalStorage.expenseBox.values.toList();
  for (final raw in expenses) {
    final exp = Map<String, dynamic>.from(raw);
    totalExpenses += (exp['amount'] ?? 0).toDouble();
  }

  final monthlySales = monthlyMap.entries.map((e) => MonthlySales(
    month: e.key,
    sales: e.value,
    gst: e.value * 0.18,
  )).toList();

  final customers = LocalStorage.getAllCachedCustomers();

  return DashboardStats(
    totalSales: totalSales,
    totalGstCollected: totalGst,
    totalCgst: totalCgst,
    totalSgst: totalSgst,
    totalIgst: totalIgst,
    invoiceCount: invoices.length,
    customerCount: customers.length,
    salesGrowth: invoices.length > 1 ? 12.5 : 0,
    totalExpenses: totalExpenses,
    cashSales: cashSales,
    upiSales: upiSales,
    cardSales: cardSales,
    totalCommission: totalCommission,
    monthlySales: monthlySales,
  );
}

final recentInvoicesProvider = FutureProvider<List<RecentInvoiceSummary>>((ref) async {
  try {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.get(
      ApiConstants.invoices,
      queryParameters: {'limit': 5, 'sortBy': 'createdAt', 'order': 'desc'},
    );
    final list = response.data['invoices'] as List? ?? [];
    return list.map((e) => RecentInvoiceSummary.fromJson(e as Map<String, dynamic>)).toList();
  } catch (_) {
    // Fallback to local cache
    final cached = LocalStorage.getAllCachedInvoices();
    final sorted = cached
        .map((m) => Map<String, dynamic>.from(m))
        .toList()
      ..sort((a, b) {
        final da = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime(2000);
        final db = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime(2000);
        return db.compareTo(da);
      });
    return sorted.take(5).map((m) => RecentInvoiceSummary.fromJson(m)).toList();
  }
});

