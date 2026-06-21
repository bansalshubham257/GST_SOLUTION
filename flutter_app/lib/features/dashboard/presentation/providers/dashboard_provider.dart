// lib/features/dashboard/presentation/providers/dashboard_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/storage/local_storage.dart';

// ─── Dashboard Stats ──────────────────────────────────────────────────────────

class DashboardStats {
  final double todaySales;
  final double totalSales;
  final double totalGstCollected;
  final double totalCgst;
  final double totalSgst;
  final double totalIgst;
  final int invoiceCount;
  final int totalOrders;
  final double pendingPaymentAmount;
  final int pendingPaymentCount;
  final int customerCount;
  final int productCount;
  final int staffCount;
  final double salesGrowth;
  final double totalExpenses;
  final double cashSales;
  final double upiSales;
  final double cardSales;
  final double totalCommission;
  final double costOfGoodsSold;
  final double grossProfit;
  final double netTaxLiability;
  final List<MonthlySales> monthlySales;
  final double totalPurchases;
  final double purchaseGst;
  final double pendingPurchaseAmount;
  final int purchaseCount;
  final double totalTaxableRevenue;
  final double totalDiscounts;
  final double incomeTax;

  const DashboardStats({
    this.todaySales = 0,
    required this.totalSales,
    required this.totalGstCollected,
    required this.totalCgst,
    required this.totalSgst,
    required this.totalIgst,
    required this.invoiceCount,
    this.totalOrders = 0,
    this.pendingPaymentAmount = 0,
    this.pendingPaymentCount = 0,
    required this.customerCount,
    this.productCount = 0,
    this.staffCount = 0,
    required this.salesGrowth,
    this.totalExpenses = 0,
    this.cashSales = 0,
    this.upiSales = 0,
    this.cardSales = 0,
    this.totalCommission = 0,
    this.costOfGoodsSold = 0,
    this.grossProfit = 0,
    this.netTaxLiability = 0,
    required this.monthlySales,
    this.totalPurchases = 0,
    this.purchaseGst = 0,
    this.pendingPurchaseAmount = 0,
    this.purchaseCount = 0,
    this.totalTaxableRevenue = 0,
    this.totalDiscounts = 0,
    this.incomeTax = 0,
  });

  static DashboardStats empty() => const DashboardStats(
    totalSales: 0,
    totalGstCollected: 0,
    totalCgst: 0,
    totalSgst: 0,
    totalIgst: 0,
    invoiceCount: 0,
    customerCount: 0,
    salesGrowth: 0,
    monthlySales: [],
    incomeTax: 0,
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
  final String paymentStatus;
  final DateTime date;

  const RecentInvoiceSummary({
    required this.id,
    required this.invoiceNumber,
    required this.customerName,
    required this.amount,
    required this.status,
    this.paymentStatus = 'paid',
    required this.date,
  });

  factory RecentInvoiceSummary.fromJson(Map<String, dynamic> json) {
    return RecentInvoiceSummary(
      id: json['id']?.toString() ?? '',
      invoiceNumber: json['invoiceNumber'] ?? '',
      customerName: json['customerName'] ?? '',
      amount: (json['grandTotal'] ?? json['amount'] ?? 0).toDouble(),
      status: json['status'] ?? 'draft',
      paymentStatus: json['paymentStatus'] ?? 'paid',
      date: DateTime.tryParse(json['invoiceDate'] ?? '') ?? DateTime.now(),
    );
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  try {
    return _computeStatsFromCache();
  } catch (e, st) {
    print('[DashboardStats] error: $e\n$st');
    return DashboardStats.empty();
  }
});

/// Compute dashboard stats from locally cached Hive data
DashboardStats _computeStatsFromCache() {
  final invoices = LocalStorage.getAllCachedInvoices();
  if (invoices.isEmpty) return DashboardStats.empty();

  double todaySales = 0;
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
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);

  for (final raw in invoices) {
    final inv = Map<String, dynamic>.from(raw);
    final grandTotal = (inv['grandTotal'] ?? 0).toDouble();
    final tax = (inv['totalTax'] ?? 0).toDouble();
    final cgst = (inv['totalCgst'] ?? 0).toDouble();
    final sgst = (inv['totalSgst'] ?? 0).toDouble();
    final igst = (inv['totalIgst'] ?? 0).toDouble();
    final paymentMode = inv['paymentMode'] ?? 'cash';
    final dateStr = inv['invoiceDate'] ?? inv['createdAt'] ?? '';

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

    final date = DateTime.tryParse(dateStr);
    if (date != null) {
      if (date.isAfter(todayStart.subtract(const Duration(days: 1)))) {
        todaySales += grandTotal;
      }
      final key = DateFormat('MMM').format(date);
      monthlyMap[key] = (monthlyMap[key] ?? 0) + grandTotal;
    }

    // Commission from line items with staffId
    final lineItems = (inv['lineItems'] as List? ?? []);
    for (final itemRaw in lineItems) {
      final item = Map<String, dynamic>.from(itemRaw);
      if (item['staffId'] != null) {
        totalCommission += (item['taxableAmount'] ?? 0) * 0.1;
      }
    }
  }

  double totalExpenses = 0;
  double pendingPaymentAmount = 0;
  int pendingPaymentCount = 0;
  int totalOrders = 0;
  List<Map<String, dynamic>> expenseList = [];
  final expenses = LocalStorage.expenseBox.values.toList();
  for (final raw in expenses) {
    final exp = Map<String, dynamic>.from(raw);
    totalExpenses += (exp['amount'] ?? 0).toDouble();
    expenseList.add(exp);
  }

  // Cost of Goods Sold: match line items to catalog items by description
  final catalogItems = LocalStorage.getAllItemCatalog();
  double costOfGoodsSold = 0;
  for (final raw in invoices) {
    final inv = Map<String, dynamic>.from(raw);
    final lineItems = (inv['lineItems'] as List? ?? []);
    for (final itemRaw in lineItems) {
      final item = Map<String, dynamic>.from(itemRaw);
      final description = (item['description'] ?? '').toString().trim();
      final qty = (item['quantity'] ?? 0).toDouble();
      if (description.isEmpty || qty == 0) continue;
      // match by description (case-insensitive)
      final match = catalogItems
          .map((e) => Map<String, dynamic>.from(e))
          .firstWhere(
        (c) => (c['name'] ?? '').toString().trim().toLowerCase() == description.toLowerCase(),
        orElse: () => <String, dynamic>{},
      );
      if (match.isNotEmpty) {
        final purchasePrice = (match['purchasePrice'] ?? 0).toDouble();
        costOfGoodsSold += purchasePrice * qty;
      }
    }
  }

  final monthlySales = monthlyMap.entries.map((e) => MonthlySales(
    month: e.key,
    sales: e.value,
    gst: e.value * 0.18,
  )).toList();

  // Count pending payments & total orders from invoices
  for (final raw in invoices) {
    final inv = Map<String, dynamic>.from(raw);
    final ps = (inv['paymentStatus'] ?? 'paid') as String;
    if (ps == 'unpaid') {
      pendingPaymentAmount += (inv['grandTotal'] ?? 0).toDouble();
      pendingPaymentCount++;
    }
    final status = (inv['status'] ?? '') as String;
    if (status != 'cancelled' && status != 'draft') {
      totalOrders++;
    }
  }

  final customers = LocalStorage.getAllCachedCustomers();
  final products = LocalStorage.getAllItemCatalog();
  final staffCount = LocalStorage.staffBox.values.length;

  double totalPurchases = 0;
  double purchaseGst = 0;
  double pendingPurchaseAmount = 0;
  int purchaseCount = 0;
  final purchases = LocalStorage.getAllCachedPurchases();
  for (final raw in purchases) {
    final pur = Map<String, dynamic>.from(raw);
    final status = (pur['status'] ?? '') as String;
    if (status == 'cancelled') continue;
    totalPurchases += (pur['grandTotal'] ?? 0).toDouble();
    purchaseGst += (pur['totalTax'] ?? 0).toDouble();
    purchaseCount++;
    final paymentStatus = (pur['paymentStatus'] ?? 'unpaid') as String;
    if (paymentStatus == 'unpaid') {
      pendingPurchaseAmount += (pur['grandTotal'] ?? 0).toDouble();
    }
  }

  double totalTaxableRevenue = 0;
  double totalDiscounts = 0;
  for (final raw in invoices) {
    final inv = Map<String, dynamic>.from(raw);
    totalTaxableRevenue += (inv['subTotal'] ?? inv['grandTotal'] ?? 0).toDouble();
    totalDiscounts += (inv['discountAmount'] ?? 0).toDouble();
  }

  final netProfitBeforeTax = (totalTaxableRevenue - totalDiscounts) - costOfGoodsSold - totalExpenses - totalCommission;
  final incomeTax = netProfitBeforeTax > 0 ? netProfitBeforeTax * 0.10 : 0.0;

  return DashboardStats(
    todaySales: todaySales,
    totalSales: totalSales,
    totalGstCollected: totalGst,
    totalCgst: totalCgst,
    totalSgst: totalSgst,
    totalIgst: totalIgst,
    invoiceCount: invoices.length,
    totalOrders: totalOrders,
    pendingPaymentAmount: pendingPaymentAmount,
    pendingPaymentCount: pendingPaymentCount,
    customerCount: customers.length,
    productCount: products.length,
    staffCount: staffCount,
    salesGrowth: invoices.length > 1 ? 12.5 : 0,
    totalExpenses: totalExpenses,
    cashSales: cashSales,
    upiSales: upiSales,
    cardSales: cardSales,
    totalCommission: totalCommission,
    costOfGoodsSold: costOfGoodsSold,
    grossProfit: (totalTaxableRevenue - totalDiscounts) - costOfGoodsSold,
    incomeTax: incomeTax,
    netTaxLiability: totalGst - purchaseGst,
    monthlySales: monthlySales,
    totalPurchases: totalPurchases,
    purchaseGst: purchaseGst,
    pendingPurchaseAmount: pendingPurchaseAmount,
    purchaseCount: purchaseCount,
    totalTaxableRevenue: totalTaxableRevenue,
    totalDiscounts: totalDiscounts,
  );
}

final recentInvoicesProvider = FutureProvider<List<RecentInvoiceSummary>>((ref) async {
  try {
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
  } catch (e) {
    return [];
  }
});

