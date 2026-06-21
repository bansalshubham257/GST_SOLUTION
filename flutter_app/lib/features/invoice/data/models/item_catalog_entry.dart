// lib/features/invoice/data/models/item_catalog_entry.dart

class ItemCatalogEntry {
  final String id;
  final String name;
  final String unit;
  final double unitPrice;
  final double? purchasePrice;
  final double gstRate;
  final String? hsnCode;
  final bool isService;
  /// Barcode / QR code value assigned to this item (EAN, UPC, or custom)
  final String? barcode;
  /// Current stock quantity (0 = untracked)
  final double stock;
  /// Minimum stock threshold for low stock alerts (null = no alert)
  final double? lowStockThreshold;
  /// Manufacturing date
  final DateTime? manufacturingDate;
  /// Expiry date
  final DateTime? expiryDate;
  /// Best before date
  final DateTime? bestBeforeDate;

  const ItemCatalogEntry({
    required this.id,
    required this.name,
    this.unit = 'Nos',
    required this.unitPrice,
    this.purchasePrice,
    required this.gstRate,
    this.hsnCode,
    this.isService = false,
    this.barcode,
    this.stock = 0,
    this.lowStockThreshold,
    this.manufacturingDate,
    this.expiryDate,
    this.bestBeforeDate,
  });

  bool get isLowStock =>
      stock > 0 && stock <= (lowStockThreshold ?? 10);

  bool get isOutOfStock => stock == 0 && (lowStockThreshold != null || !isService);

  bool get isExpired =>
      expiryDate != null && expiryDate!.isBefore(DateTime.now());

  factory ItemCatalogEntry.fromJson(Map<String, dynamic> json) {
    return ItemCatalogEntry(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      unit: json['unit'] ?? 'Nos',
      unitPrice: (json['unitPrice'] ?? 0).toDouble(),
      purchasePrice: json['purchasePrice'] != null
          ? (json['purchasePrice'] as num).toDouble()
          : null,
      gstRate: (json['gstRate'] ?? 18).toDouble(),
      hsnCode: json['hsnCode'],
      isService: json['isService'] ?? false,
      barcode: json['barcode'],
      stock: (json['stock'] ?? 0).toDouble(),
      lowStockThreshold: json['lowStockThreshold'] != null
          ? (json['lowStockThreshold'] as num).toDouble()
          : null,
      manufacturingDate: json['manufacturingDate'] != null
          ? DateTime.tryParse(json['manufacturingDate'] as String)
          : null,
      expiryDate: json['expiryDate'] != null
          ? DateTime.tryParse(json['expiryDate'] as String)
          : null,
      bestBeforeDate: json['bestBeforeDate'] != null
          ? DateTime.tryParse(json['bestBeforeDate'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'unit': unit,
    'unitPrice': unitPrice,
    'purchasePrice': purchasePrice,
    'gstRate': gstRate,
    'hsnCode': hsnCode,
    'isService': isService,
    'barcode': barcode,
    'stock': stock,
    'lowStockThreshold': lowStockThreshold,
    'manufacturingDate': manufacturingDate?.toIso8601String(),
    'expiryDate': expiryDate?.toIso8601String(),
    'bestBeforeDate': bestBeforeDate?.toIso8601String(),
  };

  /// The data we encode into this item's QR code
  String get qrData => 'gst_item|$id|$name|$unitPrice|$gstRate|$unit';

  ItemCatalogEntry copyWith({
    String? name,
    String? unit,
    double? unitPrice,
    double? purchasePrice,
    double? gstRate,
    String? hsnCode,
    bool? isService,
    String? barcode,
    double? stock,
    double? lowStockThreshold,
    DateTime? manufacturingDate,
    DateTime? expiryDate,
    DateTime? bestBeforeDate,
  }) {
    return ItemCatalogEntry(
      id: id,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      gstRate: gstRate ?? this.gstRate,
      hsnCode: hsnCode ?? this.hsnCode,
      isService: isService ?? this.isService,
      barcode: barcode ?? this.barcode,
      stock: stock ?? this.stock,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      manufacturingDate: manufacturingDate ?? this.manufacturingDate,
      expiryDate: expiryDate ?? this.expiryDate,
      bestBeforeDate: bestBeforeDate ?? this.bestBeforeDate,
    );
  }
}

