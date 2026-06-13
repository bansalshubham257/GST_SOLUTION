// lib/features/invoice/presentation/providers/item_catalog_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/item_catalog_entry.dart';
import '../../../../core/storage/local_storage.dart';

final itemCatalogProvider =
    StateNotifierProvider<ItemCatalogNotifier, List<ItemCatalogEntry>>(
  (ref) => ItemCatalogNotifier()..loadFromStorage(),
);

class ItemCatalogNotifier extends StateNotifier<List<ItemCatalogEntry>> {
  ItemCatalogNotifier() : super([]);

  final _uuid = const Uuid();

  void loadFromStorage() {
    final cached = LocalStorage.getAllItemCatalog();
    final items = cached
        .map((m) => ItemCatalogEntry.fromJson(Map<String, dynamic>.from(m)))
        .toList();
    state = items;
  }

  Future<void> addItem({
    required String name,
    required double unitPrice,
    required double gstRate,
    String unit = 'Nos',
    String? hsnCode,
    bool isService = false,
    String? barcode,
    double stock = 0,
  }) async {
    final id = 'item-${_uuid.v4().substring(0, 8)}';
    final entry = ItemCatalogEntry(
      id: id,
      name: name,
      unit: unit,
      unitPrice: unitPrice,
      gstRate: gstRate,
      hsnCode: hsnCode,
      isService: isService,
      barcode: barcode,
      stock: stock,
    );
    await LocalStorage.saveItemCatalog(id, entry.toJson());
    state = [entry, ...state];
  }

  Future<void> updateItem(ItemCatalogEntry updated) async {
    await LocalStorage.saveItemCatalog(updated.id, updated.toJson());
    state = state.map((e) => e.id == updated.id ? updated : e).toList();
  }

  Future<void> removeItem(String id) async {
    await LocalStorage.deleteItemCatalog(id);
    state = state.where((e) => e.id != id).toList();
  }

  /// Adjust stock by [delta] (positive = add, negative = sell)
  Future<void> adjustStock(String id, double delta) async {
    final item = state.firstWhere((e) => e.id == id, orElse: () => throw Exception('Item not found'));
    final updated = item.copyWith(stock: (item.stock + delta).clamp(0, double.infinity));
    await updateItem(updated);
  }

  ItemCatalogEntry? findByName(String name) {
    final lower = name.toLowerCase().trim();
    try {
      return state.firstWhere((e) => e.name.toLowerCase() == lower);
    } catch (_) {
      return null;
    }
  }

  /// Find by barcode (external EAN/UPC) or our internal QR data prefix
  ItemCatalogEntry? findByBarcode(String barcode) {
    final trimmed = barcode.trim();
    // Match our internal QR format: gst_item|id|name|price|gst|unit
    if (trimmed.startsWith('gst_item|')) {
      final parts = trimmed.split('|');
      if (parts.length >= 2) {
        final id = parts[1];
        try {
          return state.firstWhere((e) => e.id == id);
        } catch (_) {}
      }
    }
    // Match external barcode stored on item
    try {
      return state.firstWhere((e) => e.barcode == trimmed);
    } catch (_) {
      return null;
    }
  }

  /// Parse a scanned QR value produced by [ItemCatalogEntry.qrData] into a
  /// lightweight entry (useful when item is not in local catalog yet)
  static ItemCatalogEntry? parseFromQr(String qrValue) {
    if (!qrValue.startsWith('gst_item|')) return null;
    final parts = qrValue.split('|');
    if (parts.length < 6) return null;
    try {
      return ItemCatalogEntry(
        id: parts[1],
        name: parts[2],
        unitPrice: double.parse(parts[3]),
        gstRate: double.parse(parts[4]),
        unit: parts[5],
      );
    } catch (_) {
      return null;
    }
  }
}



