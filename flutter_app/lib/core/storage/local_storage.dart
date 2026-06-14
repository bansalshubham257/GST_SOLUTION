// lib/core/storage/local_storage.dart

import 'package:hive_flutter/hive_flutter.dart';

import '../constants/app_constants.dart';

/// Hive-based offline cache for invoices, customers, and business data
class LocalStorage {
  LocalStorage._();

  static Future<void> init() async {
    await Future.wait([
      Hive.openBox<Map>(AppConstants.invoiceBox),
      Hive.openBox<Map>(AppConstants.customerBox),
      Hive.openBox(AppConstants.businessBox),
      Hive.openBox(AppConstants.userBox),
      Hive.openBox(AppConstants.settingsBox),
      Hive.openBox<Map>(AppConstants.draftBox),
      Hive.openBox<Map>(AppConstants.itemCatalogBox),
      Hive.openBox<Map>(AppConstants.staffBox),
      Hive.openBox<Map>(AppConstants.expenseBox),
      Hive.openBox<Map>(AppConstants.expenseCategoryBox),
      Hive.openBox<Map>(AppConstants.purchaseBox),
    ]);
  }

  // Invoice Cache
  static Box<Map> get invoiceBox => Hive.box<Map>(AppConstants.invoiceBox);
  static Box<Map> get customerBox => Hive.box<Map>(AppConstants.customerBox);
  static Box get businessBox => Hive.box(AppConstants.businessBox);
  static Box get userBox => Hive.box(AppConstants.userBox);
  static Box get settingsBox => Hive.box(AppConstants.settingsBox);
  static Box<Map> get draftBox => Hive.box<Map>(AppConstants.draftBox);
  static Box<Map> get itemCatalogBox => Hive.box<Map>(AppConstants.itemCatalogBox);
  static Box<Map> get staffBox => Hive.box<Map>(AppConstants.staffBox);
  static Box<Map> get expenseBox => Hive.box<Map>(AppConstants.expenseBox);
  static Box<Map> get expenseCategoryBox => Hive.box<Map>(AppConstants.expenseCategoryBox);
  static Box<Map> get purchaseBox => Hive.box<Map>(AppConstants.purchaseBox);

  // Item Catalog
  static Future<void> saveItemCatalog(String id, Map<String, dynamic> data) async {
    await itemCatalogBox.put(id, data);
  }
  static Map? getItemCatalog(String id) => itemCatalogBox.get(id);
  static List<Map> getAllItemCatalog() => itemCatalogBox.values.toList();
  static Future<void> deleteItemCatalog(String id) async => itemCatalogBox.delete(id);

  // Generic helpers
  static Future<void> put(String boxName, dynamic key, dynamic value) async {
    final box = Hive.box(boxName);
    await box.put(key, value);
  }

  static dynamic get(String boxName, dynamic key) {
    final box = Hive.box(boxName);
    return box.get(key);
  }

  static Future<void> delete(String boxName, dynamic key) async {
    final box = Hive.box(boxName);
    await box.delete(key);
  }

  static Future<void> clearBox(String boxName) async {
    final box = Hive.box(boxName);
    await box.clear();
  }

  /// Clear all cached data — call on logout or user switch
  // Cache purchases offline
  static Future<void> cachePurchase(String id, Map<String, dynamic> data) async {
    await purchaseBox.put(id, data);
  }

  static Map? getCachedPurchase(String id) => purchaseBox.get(id);

  static List<Map> getAllCachedPurchases() => purchaseBox.values.toList();
  static Future<void> deletePurchase(String id) async => purchaseBox.delete(id);

  static Future<void> clearAll() async {
    await Future.wait([
      invoiceBox.clear(),
      customerBox.clear(),
      businessBox.clear(),
      userBox.clear(),
      settingsBox.clear(),
      draftBox.clear(),
      itemCatalogBox.clear(),
      staffBox.clear(),
      expenseBox.clear(),
      expenseCategoryBox.clear(),
      purchaseBox.clear(),
    ]);
  }

  /// Migrate existing cached invoices: recompute gstSlabs from lineItems
  static Future<void> migrateInvoiceSlabs() async {
    final keys = invoiceBox.keys.toList();
    for (final key in keys) {
      final inv = Map<String, dynamic>.from(invoiceBox.get(key) ?? {});
      final slabs = inv['gstSlabs'] as List? ?? [];
      // Only migrate if slabs are single/missing or rate is 0
      if (slabs.isEmpty || (slabs.length == 1 && (slabs.first['rate'] == 0 || slabs.first['rate'] == null))) {
        final lineItems = (inv['lineItems'] as List? ?? []);
        if (lineItems.isEmpty) continue;
        final slabMap = <int, Map<String, dynamic>>{};
        for (final itemRaw in lineItems) {
          final item = Map<String, dynamic>.from(itemRaw);
          final rate = (item['gstRate'] as num?)?.toInt() ?? 0;
          final taxable = (item['taxableAmount'] as num?)?.toDouble() ?? 0;
          final cgst = (item['cgst'] as num?)?.toDouble() ?? 0;
          final sgst = (item['sgst'] as num?)?.toDouble() ?? 0;
          final igst = (item['igst'] as num?)?.toDouble() ?? 0;
          if (slabMap.containsKey(rate)) {
            slabMap[rate]!['taxableAmount'] = (slabMap[rate]!['taxableAmount'] as double) + taxable;
            slabMap[rate]!['cgst'] = (slabMap[rate]!['cgst'] as double) + cgst;
            slabMap[rate]!['sgst'] = (slabMap[rate]!['sgst'] as double) + sgst;
            slabMap[rate]!['igst'] = (slabMap[rate]!['igst'] as double) + igst;
          } else {
            slabMap[rate] = {
              'rate': rate,
              'taxableAmount': taxable,
              'cgst': cgst,
              'sgst': sgst,
              'igst': igst,
            };
          }
        }
        inv['gstSlabs'] = slabMap.values.toList();
        await invoiceBox.put(key, inv);
      }
    }
  }

  // Cache invoices offline
  static Future<void> cacheInvoice(String id, Map<String, dynamic> data) async {
    await invoiceBox.put(id, data);
  }

  static Map? getCachedInvoice(String id) => invoiceBox.get(id);

  static List<Map> getAllCachedInvoices() => invoiceBox.values.toList();
  static Future<void> deleteInvoice(String id) async => invoiceBox.delete(id);

  // Cache customers offline
  static Future<void> cacheCustomer(String id, Map<String, dynamic> data) async {
    await customerBox.put(id, data);
  }

  static Map? getCachedCustomer(String id) => customerBox.get(id);

  static List<Map> getAllCachedCustomers() => customerBox.values.toList();
  static Future<void> deleteCustomer(String id) async => customerBox.delete(id);

  // Save draft invoice
  static Future<void> saveDraft(String draftId, Map<String, dynamic> data) async {
    await draftBox.put(draftId, data);
  }

  static Map? getDraft(String draftId) => draftBox.get(draftId);

  static List<Map> getAllDrafts() => draftBox.values.toList();

  static Future<void> deleteDraft(String draftId) async {
    await draftBox.delete(draftId);
  }

  // Business setup
  static Future<void> saveBusinessData(Map<String, dynamic> data) async {
    for (final entry in data.entries) {
      if (entry.value != null) {
        await businessBox.put(entry.key, entry.value);
      }
    }
  }

  static bool isBusinessSetupDone() =>
      businessBox.get('setupDone', defaultValue: false) as bool;

  static Future<void> markBusinessSetupDone() async {
    await businessBox.put('setupDone', true);
  }

  // User preferences
  static Future<void> setThemeMode(String mode) async {
    await settingsBox.put('themeMode', mode);
  }

  static String getThemeMode() => settingsBox.get('themeMode', defaultValue: 'light') as String;
}

