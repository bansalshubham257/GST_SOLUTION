import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../constants/api_constants.dart';
import '../constants/app_constants.dart';
import '../network/api_client.dart';
import '../storage/secure_storage.dart';

class SyncService {
  final ApiClient _apiClient;

  SyncService(this._apiClient);

  /// Full sync: push all local data to backend.
  /// Returns true on success (partial errors allowed).
  Future<bool> syncAll() async {
    try {
      final customers = _getAllCustomers();
      final products = _getAllProducts();
      final invoices = _getAllInvoices();
      final business = _getBusinessData();

      if (customers.isEmpty && products.isEmpty && invoices.isEmpty && business == null) {
        return true; // nothing to sync
      }

      final body = <String, dynamic>{};
      if (business != null) body['business'] = business;
      if (customers.isNotEmpty) body['customers'] = customers;
      if (products.isNotEmpty) body['products'] = products;
      if (invoices.isNotEmpty) body['invoices'] = invoices;

      final response = await _apiClient.post(ApiConstants.syncAll, data: body);
      final result = response.data as Map<String, dynamic>;
      if (result['success'] != true) return false;

      await SecureStorage.write('last_sync_at', DateTime.now().toIso8601String());
      return true;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic>? _getBusinessData() {
    final box = Hive.box(AppConstants.businessBox);
    if (box.isEmpty) return null;
    final data = <String, dynamic>{};
    for (final key in box.keys) {
      data[key.toString()] = box.get(key);
    }
    return data;
  }

  List<Map<String, dynamic>> _getAllCustomers() {
    final box = Hive.box<Map>(AppConstants.customerBox);
    return box.values.map((m) => _mapCustomer(m)).toList();
  }

  List<Map<String, dynamic>> _getAllProducts() {
    final box = Hive.box<Map>(AppConstants.itemCatalogBox);
    return box.values.map((m) => _mapProduct(m)).toList();
  }

  List<Map<String, dynamic>> _getAllInvoices() {
    final box = Hive.box<Map>(AppConstants.invoiceBox);
    return box.values.map((m) => _mapInvoice(m)).toList();
  }

  Map<String, dynamic> _mapCustomer(Map raw) {
    final m = _toMap(raw);
    return {
      'id': m['id'],
      'name': m['name'] ?? '',
      'gstin': m['gstin'] ?? '',
      'phone': m['phone'] ?? '',
      'email': m['email'] ?? '',
      'address': m['address'] ?? '',
      'city': m['city'] ?? '',
      'state': m['state'] ?? '',
    };
  }

  Map<String, dynamic> _mapProduct(Map raw) {
    final m = _toMap(raw);
    return {
      'id': m['id'],
      'name': m['name'] ?? '',
      'description': m['description'] ?? '',
      'hsn_sac_code': m['hsnCode'] ?? '',
      'is_service': m['isService'] ?? false,
      'unit_price': (m['unitPrice'] ?? 0).toDouble(),
      'unit': m['unit'] ?? 'Nos',
      'gst_rate': (m['gstRate'] ?? 0).toDouble(),
    };
  }

  Map<String, dynamic> _mapInvoice(Map raw) {
    final m = _toMap(raw);
    final lineItems = (m['lineItems'] as List<dynamic>?)
            ?.map((li) => _mapLineItem(li as Map))
            .toList() ??
        [];

    return {
      'id': m['id'],
      'invoice_number': m['invoiceNumber'] ?? '',
      'customer_id': m['customerId'],
      'customer_name': m['customerName'] ?? '',
      'customer_gstin': m['customerGstin'] ?? '',
      'customer_phone': m['customerPhone'] ?? '',
      'customer_email': m['customerEmail'] ?? '',
      'customer_address': m['customerAddress'] ?? '',
      'customer_state': m['customerState'] ?? m['state'] ?? '',
      'invoice_date': m['invoiceDate'],
      'due_date': m['dueDate'],
      'status': m['status'] ?? 'draft',
      'is_inter_state': m['isInterState'] ?? false,
      'sub_total': (m['subTotal'] ?? 0).toDouble(),
      'total_cgst': (m['totalCgst'] ?? 0).toDouble(),
      'total_sgst': (m['totalSgst'] ?? 0).toDouble(),
      'total_igst': (m['totalIgst'] ?? 0).toDouble(),
      'total_cess': (m['totalCess'] ?? 0).toDouble(),
      'total_tax': (m['totalTax'] ?? 0).toDouble(),
      'discount_amount': (m['discountAmount'] ?? 0).toDouble(),
      'grand_total': (m['grandTotal'] ?? 0).toDouble(),
      'round_off': (m['roundOff'] ?? 0).toDouble(),
      'notes': m['notes'] ?? '',
      'terms_and_conditions': m['termsAndConditions'] ?? '',
      'gst_slabs': m['gstSlabs'] ?? [],
      'line_items': lineItems,
    };
  }

  Map<String, dynamic> _mapLineItem(Map raw) {
    final m = _toMap(raw);
    return {
      'id': m['id'],
      'description': m['description'] ?? '',
      'hsn_sac_code': m['hsnSacCode'] ?? m['hsnCode'] ?? '',
      'is_service': m['isService'] ?? false,
      'quantity': (m['quantity'] ?? 1).toDouble(),
      'unit': m['unit'] ?? 'Nos',
      'unit_price': (m['unitPrice'] ?? 0).toDouble(),
      'discount_percent': (m['discountPercent'] ?? 0).toDouble(),
      'discount_amount': (m['discountAmount'] ?? 0).toDouble(),
      'taxable_amount': (m['taxableAmount'] ?? 0).toDouble(),
      'gst_rate': (m['gstRate'] ?? 0).toDouble(),
      'cgst': (m['cgst'] ?? 0).toDouble(),
      'sgst': (m['sgst'] ?? 0).toDouble(),
      'igst': (m['igst'] ?? 0).toDouble(),
      'cess': (m['cess'] ?? 0).toDouble(),
      'total_amount': (m['totalAmount'] ?? 0).toDouble(),
      'sort_order': (m['sortOrder'] ?? 0),
    };
  }

  Map<String, dynamic> _toMap(Map raw) {
    return raw.map((k, v) => MapEntry(k.toString(), v is double ? v : v));
  }
}
