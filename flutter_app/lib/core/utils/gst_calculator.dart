// lib/core/utils/gst_calculator.dart

/// Core GST calculation engine for Indian GST
/// Handles CGST, SGST, IGST based on transaction type (intra/inter-state)
class GstCalculator {
  GstCalculator._();

  /// Determine if transaction is inter-state
  /// by comparing seller state code with buyer state code
  static bool isInterState({
    required String sellerGstin,
    required String? buyerGstin,
    required String? sellerStateCode,
    required String? buyerStateCode,
  }) {
    // Extract state codes from GSTIN if available
    final sellerState = sellerGstin.isNotEmpty
        ? sellerGstin.substring(0, 2)
        : (sellerStateCode ?? '');

    final buyerState = buyerGstin != null && buyerGstin.length >= 2
        ? buyerGstin.substring(0, 2)
        : (buyerStateCode ?? '');

    if (sellerState.isEmpty || buyerState.isEmpty) return false;
    return sellerState != buyerState;
  }

  /// Calculate GST amounts from taxable value and rate
  static GstBreakdown calculate({
    required double taxableAmount,
    required double gstRate,
    required bool isInterState,
    bool isCessApplicable = false,
    double cessRate = 0,
  }) {
    final totalGstAmount = (taxableAmount * gstRate) / 100;
    final cessAmount = isCessApplicable ? (taxableAmount * cessRate) / 100 : 0.0;

    double cgst = 0;
    double sgst = 0;
    double igst = 0;

    if (isInterState) {
      igst = totalGstAmount;
    } else {
      cgst = totalGstAmount / 2;
      sgst = totalGstAmount / 2;
    }

    return GstBreakdown(
      taxableAmount: taxableAmount,
      gstRate: gstRate,
      cgst: _round(cgst),
      sgst: _round(sgst),
      igst: _round(igst),
      cess: _round(cessAmount),
      totalGst: _round(totalGstAmount + cessAmount),
      totalAmount: _round(taxableAmount + totalGstAmount + cessAmount),
      isInterState: isInterState,
    );
  }

  /// Calculate from total amount (inclusive of GST)
  static GstBreakdown calculateFromTotal({
    required double totalAmount,
    required double gstRate,
    required bool isInterState,
  }) {
    final taxableAmount = (totalAmount * 100) / (100 + gstRate);
    return calculate(
      taxableAmount: taxableAmount,
      gstRate: gstRate,
      isInterState: isInterState,
    );
  }

  /// Calculate invoice totals for multiple line items
  static InvoiceTotals calculateInvoiceTotals({
    required List<InvoiceLineItem> lineItems,
    required bool isInterState,
    double discountPercent = 0,
  }) {
    double subTotal = 0;
    double totalCgst = 0;
    double totalSgst = 0;
    double totalIgst = 0;
    double totalCess = 0;
    final Map<double, GstSlabSummary> gstSlabMap = {};

    for (final item in lineItems) {
      final taxableAmount = item.quantity * item.unitPrice;
      final discountAmount = taxableAmount * (item.discountPercent / 100);
      final taxableAfterDiscount = taxableAmount - discountAmount;

      final breakdown = calculate(
        taxableAmount: taxableAfterDiscount,
        gstRate: item.gstRate,
        isInterState: isInterState,
        isCessApplicable: item.cessRate > 0,
        cessRate: item.cessRate,
      );

      subTotal += taxableAfterDiscount;
      totalCgst += breakdown.cgst;
      totalSgst += breakdown.sgst;
      totalIgst += breakdown.igst;
      totalCess += breakdown.cess;

      // Group by GST rate slab
      if (gstSlabMap.containsKey(item.gstRate)) {
        final existing = gstSlabMap[item.gstRate]!;
        gstSlabMap[item.gstRate] = GstSlabSummary(
          gstRate: item.gstRate,
          taxableAmount: existing.taxableAmount + taxableAfterDiscount,
          cgst: existing.cgst + breakdown.cgst,
          sgst: existing.sgst + breakdown.sgst,
          igst: existing.igst + breakdown.igst,
        );
      } else {
        gstSlabMap[item.gstRate] = GstSlabSummary(
          gstRate: item.gstRate,
          taxableAmount: taxableAfterDiscount,
          cgst: breakdown.cgst,
          sgst: breakdown.sgst,
          igst: breakdown.igst,
        );
      }
    }

    final totalTax = totalCgst + totalSgst + totalIgst + totalCess;
    final grandTotal = subTotal + totalTax;

    return InvoiceTotals(
      subTotal: _round(subTotal),
      totalCgst: _round(totalCgst),
      totalSgst: _round(totalSgst),
      totalIgst: _round(totalIgst),
      totalCess: _round(totalCess),
      totalTax: _round(totalTax),
      grandTotal: _round(grandTotal),
      roundOff: _round(grandTotal.roundToDouble() - grandTotal),
      roundedTotal: grandTotal.roundToDouble(),
      gstSlabs: gstSlabMap.values.toList(),
      isInterState: isInterState,
    );
  }

  static double _round(double value) {
    return double.parse(value.toStringAsFixed(2));
  }

  /// Convert number to words for invoice (Indian format)
  static String numberToWords(double amount) {
    final int rupees = amount.floor();
    final int paise = ((amount - rupees) * 100).round();

    String result = '${_convertToWords(rupees)} Rupees';
    if (paise > 0) {
      result += ' and ${_convertToWords(paise)} Paise';
    }
    return '$result Only';
  }

  static String _convertToWords(int number) {
    if (number == 0) return 'Zero';

    const ones = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven',
      'Eight', 'Nine', 'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen',
      'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
    const tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty',
      'Sixty', 'Seventy', 'Eighty', 'Ninety'];

    String words = '';

    if (number >= 10000000) {
      words += '${_convertToWords(number ~/ 10000000)} Crore ';
      number %= 10000000;
    }
    if (number >= 100000) {
      words += '${_convertToWords(number ~/ 100000)} Lakh ';
      number %= 100000;
    }
    if (number >= 1000) {
      words += '${_convertToWords(number ~/ 1000)} Thousand ';
      number %= 1000;
    }
    if (number >= 100) {
      words += '${ones[number ~/ 100]} Hundred ';
      number %= 100;
    }
    if (number >= 20) {
      words += '${tens[number ~/ 10]} ';
      number %= 10;
    }
    if (number > 0) {
      words += '${ones[number]} ';
    }

    return words.trim();
  }
}

class GstBreakdown {
  final double taxableAmount;
  final double gstRate;
  final double cgst;
  final double sgst;
  final double igst;
  final double cess;
  final double totalGst;
  final double totalAmount;
  final bool isInterState;

  const GstBreakdown({
    required this.taxableAmount,
    required this.gstRate,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.cess,
    required this.totalGst,
    required this.totalAmount,
    required this.isInterState,
  });
}

class InvoiceLineItem {
  final String description;
  final String? hsnSacCode;
  final double quantity;
  final double unitPrice;
  final double gstRate;
  final double discountPercent;
  final double cessRate;

  const InvoiceLineItem({
    required this.description,
    this.hsnSacCode,
    required this.quantity,
    required this.unitPrice,
    required this.gstRate,
    this.discountPercent = 0,
    this.cessRate = 0,
  });
}

class InvoiceTotals {
  final double subTotal;
  final double totalCgst;
  final double totalSgst;
  final double totalIgst;
  final double totalCess;
  final double totalTax;
  final double grandTotal;
  final double roundOff;
  final double roundedTotal;
  final List<GstSlabSummary> gstSlabs;
  final bool isInterState;

  const InvoiceTotals({
    required this.subTotal,
    required this.totalCgst,
    required this.totalSgst,
    required this.totalIgst,
    required this.totalCess,
    required this.totalTax,
    required this.grandTotal,
    required this.roundOff,
    required this.roundedTotal,
    required this.gstSlabs,
    required this.isInterState,
  });
}

class GstSlabSummary {
  final double gstRate;
  final double taxableAmount;
  final double cgst;
  final double sgst;
  final double igst;

  const GstSlabSummary({
    required this.gstRate,
    required this.taxableAmount,
    required this.cgst,
    required this.sgst,
    required this.igst,
  });
}

