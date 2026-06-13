// lib/features/invoice/data/models/item_catalog_entry.dart

class ItemCatalogEntry {
  final String id;
  final String name;
  final String unit;
  final double unitPrice;
  final double gstRate;
  final String? hsnCode;
  final bool isService;
  /// Barcode / QR code value assigned to this item (EAN, UPC, or custom)
  final String? barcode;
  /// Current stock quantity (0 = untracked)
  final double stock;

  const ItemCatalogEntry({
    required this.id,
    required this.name,
    this.unit = 'Nos',
    required this.unitPrice,
    required this.gstRate,
    this.hsnCode,
    this.isService = false,
    this.barcode,
    this.stock = 0,
  });

  factory ItemCatalogEntry.fromJson(Map<String, dynamic> json) {
    return ItemCatalogEntry(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      unit: json['unit'] ?? 'Nos',
      unitPrice: (json['unitPrice'] ?? 0).toDouble(),
      gstRate: (json['gstRate'] ?? 18).toDouble(),
      hsnCode: json['hsnCode'],
      isService: json['isService'] ?? false,
      barcode: json['barcode'],
      stock: (json['stock'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'unit': unit,
    'unitPrice': unitPrice,
    'gstRate': gstRate,
    'hsnCode': hsnCode,
    'isService': isService,
    'barcode': barcode,
    'stock': stock,
  };

  /// The data we encode into this item's QR code
  String get qrData => 'gst_item|$id|$name|$unitPrice|$gstRate|$unit';

  ItemCatalogEntry copyWith({
    String? name,
    String? unit,
    double? unitPrice,
    double? gstRate,
    String? hsnCode,
    bool? isService,
    String? barcode,
    double? stock,
  }) {
    return ItemCatalogEntry(
      id: id,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      gstRate: gstRate ?? this.gstRate,
      hsnCode: hsnCode ?? this.hsnCode,
      isService: isService ?? this.isService,
      barcode: barcode ?? this.barcode,
      stock: stock ?? this.stock,
    );
  }
}

