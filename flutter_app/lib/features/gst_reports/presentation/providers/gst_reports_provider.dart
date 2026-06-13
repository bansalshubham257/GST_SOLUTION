// lib/features/gst_reports/presentation/providers/gst_reports_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/storage/local_storage.dart';

class GstMonthlySummary {
  final DateTime month;
  final double totalTaxable;
  final double totalCgst;
  final double totalSgst;
  final double totalIgst;
  final double totalCess;
  final double totalTax;
  final int invoiceCount;
  final List<GstSlabSummaryData> slabSummaries;

  const GstMonthlySummary({
    required this.month,
    required this.totalTaxable,
    required this.totalCgst,
    required this.totalSgst,
    required this.totalIgst,
    required this.totalCess,
    required this.totalTax,
    required this.invoiceCount,
    required this.slabSummaries,
  });

  factory GstMonthlySummary.fromJson(Map<String, dynamic> json) {
    return GstMonthlySummary(
      month: DateTime.tryParse(json['month'] ?? '') ?? DateTime.now(),
      totalTaxable: (json['totalTaxable'] ?? 0).toDouble(),
      totalCgst: (json['totalCgst'] ?? 0).toDouble(),
      totalSgst: (json['totalSgst'] ?? 0).toDouble(),
      totalIgst: (json['totalIgst'] ?? 0).toDouble(),
      totalCess: (json['totalCess'] ?? 0).toDouble(),
      totalTax: (json['totalTax'] ?? 0).toDouble(),
      invoiceCount: json['invoiceCount'] ?? 0,
      slabSummaries: (json['slabSummaries'] as List? ?? [])
          .map((e) => GstSlabSummaryData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  static GstMonthlySummary empty(DateTime month) => GstMonthlySummary(
    month: month,
    totalTaxable: 0,
    totalCgst: 0,
    totalSgst: 0,
    totalIgst: 0,
    totalCess: 0,
    totalTax: 0,
    invoiceCount: 0,
    slabSummaries: [],
  );
}

class GstSlabSummaryData {
  final double rate;
  final double taxableAmount;
  final double cgst;
  final double sgst;
  final double igst;

  const GstSlabSummaryData({
    required this.rate,
    required this.taxableAmount,
    required this.cgst,
    required this.sgst,
    required this.igst,
  });

  factory GstSlabSummaryData.fromJson(Map<String, dynamic> json) {
    return GstSlabSummaryData(
      rate: (json['rate'] ?? 0).toDouble(),
      taxableAmount: (json['taxableAmount'] ?? 0).toDouble(),
      cgst: (json['cgst'] ?? 0).toDouble(),
      sgst: (json['sgst'] ?? 0).toDouble(),
      igst: (json['igst'] ?? 0).toDouble(),
    );
  }
}

final gstMonthlySummaryProvider = FutureProvider.family<GstMonthlySummary, DateTime>((ref, month) async {
  try {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.get(
      ApiConstants.gstSummary,
      queryParameters: {
        'month': '${month.year}-${month.month.toString().padLeft(2, '0')}',
      },
    );
    return GstMonthlySummary.fromJson(response.data as Map<String, dynamic>);
  } catch (e) {
    return computeGstSummaryFromCache(month);
  }
});

GstMonthlySummary computeGstSummaryFromCache(DateTime month) {
  final invoices = LocalStorage.getAllCachedInvoices();
  if (invoices.isEmpty) return GstMonthlySummary.empty(month);

  double totalTaxable = 0;
  double totalCgst = 0;
  double totalSgst = 0;
  double totalIgst = 0;
  double totalCess = 0;
  int count = 0;
  final Map<int, GstSlabSummaryData> slabMap = {};

  for (final raw in invoices) {
    final inv = Map<String, dynamic>.from(raw);
    final dateStr = inv['invoiceDate'] ?? '';
    final invDate = DateTime.tryParse(dateStr);
    if (invDate == null ||
        invDate.month != month.month ||
        invDate.year != month.year) {
      continue;
    }

    totalCgst += (inv['totalCgst'] ?? 0).toDouble();
    totalSgst += (inv['totalSgst'] ?? 0).toDouble();
    totalIgst += (inv['totalIgst'] ?? 0).toDouble();
    totalTaxable += (inv['subTotal'] ?? 0).toDouble();
    count++;

    // Aggregate by GST slab
    final slabs = (inv['gstSlabs'] as List? ?? []);
    for (final slabRaw in slabs) {
      final slab = Map<String, dynamic>.from(slabRaw);
      final rate = (slab['rate'] ?? 0).toInt();
      final existing = slabMap[rate] ?? GstSlabSummaryData(
        rate: rate.toDouble(),
        taxableAmount: 0,
        cgst: 0,
        sgst: 0,
        igst: 0,
      );
      slabMap[rate] = GstSlabSummaryData(
        rate: rate.toDouble(),
        taxableAmount: existing.taxableAmount + (slab['taxableAmount'] ?? 0).toDouble(),
        cgst: existing.cgst + (slab['cgst'] ?? 0).toDouble(),
        sgst: existing.sgst + (slab['sgst'] ?? 0).toDouble(),
        igst: existing.igst + (slab['igst'] ?? 0).toDouble(),
      );
    }
  }

  return GstMonthlySummary(
    month: month,
    totalTaxable: totalTaxable,
    totalCgst: totalCgst,
    totalSgst: totalSgst,
    totalIgst: totalIgst,
    totalCess: totalCess,
    totalTax: totalCgst + totalSgst + totalIgst + totalCess,
    invoiceCount: count,
    slabSummaries: slabMap.values.toList(),
  );
}

// GSTR-1 Data
class Gstr1Data {
  final List<B2bInvoice> b2bInvoices;
  final List<B2cInvoice> b2cInvoices;
  final DateTime period;
  final double totalTaxableValue;
  final double totalTax;

  const Gstr1Data({
    required this.b2bInvoices,
    required this.b2cInvoices,
    required this.period,
    required this.totalTaxableValue,
    required this.totalTax,
  });

  factory Gstr1Data.fromJson(Map<String, dynamic> json) {
    return Gstr1Data(
      b2bInvoices: (json['b2b'] as List? ?? []).map((e) => B2bInvoice.fromJson(e)).toList(),
      b2cInvoices: (json['b2c'] as List? ?? []).map((e) => B2cInvoice.fromJson(e)).toList(),
      period: DateTime.tryParse(json['period'] ?? '') ?? DateTime.now(),
      totalTaxableValue: (json['totalTaxableValue'] ?? 0).toDouble(),
      totalTax: (json['totalTax'] ?? 0).toDouble(),
    );
  }
}

class B2bInvoice {
  final String customerGstin;
  final String customerName;
  final String invoiceNumber;
  final DateTime invoiceDate;
  final double invoiceValue;
  final double taxableValue;
  final double cgst;
  final double sgst;
  final double igst;

  const B2bInvoice({
    required this.customerGstin,
    required this.customerName,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.invoiceValue,
    required this.taxableValue,
    required this.cgst,
    required this.sgst,
    required this.igst,
  });

  factory B2bInvoice.fromJson(Map<String, dynamic> json) => B2bInvoice(
    customerGstin: json['customerGstin'] ?? '',
    customerName: json['customerName'] ?? '',
    invoiceNumber: json['invoiceNumber'] ?? '',
    invoiceDate: DateTime.tryParse(json['invoiceDate'] ?? '') ?? DateTime.now(),
    invoiceValue: (json['invoiceValue'] ?? 0).toDouble(),
    taxableValue: (json['taxableValue'] ?? 0).toDouble(),
    cgst: (json['cgst'] ?? 0).toDouble(),
    sgst: (json['sgst'] ?? 0).toDouble(),
    igst: (json['igst'] ?? 0).toDouble(),
  );
}

class B2cInvoice {
  final String state;
  final double taxableValue;
  final double cgst;
  final double sgst;
  final double igst;

  const B2cInvoice({
    required this.state,
    required this.taxableValue,
    required this.cgst,
    required this.sgst,
    required this.igst,
  });

  factory B2cInvoice.fromJson(Map<String, dynamic> json) => B2cInvoice(
    state: json['state'] ?? '',
    taxableValue: (json['taxableValue'] ?? 0).toDouble(),
    cgst: (json['cgst'] ?? 0).toDouble(),
    sgst: (json['sgst'] ?? 0).toDouble(),
    igst: (json['igst'] ?? 0).toDouble(),
  );
}

final gstr1Provider = FutureProvider.family<Gstr1Data, DateTime>((ref, month) async {
  try {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.get(
      ApiConstants.gstr1Draft,
      queryParameters: {'month': '${month.year}-${month.month.toString().padLeft(2, '0')}'},
    );
    return Gstr1Data.fromJson(response.data as Map<String, dynamic>);
  } catch (e) {
    return computeGstr1FromCache(month);
  }
});

Gstr1Data computeGstr1FromCache(DateTime month) {
  final invoices = LocalStorage.getAllCachedInvoices();
  final List<B2bInvoice> b2b = [];
  final List<B2cInvoice> b2c = [];

  double totalTaxable = 0;
  double totalTax = 0;

  for (final raw in invoices) {
    final inv = Map<String, dynamic>.from(raw);
    final dateStr = inv['invoiceDate'] ?? '';
    final invDate = DateTime.tryParse(dateStr);
    if (invDate == null ||
        invDate.month != month.month ||
        invDate.year != month.year) {
      continue;
    }

    final invoiceValue = (inv['grandTotal'] ?? 0).toDouble();
    final taxable = (inv['subTotal'] ?? 0).toDouble();
    final cgst = (inv['totalCgst'] ?? 0).toDouble();
    final sgst = (inv['totalSgst'] ?? 0).toDouble();
    final igst = (inv['totalIgst'] ?? 0).toDouble();

    totalTaxable += taxable;
    totalTax += cgst + sgst + igst;

    final customerGstin = inv['customerGstin']?.toString() ?? '';
    final customerName = inv['customerName'] ?? 'Walk-in Customer';
    final invoiceNumber = inv['invoiceNumber'] ?? '';
    final state = inv['state'] ?? '';

    if (customerGstin.isNotEmpty) {
      b2b.add(B2bInvoice(
        customerGstin: customerGstin,
        customerName: customerName,
        invoiceNumber: invoiceNumber,
        invoiceDate: invDate,
        invoiceValue: invoiceValue,
        taxableValue: taxable,
        cgst: cgst,
        sgst: sgst,
        igst: igst,
      ));
    } else {
      b2c.add(B2cInvoice(
        state: state.isNotEmpty ? state : 'Local',
        taxableValue: taxable,
        cgst: cgst,
        sgst: sgst,
        igst: igst,
      ));
    }
  }

  return Gstr1Data(
    b2bInvoices: b2b,
    b2cInvoices: b2c,
    period: month,
    totalTaxableValue: totalTaxable,
    totalTax: totalTax,
  );
}

