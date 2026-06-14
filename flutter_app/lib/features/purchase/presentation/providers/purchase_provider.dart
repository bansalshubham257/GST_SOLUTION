import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/utils/plan_limits.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../invoice/domain/entities/invoice_entity.dart';
import '../../domain/entities/purchase_entity.dart';

final purchaseListProvider = AsyncNotifierProvider<PurchaseListNotifier, List<PurchaseEntity>>(
  PurchaseListNotifier.new,
);

class PurchaseListNotifier extends AsyncNotifier<List<PurchaseEntity>> {
  @override
  Future<List<PurchaseEntity>> build() async {
    return _fetchPurchases(reset: true);
  }

  Future<List<PurchaseEntity>> _fetchPurchases({bool reset = false}) async {
    final cached = LocalStorage.getAllCachedPurchases();
    final localList = cached
        .map((m) => PurchaseEntityJson.fromJson(_deepConvert(m) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (reset && localList.isNotEmpty) {
      return localList;
    }

    return localList;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _fetchPurchases(reset: true));
  }
}

dynamic _deepConvert(dynamic value) {
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), _deepConvert(v)));
  }
  if (value is List) {
    return value.map((e) => _deepConvert(e)).toList();
  }
  return value;
}

class CreatePurchaseState {
  final bool isLoading;
  final bool isSuccess;
  final String? error;
  final PurchaseEntity? createdPurchase;

  const CreatePurchaseState({
    this.isLoading = false,
    this.isSuccess = false,
    this.error,
    this.createdPurchase,
  });

  CreatePurchaseState copyWith({bool? isLoading, bool? isSuccess, String? error, PurchaseEntity? createdPurchase}) {
    return CreatePurchaseState(
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      error: error,
      createdPurchase: createdPurchase ?? this.createdPurchase,
    );
  }
}

final createPurchaseProvider = NotifierProvider<CreatePurchaseNotifier, CreatePurchaseState>(
  CreatePurchaseNotifier.new,
);

class CreatePurchaseNotifier extends Notifier<CreatePurchaseState> {
  @override
  CreatePurchaseState build() => const CreatePurchaseState();

  Future<void> createPurchase(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true);
    try {
      final id = const Uuid().v4();
      final purchaseNumber = _generateLocalPurchaseNumber();

      final purchaseData = {
        ...data,
        'id': id,
        'purchaseNumber': purchaseNumber,
        'createdAt': DateTime.now().toIso8601String(),
      };

      final purchase = PurchaseEntityJson.fromJson(purchaseData);
      await LocalStorage.cachePurchase(id, purchase.toJson());

      ref.read(purchaseListProvider.notifier).refresh();
      state = state.copyWith(isLoading: false, isSuccess: true, createdPurchase: purchase);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to create purchase locally');
    }
  }

  String _generateLocalPurchaseNumber() {
    final purchases = LocalStorage.getAllCachedPurchases();
    final count = purchases.length + 1;
    final year = DateTime.now().year.toString().substring(2);
    final month = DateTime.now().month.toString().padLeft(2, '0');
    return 'PUR-$year$month-${count.toString().padLeft(4, '0')}';
  }

  Future<void> cancelPurchase(String id) async {
    state = state.copyWith(isLoading: true);
    try {
      final cached = LocalStorage.getCachedPurchase(id);
      if (cached != null) {
        final updated = Map<String, dynamic>.from(cached)..['status'] = 'cancelled';
        await LocalStorage.cachePurchase(id, updated);
        ref.read(purchaseListProvider.notifier).refresh();
        state = state.copyWith(isLoading: false, isSuccess: true);
      } else {
        state = state.copyWith(isLoading: false, error: 'Purchase not found in cache');
        return;
      }

      try {
        final apiClient = ref.read(apiClientProvider);
        await apiClient.post('/purchases/$id/cancel');
      } catch (_) {}
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to cancel purchase');
    }
  }

  void reset() => state = const CreatePurchaseState();
}

extension PurchaseEntityJson on PurchaseEntity {
  static PurchaseEntity fromJson(Map<String, dynamic> json) {
    return PurchaseEntity(
      id: json['id']?.toString() ?? '',
      purchaseNumber: json['purchaseNumber'] ?? '',
      businessId: json['businessId']?.toString() ?? '',
      supplierName: json['supplierName'] ?? '',
      supplierGstin: json['supplierGstin'],
      supplierPhone: json['supplierPhone'],
      supplierEmail: json['supplierEmail'],
      supplierAddress: json['supplierAddress'],
      invoiceDate: DateTime.tryParse(json['invoiceDate'] ?? '') ?? DateTime.now(),
      dueDate: json['dueDate'] != null ? DateTime.tryParse(json['dueDate']) : null,
      lineItems: (json['lineItems'] as List? ?? [])
          .map((e) => PurchaseLineItemJson.fromJson(e as Map<String, dynamic>))
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
      paymentStatus: json['paymentStatus'] ?? 'unpaid',
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
    'purchaseNumber': purchaseNumber,
    'businessId': businessId,
    'supplierName': supplierName,
    'supplierGstin': supplierGstin,
    'supplierPhone': supplierPhone,
    'supplierEmail': supplierEmail,
    'supplierAddress': supplierAddress,
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
    'paymentStatus': paymentStatus,
    'isInterState': isInterState,
    'notes': notes,
    'termsAndConditions': termsAndConditions,
    'gstSlabs': gstSlabs.map((e) => e.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
  };
}

extension PurchaseLineItemJson on PurchaseLineItemEntity {
  static PurchaseLineItemEntity fromJson(Map<String, dynamic> json) {
    return PurchaseLineItemEntity(
      id: json['id']?.toString(),
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


