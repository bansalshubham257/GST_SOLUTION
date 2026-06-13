// lib/features/invoice/data/models/scanned_bill_model.dart

class ScannedBillData {
  final String? customerName;
  final String? customerGstin;
  final String? customerPhone;
  final String? customerEmail;
  final String? customerAddress;
  final String? supplierName;
  final String? supplierGstin;
  final String? invoiceNumber;
  final DateTime? invoiceDate;
  final List<ScannedLineItem> lineItems;
  final double? totalAmount;
  final double? totalGst;
  final double? subTotal;
  final String rawText;
  final double confidence; // 0.0 to 1.0

  const ScannedBillData({
    this.customerName,
    this.customerGstin,
    this.customerPhone,
    this.customerEmail,
    this.customerAddress,
    this.supplierName,
    this.supplierGstin,
    this.invoiceNumber,
    this.invoiceDate,
    this.lineItems = const [],
    this.totalAmount,
    this.totalGst,
    this.subTotal,
    this.rawText = '',
    this.confidence = 0.0,
  });

  ScannedBillData copyWith({
    String? customerName,
    String? customerGstin,
    String? customerPhone,
    String? customerEmail,
    String? customerAddress,
    String? supplierName,
    String? supplierGstin,
    String? invoiceNumber,
    DateTime? invoiceDate,
    List<ScannedLineItem>? lineItems,
    double? totalAmount,
    double? totalGst,
    double? subTotal,
    String? rawText,
    double? confidence,
  }) {
    return ScannedBillData(
      customerName: customerName ?? this.customerName,
      customerGstin: customerGstin ?? this.customerGstin,
      customerPhone: customerPhone ?? this.customerPhone,
      customerEmail: customerEmail ?? this.customerEmail,
      customerAddress: customerAddress ?? this.customerAddress,
      supplierName: supplierName ?? this.supplierName,
      supplierGstin: supplierGstin ?? this.supplierGstin,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      lineItems: lineItems ?? this.lineItems,
      totalAmount: totalAmount ?? this.totalAmount,
      totalGst: totalGst ?? this.totalGst,
      subTotal: subTotal ?? this.subTotal,
      rawText: rawText ?? this.rawText,
      confidence: confidence ?? this.confidence,
    );
  }

  factory ScannedBillData.fromJson(Map<String, dynamic> json) {
    return ScannedBillData(
      customerName: json['customerName'],
      customerGstin: json['customerGstin'],
      customerPhone: json['customerPhone'],
      customerEmail: json['customerEmail'],
      customerAddress: json['customerAddress'],
      supplierName: json['supplierName'],
      supplierGstin: json['supplierGstin'],
      invoiceNumber: json['invoiceNumber'],
      invoiceDate: json['invoiceDate'] != null
          ? DateTime.tryParse(json['invoiceDate'])
          : null,
      lineItems: (json['lineItems'] as List? ?? [])
          .map((e) => ScannedLineItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalAmount: (json['totalAmount'] as num?)?.toDouble(),
      totalGst: (json['totalGst'] as num?)?.toDouble(),
      subTotal: (json['subTotal'] as num?)?.toDouble(),
      rawText: json['rawText'] ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }

  bool get hasCustomerInfo =>
      customerName != null || customerGstin != null || customerPhone != null;

  bool get hasItems => lineItems.isNotEmpty;

  int get extractedFieldCount {
    int count = 0;
    if (customerName != null) count++;
    if (customerGstin != null) count++;
    if (customerPhone != null) count++;
    if (customerEmail != null) count++;
    if (customerAddress != null) count++;
    if (invoiceNumber != null) count++;
    if (invoiceDate != null) count++;
    count += lineItems.length;
    return count;
  }
}

class ScannedLineItem {
  final String description;
  final double quantity;
  final double unitPrice;
  final double gstRate;
  final double amount;
  final String? hsnCode;

  const ScannedLineItem({
    required this.description,
    this.quantity = 1.0,
    this.unitPrice = 0.0,
    this.gstRate = 18.0,
    this.amount = 0.0,
    this.hsnCode,
  });

  ScannedLineItem copyWith({
    String? description,
    double? quantity,
    double? unitPrice,
    double? gstRate,
    double? amount,
    String? hsnCode,
  }) {
    return ScannedLineItem(
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      gstRate: gstRate ?? this.gstRate,
      amount: amount ?? this.amount,
      hsnCode: hsnCode ?? this.hsnCode,
    );
  }

  factory ScannedLineItem.fromJson(Map<String, dynamic> json) {
    return ScannedLineItem(
      description: json['description'] ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
      gstRate: (json['gstRate'] as num?)?.toDouble() ?? 18.0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      hsnCode: json['hsnCode'],
    );
  }

  Map<String, dynamic> toJson() => {
    'description': description,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'gstRate': gstRate,
    'amount': amount,
    'hsnCode': hsnCode,
  };
}

