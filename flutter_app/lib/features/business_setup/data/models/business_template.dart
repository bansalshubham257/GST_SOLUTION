import 'package:flutter/material.dart';

import '../../../settings/presentation/providers/feature_settings_provider.dart';
import '../../../invoice/presentation/providers/invoice_settings_provider.dart';
import '../../../chat_flow/presentation/providers/sale_settings_provider.dart';
import '../../../invoice/presentation/providers/item_settings_provider.dart';

enum BusinessTemplate {
  custom,
  salon,
  retail,
  restaurant,
  service;

  String get id => name;

  String get displayName {
    switch (this) {
      case custom:
        return 'General / Custom';
      case salon:
        return 'Salon / Spa / Beauty Parlour';
      case retail:
        return 'Retailer / General Store';
      case restaurant:
        return 'Restaurant / Cafe';
      case service:
        return 'Service Provider / Freelancer';
    }
  }

  IconData get icon {
    switch (this) {
      case custom:
        return Icons.tune;
      case salon:
        return Icons.content_cut;
      case retail:
        return Icons.store;
      case restaurant:
        return Icons.restaurant;
      case service:
        return Icons.handyman;
    }
  }

  String get description {
    switch (this) {
      case custom:
        return 'Manually configure all settings';
      case salon:
        return 'Staff commission, service-based billing, no barcode';
      case retail:
        return 'Barcode scanning, purchases, stock & expiry tracking';
      case restaurant:
        return 'Waiter assignment, minimal discounts, expiry dates';
      case service:
        return 'Fixed-price services, no quantity, simple billing';
    }
  }

  // ─── Feature Presets ──────────────────────────────────────────────

  FeatureSettings get featurePreset {
    switch (this) {
      case custom:
        return const FeatureSettings();
      case salon:
        return const FeatureSettings(
          showStaff: true,
          showCustomers: true,
          showPurchases: false,
          showGstReports: true,
          showExpenses: true,
          showItems: true,
        );
      case retail:
        return const FeatureSettings(
          showStaff: false,
          showCustomers: true,
          showPurchases: true,
          showGstReports: true,
          showExpenses: true,
          showItems: true,
        );
      case restaurant:
        return const FeatureSettings(
          showStaff: true,
          showCustomers: true,
          showPurchases: true,
          showGstReports: true,
          showExpenses: true,
          showItems: true,
        );
      case service:
        return const FeatureSettings(
          showStaff: false,
          showCustomers: true,
          showPurchases: false,
          showGstReports: true,
          showExpenses: true,
          showItems: true,
        );
    }
  }

  // ─── Sale Presets ────────────────────────────────────────────────

  SaleSettings get salePreset {
    switch (this) {
      case custom:
        return const SaleSettings();
      case salon:
        return const SaleSettings(
          askCustomer: true,
          askStaff: true,
          askQty: true,
          askPrice: true,
          askGst: true,
          askDiscount: true,
          enableBarcode: false,
          enableCatalog: true,
          continuousScan: false,
          defaultQty: 1,
          defaultGst: 5,
          defaultDiscount: 0,
          saleType: 'retail',
        );
      case retail:
        return const SaleSettings(
          askCustomer: true,
          askStaff: false,
          askQty: true,
          askPrice: true,
          askGst: true,
          askDiscount: true,
          enableBarcode: true,
          enableCatalog: true,
          continuousScan: true,
          defaultQty: 1,
          defaultGst: 18,
          defaultDiscount: 0,
          saleType: 'retail',
        );
      case restaurant:
        return const SaleSettings(
          askCustomer: true,
          askStaff: true,
          askQty: true,
          askPrice: true,
          askGst: true,
          askDiscount: false,
          enableBarcode: false,
          enableCatalog: true,
          continuousScan: false,
          defaultQty: 1,
          defaultGst: 5,
          defaultDiscount: 0,
          saleType: 'retail',
        );
      case service:
        return const SaleSettings(
          askCustomer: true,
          askStaff: false,
          askQty: false,
          askPrice: true,
          askGst: true,
          askDiscount: true,
          enableBarcode: false,
          enableCatalog: true,
          continuousScan: false,
          defaultQty: 1,
          defaultGst: 18,
          defaultDiscount: 0,
          saleType: 'retail',
        );
    }
  }

  // ─── Invoice Presets ──────────────────────────────────────────────

  InvoiceSettings get invoicePreset {
    switch (this) {
      case custom:
        return const InvoiceSettings();
      case salon:
        return const InvoiceSettings(
          prefix: 'SALON',
          defaultTerms: 'Thank you for visiting!',
          templateStyle: 'modern',
        );
      case retail:
        return const InvoiceSettings(
          prefix: 'INV',
          defaultTerms: 'Thank you for your purchase!',
          templateStyle: 'classic',
        );
      case restaurant:
        return const InvoiceSettings(
          prefix: 'REST',
          defaultTerms: 'Please visit again!',
          templateStyle: 'minimal',
        );
      case service:
        return const InvoiceSettings(
          prefix: 'SRV',
          defaultTerms: 'Thank you for your business!',
          templateStyle: 'modern',
        );
    }
  }

  // ─── Item Presets ────────────────────────────────────────────────

  ItemSettings get itemPreset {
    switch (this) {
      case custom:
        return const ItemSettings();
      case salon:
        return const ItemSettings(
          showManufacturingDate: false,
          showExpiryDate: false,
          showBestBeforeDate: false,
          showPurchasePrice: true,
          showStock: true,
          showLowStockAlert: true,
          defaultLowStockThreshold: 10,
        );
      case retail:
        return const ItemSettings(
          showManufacturingDate: false,
          showExpiryDate: true,
          showBestBeforeDate: false,
          showPurchasePrice: true,
          showStock: true,
          showLowStockAlert: true,
          defaultLowStockThreshold: 10,
        );
      case restaurant:
        return const ItemSettings(
          showManufacturingDate: false,
          showExpiryDate: true,
          showBestBeforeDate: true,
          showPurchasePrice: true,
          showStock: true,
          showLowStockAlert: true,
          defaultLowStockThreshold: 5,
        );
      case service:
        return const ItemSettings(
          showManufacturingDate: false,
          showExpiryDate: false,
          showBestBeforeDate: false,
          showPurchasePrice: true,
          showStock: true,
          showLowStockAlert: true,
          defaultLowStockThreshold: 5,
        );
    }
  }
}
