// lib/features/customer/presentation/providers/customer_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/storage/local_storage.dart';

class CustomerEntity {
  final String id;
  final String name;
  final String? gstin;
  final String? phone;
  final String? email;
  final String? address;
  final String? city;
  final String? state;
  final int invoiceCount;
  final double totalBusiness;
  final DateTime createdAt;

  const CustomerEntity({
    required this.id,
    required this.name,
    this.gstin,
    this.phone,
    this.email,
    this.address,
    this.city,
    this.state,
    this.invoiceCount = 0,
    this.totalBusiness = 0,
    required this.createdAt,
  });

  factory CustomerEntity.fromJson(Map<String, dynamic> json) {
    return CustomerEntity(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      gstin: json['gstin'],
      phone: json['phone'],
      email: json['email'],
      address: json['address'],
      city: json['city'],
      state: json['state'],
      invoiceCount: json['invoiceCount'] ?? 0,
      totalBusiness: (json['totalBusiness'] ?? 0).toDouble(),
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'gstin': gstin,
    'phone': phone,
    'email': email,
    'address': address,
    'city': city,
    'state': state,
    'createdAt': createdAt.toIso8601String(),
  };
}

// ─── Customer List Provider ───────────────────────────────────────────────────

final customerListProvider = AsyncNotifierProvider<CustomerListNotifier, List<CustomerEntity>>(
  CustomerListNotifier.new,
);

class CustomerListNotifier extends AsyncNotifier<List<CustomerEntity>> {
  String? _searchQuery;

  @override
  Future<List<CustomerEntity>> build() async {
    return _fetchCustomers();
  }

  Future<List<CustomerEntity>> _fetchCustomers() async {
    // Load local cache immediately
    final cached = LocalStorage.getAllCachedCustomers();
    final localList = cached
        .map((m) => CustomerEntity.fromJson(Map<String, dynamic>.from(m)))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Try to refresh from backend in background
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get(
        ApiConstants.customers,
        queryParameters: {
          if (_searchQuery != null && _searchQuery!.isNotEmpty) 'search': _searchQuery,
        },
      );
      final list = (response.data['customers'] as List? ?? [])
          .map((e) => CustomerEntity.fromJson(e as Map<String, dynamic>))
          .toList();
      for (final c in list) LocalStorage.cacheCustomer(c.id, c.toJson());
      return list;
    } catch (_) {
      // Return local cache
      if (_searchQuery != null && _searchQuery!.isNotEmpty) {
        final q = _searchQuery!.toLowerCase();
        return localList.where((c) =>
          c.name.toLowerCase().contains(q) ||
          (c.phone ?? '').contains(q) ||
          (c.gstin ?? '').toLowerCase().contains(q)
        ).toList();
      }
      return localList;
    }
  }

  Future<void> search(String query) async {
    _searchQuery = query;
    state = const AsyncLoading();
    state = AsyncData(await _fetchCustomers());
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _fetchCustomers());
  }

  void addCustomer(CustomerEntity customer) {
    final current = state.valueOrNull ?? [];
    state = AsyncData([customer, ...current]);
  }

  void removeCustomer(String id) {
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.where((c) => c.id != id).toList());
  }
}

// ─── Add Customer Provider ────────────────────────────────────────────────────

class AddCustomerState {
  final bool isLoading;
  final bool isSuccess;
  final String? error;
  final CustomerEntity? addedCustomer;

  const AddCustomerState({this.isLoading = false, this.isSuccess = false, this.error, this.addedCustomer});

  AddCustomerState copyWith({bool? isLoading, bool? isSuccess, String? error, CustomerEntity? addedCustomer}) {
    return AddCustomerState(
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      error: error,
      addedCustomer: addedCustomer ?? this.addedCustomer,
    );
  }
}

final addCustomerProvider = NotifierProvider<AddCustomerNotifier, AddCustomerState>(
  AddCustomerNotifier.new,
);

class AddCustomerNotifier extends Notifier<AddCustomerState> {
  @override
  AddCustomerState build() => const AddCustomerState();

  Future<void> addCustomer(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Try backend first
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post(ApiConstants.customers, data: data);
      final customer = CustomerEntity.fromJson(response.data['customer'] ?? response.data);
      LocalStorage.cacheCustomer(customer.id, customer.toJson());
      ref.read(customerListProvider.notifier).addCustomer(customer);
      state = state.copyWith(isLoading: false, isSuccess: true, addedCustomer: customer);
    } catch (_) {
      // Backend unavailable — save locally
      final id = 'cust-${const Uuid().v4().substring(0, 8)}';
      final customer = CustomerEntity(
        id: id,
        name: data['name'] ?? '',
        gstin: data['gstin'] as String?,
        phone: data['phone'] as String?,
        email: data['email'] as String?,
        address: data['address'] as String?,
        city: data['city'] as String?,
        state: data['stateName'] as String?,
        createdAt: DateTime.now(),
      );
      final json = {
        ...customer.toJson(),
        'id': id,
        'createdAt': DateTime.now().toIso8601String(),
      };
      await LocalStorage.cacheCustomer(id, json);
      ref.read(customerListProvider.notifier).addCustomer(customer);
      state = state.copyWith(isLoading: false, isSuccess: true, addedCustomer: customer);
    }
  }

  void reset() => state = const AddCustomerState();
}

