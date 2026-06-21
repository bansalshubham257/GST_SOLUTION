// lib/features/invoice/presentation/providers/invoice_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/utils/plan_limits.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/invoice_entity.dart';

// ─── Invoice List Provider ────────────────────────────────────────────────────

final invoiceListProvider = AsyncNotifierProvider<InvoiceListNotifier, List<InvoiceEntity>>(
  InvoiceListNotifier.new,
);

class InvoiceListNotifier extends AsyncNotifier<List<InvoiceEntity>> {
  int _page = 1;
  bool hasMore = true;
  String? _searchQuery;
  String? _statusFilter;

  @override
  Future<List<InvoiceEntity>> build() async {
    return _fetchInvoices(reset: true);
  }

  Future<List<InvoiceEntity>> _fetchInvoices({bool reset = false}) async {
    if (reset) { _page = 1; hasMore = true; }

    // Phase 1: Always use local cache first
    final cached = LocalStorage.getAllCachedInvoices();
    final localList = cached
        .map((m) => InvoiceEntityJson.fromJson(_deepConvert(m) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (reset && localList.isNotEmpty) {
      // For Phase 1, we can stop here or try background sync if desired
      // but the user wants local-first/cache only for now.
      return localList;
    }

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get(
        ApiConstants.invoices,
        queryParameters: {
          'page': _page,
          'limit': 20,
          if (_searchQuery != null && _searchQuery!.isNotEmpty) 'search': _searchQuery,
          if (_statusFilter != null) 'status': _statusFilter,
        },
      );

      final list = (response.data['invoices'] as List? ?? [])
          .map((e) => InvoiceEntityJson.fromJson(e as Map<String, dynamic>))
          .toList();

      hasMore = list.length == 20;

      // Cache for offline
      for (final inv in list) {
        LocalStorage.cacheInvoice(inv.id, inv.toJson());
      }

      if (reset) return list;

      final current = state.valueOrNull ?? [];
      return [...current, ...list];
    } catch (e) {
      // Return cached invoices on error
      final cached = LocalStorage.getAllCachedInvoices();
      return cached.map((m) => InvoiceEntityJson.fromJson(_deepConvert(m) as Map<String, dynamic>)).toList();
    }
  }

  Future<void> loadMore() async {
    if (!hasMore || state.isLoading) return;
    _page++;
    final newList = await _fetchInvoices();
    state = AsyncData(newList);
  }

  Future<void> search(String query) async {
    _searchQuery = query;
    // Instant client-side filter to avoid skeleton flash
    final current = state.valueOrNull ?? [];
    if (current.isNotEmpty) {
      final filtered = query.isEmpty
          ? current
          : current.where((inv) =>
              inv.customerName.toLowerCase().contains(query.toLowerCase()) ||
              inv.invoiceNumber.toLowerCase().contains(query.toLowerCase())).toList();
      state = AsyncData(filtered);
    } else {
      state = const AsyncLoading();
    }
    state = AsyncData(await _fetchInvoices(reset: true));
  }

  Future<void> filterByStatus(String? status) async {
    _statusFilter = status;
    // Instant client-side filter to avoid skeleton flash
    final current = state.valueOrNull ?? [];
    if (current.isNotEmpty) {
      final filtered = status == null
          ? current
          : current.where((inv) => inv.status.toLowerCase() == status.toLowerCase()).toList();
      state = AsyncData(filtered);
    } else {
      state = const AsyncLoading();
    }
    state = AsyncData(await _fetchInvoices(reset: true));
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _fetchInvoices(reset: true));
  }

  Future<void> removeInvoice(String id) async {
    await LocalStorage.deleteInvoice(id);
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.delete('/invoices/$id');
    } catch (_) {}
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.where((inv) => inv.id != id).toList());
  }

  void updateInvoice(InvoiceEntity updated) {
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.map((inv) => inv.id == updated.id ? updated : inv).toList());
  }
}

// ─── Single Invoice Provider ──────────────────────────────────────────────────

/// Recursively convert Hive's Map<dynamic,dynamic> to Map<String,dynamic>
dynamic _deepConvert(dynamic value) {
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), _deepConvert(v)));
  }
  if (value is List) {
    return value.map((e) => _deepConvert(e)).toList();
  }
  return value;
}

final invoiceDetailProvider = FutureProvider.family<InvoiceEntity?, String>((ref, id) async {
  // Phase 1: Local-first — search all cached invoices by id field
  try {
    final allCached = LocalStorage.getAllCachedInvoices();
    for (final raw in allCached) {
      if (raw['id']?.toString() == id) {
        return InvoiceEntityJson.fromJson(_deepConvert(raw) as Map<String, dynamic>);
      }
    }
  } catch (_) {
    // Cache scan failed; fall through to API attempt
  }

  // API fallback (non-blocking best-effort)
  try {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.get('/invoices/$id');
    final entity = InvoiceEntityJson.fromJson(response.data as Map<String, dynamic>);
    LocalStorage.cacheInvoice(id, entity.toJson());
    return entity;
  } catch (_) {
    // API unavailable; return null (caller shows "not found")
  }

  return null;
});

// ─── Create Invoice State ─────────────────────────────────────────────────────

class CreateInvoiceState {
  final bool isLoading;
  final bool isSuccess;
  final String? error;
  final InvoiceEntity? createdInvoice;

  const CreateInvoiceState({
    this.isLoading = false,
    this.isSuccess = false,
    this.error,
    this.createdInvoice,
  });

  CreateInvoiceState copyWith({bool? isLoading, bool? isSuccess, String? error, InvoiceEntity? createdInvoice}) {
    return CreateInvoiceState(
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      error: error,
      createdInvoice: createdInvoice ?? this.createdInvoice,
    );
  }
}

final createInvoiceProvider = NotifierProvider<CreateInvoiceNotifier, CreateInvoiceState>(
  CreateInvoiceNotifier.new,
);

class CreateInvoiceNotifier extends Notifier<CreateInvoiceState> {
  @override
  CreateInvoiceState build() => const CreateInvoiceState();

  Future<void> createInvoice(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true);
    try {
      // Plan limit check
      final authState = ref.read(authStateProvider).valueOrNull;
      final maxSales = authState?.user?.maxSales ?? 999;
      final salesCount = LocalStorage.getAllCachedInvoices().length;
      if (PlanLimits.isLimitReached(salesCount, maxSales)) {
        state = state.copyWith(
          isLoading: false,
          error: 'You have reached the free plan limit of $maxSales sales.',
        );
        return;
      }

      // Phase 1: Local-only creation
      final id = const Uuid().v4();
      final invoiceNumber = _generateLocalInvoiceNumber();
      
      final invoiceData = {
        ...data,
        'id': id,
        'invoiceNumber': invoiceNumber,
        'createdAt': DateTime.now().toIso8601String(),
      };

      final invoice = InvoiceEntityJson.fromJson(invoiceData);
      await LocalStorage.cacheInvoice(id, invoice.toJson());
      
      ref.read(invoiceListProvider.notifier).refresh();
      state = state.copyWith(isLoading: false, isSuccess: true, createdInvoice: invoice);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to create invoice locally');
    }
  }

  String _generateLocalInvoiceNumber() {
    final invoices = LocalStorage.getAllCachedInvoices();
    final count = invoices.length + 1;
    final year = DateTime.now().year.toString().substring(2);
    final month = DateTime.now().month.toString().padLeft(2, '0');
    return 'INV-$year$month-${count.toString().padLeft(4, '0')}';
  }

  Future<void> updateInvoice(String id, Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true);
    try {
      final invoiceData = {
        ...data,
        'id': id,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      final invoice = InvoiceEntityJson.fromJson(invoiceData);
      await LocalStorage.cacheInvoice(id, invoice.toJson());
      
      ref.read(invoiceListProvider.notifier).updateInvoice(invoice);
      state = state.copyWith(isLoading: false, isSuccess: true, createdInvoice: invoice);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to update invoice locally');
    }
  }

  Future<void> cancelInvoice(String id) async {
    state = state.copyWith(isLoading: true);
    try {
      // Update locally first
      final cached = LocalStorage.getCachedInvoice(id);
      if (cached != null) {
        final updated = Map<String, dynamic>.from(cached)..['status'] = 'cancelled';
        await LocalStorage.cacheInvoice(id, updated);
        ref.invalidate(invoiceDetailProvider(id));
        ref.read(invoiceListProvider.notifier).refresh();
        state = state.copyWith(isLoading: false, isSuccess: true);
      } else {
        state = state.copyWith(isLoading: false, error: 'Invoice not found in cache');
        return;
      }

      // Try API in background (non-blocking)
      try {
        final apiClient = ref.read(apiClientProvider);
        await apiClient.post('/invoices/$id/cancel');
      } catch (_) {}
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to cancel invoice');
    }
  }

  void reset() => state = const CreateInvoiceState();
}

// Extension for JSON serialization
extension InvoiceEntityJson on InvoiceEntity {
  static InvoiceEntity fromJson(Map<String, dynamic> json) {
    return InvoiceEntity(
      id: json['id']?.toString() ?? '',
      invoiceNumber: json['invoiceNumber'] ?? '',
      businessId: json['businessId']?.toString() ?? '',
      customerId: json['customerId']?.toString(),
      customerName: json['customerName'] ?? '',
      customerGstin: json['customerGstin'],
      customerPhone: json['customerPhone'],
      customerEmail: json['customerEmail'],
      customerAddress: json['customerAddress'],
      customerState: json['customerState'] ?? json['state'],
      invoiceDate: DateTime.tryParse(json['invoiceDate'] ?? '') ?? DateTime.now(),
      dueDate: json['dueDate'] != null ? DateTime.tryParse(json['dueDate']) : null,
      lineItems: (json['lineItems'] as List? ?? [])
          .map((e) => InvoiceLineItemJson.fromJson(e as Map<String, dynamic>))
          .toList(),
      subTotal: (json['subTotal'] ?? 0).toDouble(),
      totalCgst: (json['totalCgst'] ?? 0).toDouble(),
      totalSgst: (json['totalSgst'] ?? 0).toDouble(),
      totalIgst: (json['totalIgst'] ?? 0).toDouble(),
      totalCess: (json['totalCess'] ?? 0).toDouble(),
      totalTax: (json['totalTax'] ?? 0).toDouble(),
      discountAmount: (json['discountAmount'] ?? 0).toDouble(),
      grandTotal: (json['grandTotal'] ?? 0).toDouble(),
      roundOff: (json['roundOff'] ?? 0).toDouble(),
      status: json['status'] ?? 'draft',
      paymentMode: json['paymentMode'] ?? 'cash',
      paymentStatus: json['paymentStatus'] ?? (json['status'] == 'paid' ? 'paid' : 'unpaid'),
      isInterState: json['isInterState'] ?? false,
      notes: json['notes'],
      termsAndConditions: json['termsAndConditions'],
      gstSlabs: (json['gstSlabs'] as List? ?? [])
          .map((e) => GstSlabEntity.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'invoiceNumber': invoiceNumber,
    'businessId': businessId,
    'customerId': customerId,
    'customerName': customerName,
    'customerGstin': customerGstin,
    'customerPhone': customerPhone,
    'customerEmail': customerEmail,
    'customerAddress': customerAddress,
    'customerState': customerState,
    'state': customerState,
    'invoiceDate': invoiceDate.toIso8601String(),
    'dueDate': dueDate?.toIso8601String(),
    'lineItems': lineItems.map((e) => e.toJson()).toList(),
    'subTotal': subTotal,
    'totalCgst': totalCgst,
    'totalSgst': totalSgst,
    'totalIgst': totalIgst,
    'totalCess': totalCess,
    'totalTax': totalTax,
    'discountAmount': discountAmount,
    'grandTotal': grandTotal,
    'roundOff': roundOff,
    'status': status,
    'paymentMode': paymentMode,
    'paymentStatus': paymentStatus,
    'isInterState': isInterState,
    'notes': notes,
    'termsAndConditions': termsAndConditions,
    'gstSlabs': gstSlabs.map((e) => e.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
  };
}

extension InvoiceLineItemJson on InvoiceLineItemEntity {
  static InvoiceLineItemEntity fromJson(Map<String, dynamic> json) {
    return InvoiceLineItemEntity(
      id: json['id']?.toString(),
      staffId: json['staffId']?.toString(),
      staffName: json['staffName'],
      description: json['description'] ?? '',
      hsnSacCode: json['hsnSacCode'] ?? json['hsnCode'],
      isService: json['isService'] ?? false,
      quantity: (json['quantity'] ?? 1).toDouble(),
      unit: json['unit'] ?? 'Nos',
      unitPrice: (json['unitPrice'] ?? 0).toDouble(),
      discountPercent: (json['discountPercent'] ?? 0).toDouble(),
      discountAmount: (json['discountAmount'] ?? 0).toDouble(),
      taxableAmount: (json['taxableAmount'] ?? 0).toDouble(),
      gstRate: (json['gstRate'] ?? 0).toDouble(),
      cgst: (json['cgst'] ?? 0).toDouble(),
      sgst: (json['sgst'] ?? 0).toDouble(),
      igst: (json['igst'] ?? 0).toDouble(),
      cess: (json['cess'] ?? 0).toDouble(),
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'staffId': staffId,
    'staffName': staffName,
    'description': description,
    'hsnSacCode': hsnSacCode,
    'hsnCode': hsnSacCode,
    'isService': isService,
    'quantity': quantity,
    'unit': unit,
    'unitPrice': unitPrice,
    'discountPercent': discountPercent,
    'discountAmount': discountAmount,
    'taxableAmount': taxableAmount,
    'gstRate': gstRate,
    'cgst': cgst,
    'sgst': sgst,
    'igst': igst,
    'cess': cess,
    'totalAmount': totalAmount,
  };
}



