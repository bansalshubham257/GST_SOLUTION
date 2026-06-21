// lib/features/invoice/presentation/providers/item_settings_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/local_storage.dart';

class ItemSettings {
  final bool showManufacturingDate;
  final bool showExpiryDate;
  final bool showBestBeforeDate;
  final bool showPurchasePrice;
  final bool showStock;
  final bool showLowStockAlert;
  final double defaultLowStockThreshold;

  const ItemSettings({
    this.showManufacturingDate = false,
    this.showExpiryDate = false,
    this.showBestBeforeDate = false,
    this.showPurchasePrice = true,
    this.showStock = true,
    this.showLowStockAlert = true,
    this.defaultLowStockThreshold = 10,
  });

  ItemSettings copyWith({
    bool? showManufacturingDate,
    bool? showExpiryDate,
    bool? showBestBeforeDate,
    bool? showPurchasePrice,
    bool? showStock,
    bool? showLowStockAlert,
    double? defaultLowStockThreshold,
  }) =>
      ItemSettings(
        showManufacturingDate: showManufacturingDate ?? this.showManufacturingDate,
        showExpiryDate: showExpiryDate ?? this.showExpiryDate,
        showBestBeforeDate: showBestBeforeDate ?? this.showBestBeforeDate,
        showPurchasePrice: showPurchasePrice ?? this.showPurchasePrice,
        showStock: showStock ?? this.showStock,
        showLowStockAlert: showLowStockAlert ?? this.showLowStockAlert,
        defaultLowStockThreshold: defaultLowStockThreshold ?? this.defaultLowStockThreshold,
      );

  Map<String, dynamic> toMap() => {
        'item_showManufacturingDate': showManufacturingDate,
        'item_showExpiryDate': showExpiryDate,
        'item_showBestBeforeDate': showBestBeforeDate,
        'item_showPurchasePrice': showPurchasePrice,
        'item_showStock': showStock,
        'item_showLowStockAlert': showLowStockAlert,
        'item_defaultLowStockThreshold': defaultLowStockThreshold,
      };

  factory ItemSettings.fromBox() {
    final box = LocalStorage.settingsBox;
    return ItemSettings(
      showManufacturingDate: box.get('item_showManufacturingDate', defaultValue: false) as bool,
      showExpiryDate: box.get('item_showExpiryDate', defaultValue: false) as bool,
      showBestBeforeDate: box.get('item_showBestBeforeDate', defaultValue: false) as bool,
      showPurchasePrice: box.get('item_showPurchasePrice', defaultValue: true) as bool,
      showStock: box.get('item_showStock', defaultValue: true) as bool,
      showLowStockAlert: box.get('item_showLowStockAlert', defaultValue: true) as bool,
      defaultLowStockThreshold: (box.get('item_defaultLowStockThreshold', defaultValue: 10.0) as num).toDouble(),
    );
  }
}

class ItemSettingsNotifier extends Notifier<ItemSettings> {
  @override
  ItemSettings build() => ItemSettings.fromBox();

  Future<void> save(ItemSettings settings) async {
    final box = LocalStorage.settingsBox;
    await box.put('item_showManufacturingDate', settings.showManufacturingDate);
    await box.put('item_showExpiryDate', settings.showExpiryDate);
    await box.put('item_showBestBeforeDate', settings.showBestBeforeDate);
    await box.put('item_showPurchasePrice', settings.showPurchasePrice);
    await box.put('item_showStock', settings.showStock);
    await box.put('item_showLowStockAlert', settings.showLowStockAlert);
    await box.put('item_defaultLowStockThreshold', settings.defaultLowStockThreshold);
    state = settings;
  }
}

final itemSettingsProvider =
    NotifierProvider<ItemSettingsNotifier, ItemSettings>(
  ItemSettingsNotifier.new,
);
