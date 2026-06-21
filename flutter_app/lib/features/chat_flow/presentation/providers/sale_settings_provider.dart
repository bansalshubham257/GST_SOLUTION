// lib/features/chat_flow/presentation/providers/sale_settings_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/local_storage.dart';

class SaleSettings {
  final bool askCustomer;
  final bool askStaff;
  final bool askQty;
  final bool askPrice;
  final bool askGst;
  final bool askDiscount;
  final bool enableBarcode;
  final bool enableCatalog;
  final bool continuousScan;
  final double defaultQty;
  final double defaultGst;
  final double defaultDiscount;
  final String saleType; // 'retail' (simple) or 'detailed'

  const SaleSettings({
    this.askCustomer = true,
    this.askStaff = false,
    this.askQty = true,
    this.askPrice = true,
    this.askGst = false,
    this.askDiscount = true,
    this.enableBarcode = true,
    this.enableCatalog = true,
    this.continuousScan = false,
    this.defaultQty = 1,
    this.defaultGst = 18,
    this.defaultDiscount = 0,
    this.saleType = 'retail',
  });

  SaleSettings copyWith({
    bool? askCustomer,
    bool? askStaff,
    bool? askQty,
    bool? askPrice,
    bool? askGst,
    bool? askDiscount,
    bool? enableBarcode,
    bool? enableCatalog,
    bool? continuousScan,
    double? defaultQty,
    double? defaultGst,
    double? defaultDiscount,
    String? saleType,
  }) =>
      SaleSettings(
        askCustomer: askCustomer ?? this.askCustomer,
        askStaff: askStaff ?? this.askStaff,
        askQty: askQty ?? this.askQty,
        askPrice: askPrice ?? this.askPrice,
        askGst: askGst ?? this.askGst,
        askDiscount: askDiscount ?? this.askDiscount,
        enableBarcode: enableBarcode ?? this.enableBarcode,
        enableCatalog: enableCatalog ?? this.enableCatalog,
        continuousScan: continuousScan ?? this.continuousScan,
        defaultQty: defaultQty ?? this.defaultQty,
        defaultGst: defaultGst ?? this.defaultGst,
        defaultDiscount: defaultDiscount ?? this.defaultDiscount,
        saleType: saleType ?? this.saleType,
      );

  Map<String, dynamic> toMap() => {
        'sale_askCustomer': askCustomer,
        'sale_askStaff': askStaff,
        'sale_askQty': askQty,
        'sale_askPrice': askPrice,
        'sale_askGst': askGst,
        'sale_askDiscount': askDiscount,
        'sale_enableBarcode': enableBarcode,
        'sale_enableCatalog': enableCatalog,
        'sale_continuousScan': continuousScan,
        'sale_defaultQty': defaultQty,
        'sale_defaultGst': defaultGst,
        'sale_defaultDiscount': defaultDiscount,
        'sale_type': saleType,
      };

  factory SaleSettings.fromBox() {
    final box = LocalStorage.settingsBox;
    return SaleSettings(
      askCustomer: box.get('sale_askCustomer', defaultValue: true) as bool,
      askStaff: box.get('sale_askStaff', defaultValue: false) as bool,
      askQty: box.get('sale_askQty', defaultValue: true) as bool,
      askPrice: box.get('sale_askPrice', defaultValue: true) as bool,
      askGst: box.get('sale_askGst', defaultValue: false) as bool,
      askDiscount: box.get('sale_askDiscount', defaultValue: true) as bool,
      enableBarcode: box.get('sale_enableBarcode', defaultValue: true) as bool,
      enableCatalog: box.get('sale_enableCatalog', defaultValue: true) as bool,
      continuousScan: box.get('sale_continuousScan', defaultValue: false) as bool,
      defaultQty: (box.get('sale_defaultQty', defaultValue: 1.0) as num).toDouble(),
      defaultGst: (box.get('sale_defaultGst', defaultValue: 18.0) as num).toDouble(),
      defaultDiscount: (box.get('sale_defaultDiscount', defaultValue: 0.0) as num).toDouble(),
      saleType: box.get('sale_type', defaultValue: 'retail') as String,
    );
  }
}

class SaleSettingsNotifier extends Notifier<SaleSettings> {
  @override
  SaleSettings build() => SaleSettings.fromBox();

  Future<void> save(SaleSettings settings) async {
    final box = LocalStorage.settingsBox;
    await box.put('sale_askCustomer', settings.askCustomer);
    await box.put('sale_askStaff', settings.askStaff);
    await box.put('sale_askQty', settings.askQty);
    await box.put('sale_askPrice', settings.askPrice);
    await box.put('sale_askGst', settings.askGst);
    await box.put('sale_askDiscount', settings.askDiscount);
    await box.put('sale_enableBarcode', settings.enableBarcode);
    await box.put('sale_enableCatalog', settings.enableCatalog);
    await box.put('sale_continuousScan', settings.continuousScan);
    await box.put('sale_defaultQty', settings.defaultQty);
    await box.put('sale_defaultGst', settings.defaultGst);
    await box.put('sale_defaultDiscount', settings.defaultDiscount);
    await box.put('sale_type', settings.saleType);
    state = settings;
  }
}

final saleSettingsProvider =
    NotifierProvider<SaleSettingsNotifier, SaleSettings>(
  SaleSettingsNotifier.new,
);
