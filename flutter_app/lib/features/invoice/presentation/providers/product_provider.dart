// lib/features/invoice/presentation/providers/product_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/local_storage.dart';

class ProductEntity {
  final String id;
  final String name;
  final String? description;
  final String? hsnSacCode;
  final bool isService;
  final double unitPrice;
  final String unit;
  final double gstRate;

  const ProductEntity({
    required this.id,
    required this.name,
    this.description,
    this.hsnSacCode,
    this.isService = false,
    required this.unitPrice,
    this.unit = 'Nos',
    this.gstRate = 18,
  });

  factory ProductEntity.fromJson(Map<String, dynamic> json) => ProductEntity(
    id: json['id']?.toString() ?? '',
    name: json['name'] ?? '',
    description: json['description'],
    hsnSacCode: json['hsnSacCode'],
    isService: json['isService'] ?? false,
    unitPrice: (json['unitPrice'] ?? 0).toDouble(),
    unit: json['unit'] ?? 'Nos',
    gstRate: (json['gstRate'] ?? 18).toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'hsnSacCode': hsnSacCode,
    'isService': isService,
    'unitPrice': unitPrice,
    'unit': unit,
    'gstRate': gstRate,
  };
}

final productListProvider = FutureProvider<List<ProductEntity>>((ref) async {
  try {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.get('/products');
    final list = response.data['products'] as List? ?? [];
    final products = list.map((e) => ProductEntity.fromJson(e as Map<String, dynamic>)).toList();
    // Cache locally for offline use
    for (final p in products) {
      await LocalStorage.saveItemCatalog(p.id, Map<String, dynamic>.from(p.toJson()));
    }
    return products;
  } catch (e) {
    // Fall back to locally cached item catalog
    final cached = LocalStorage.getAllItemCatalog();
    return cached.map((m) => ProductEntity.fromJson(Map<String, dynamic>.from(m))).toList();
  }
});

class SaveProductState {
  final bool isLoading;
  final bool isSuccess;
  final String? error;
  const SaveProductState({this.isLoading = false, this.isSuccess = false, this.error});
  SaveProductState copyWith({bool? isLoading, bool? isSuccess, String? error}) =>
      SaveProductState(isLoading: isLoading ?? this.isLoading, isSuccess: isSuccess ?? this.isSuccess, error: error);

  @override
  String toString() => 'SaveProductState(isLoading: $isLoading, isSuccess: $isSuccess, error: $error)';
}

final saveProductProvider = NotifierProvider<SaveProductNotifier, SaveProductState>(
  SaveProductNotifier.new,
);

class SaveProductNotifier extends Notifier<SaveProductState> {
  @override
  SaveProductState build() => const SaveProductState();

  Future<void> save(Map<String, dynamic> data, {String? id}) async {
    state = state.copyWith(isLoading: true);
    final productId = id ?? const Uuid().v4();
    final productData = {
      ...data,
      'id': productId,
    };
    // Always save locally first
    await LocalStorage.saveItemCatalog(productId, productData);
    ref.invalidate(productListProvider);
    state = state.copyWith(isLoading: false, isSuccess: true);

    // Try API in background (don't block UI)
    try {
      final apiClient = ref.read(apiClientProvider);
      if (id != null) {
        await apiClient.put('/products/$id', data: data);
      } else {
        await apiClient.post('/products', data: data);
      }
    } catch (_) {
      // Local save succeeded; API failure is non-blocking
    }
  }

  void reset() => state = const SaveProductState();
}

