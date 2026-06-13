// lib/features/staff/presentation/providers/staff_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/storage/local_storage.dart';
import '../../domain/entities/staff_entity.dart';

final staffListProvider = AsyncNotifierProvider<StaffListNotifier, List<StaffEntity>>(
  StaffListNotifier.new,
);

class StaffListNotifier extends AsyncNotifier<List<StaffEntity>> {
  @override
  Future<List<StaffEntity>> build() async {
    return _fetchStaff();
  }

  Future<List<StaffEntity>> _fetchStaff() async {
    final cached = LocalStorage.staffBox.values.toList();
    final staffList = cached
        .map((m) => StaffEntity.fromJson(Map<String, dynamic>.from(m)))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Compute revenue from cached invoices
    final invoices = LocalStorage.getAllCachedInvoices();
    final Map<String, double> revenueMap = {};
    final Map<String, double> commissionMap = {};

    for (final raw in invoices) {
      final inv = Map<String, dynamic>.from(raw);
      final lineItems = (inv['lineItems'] as List? ?? []);
      for (final itemRaw in lineItems) {
        final item = Map<String, dynamic>.from(itemRaw);
        final staffId = item['staffId']?.toString();
        if (staffId != null && staffId.isNotEmpty) {
          final taxable = (item['unitPrice'] ?? 0).toDouble() * (item['quantity'] ?? 1).toDouble();
          revenueMap[staffId] = (revenueMap[staffId] ?? 0) + taxable;
          commissionMap[staffId] = (commissionMap[staffId] ?? 0) + taxable;
        }
      }
    }

    return staffList.map((staff) {
      final rev = revenueMap[staff.id] ?? 0;
      final commPct = staff.commissionPercentage;
      final commission = rev * (commPct / 100);
      return staff.copyWith(
        totalRevenue: rev,
        totalCommission: commission,
      );
    }).toList();
  }

  Future<void> addStaff(StaffEntity staff) async {
    state = const AsyncLoading();
    await LocalStorage.staffBox.put(staff.id, staff.toJson());
    state = AsyncData(await _fetchStaff());
  }

  Future<void> updateStaff(StaffEntity staff) async {
    state = const AsyncLoading();
    await LocalStorage.staffBox.put(staff.id, staff.toJson());
    state = AsyncData(await _fetchStaff());
  }

  Future<void> deleteStaff(String id) async {
    state = const AsyncLoading();
    await LocalStorage.staffBox.delete(id);
    state = AsyncData(await _fetchStaff());
  }
}

class StaffFormState {
  final bool isLoading;
  final bool isSuccess;
  final String? error;

  const StaffFormState({this.isLoading = false, this.isSuccess = false, this.error});

  StaffFormState copyWith({bool? isLoading, bool? isSuccess, String? error}) {
    return StaffFormState(
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      error: error,
    );
  }
}

final staffFormProvider = NotifierProvider<StaffFormNotifier, StaffFormState>(
  StaffFormNotifier.new,
);

class StaffFormNotifier extends Notifier<StaffFormState> {
  @override
  StaffFormState build() => const StaffFormState();

  Future<void> saveStaff({
    String? id,
    required String name,
    String? role,
    String? phone,
    double? commissionPercentage,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final isNew = id == null;
      final staffId = id ?? const Uuid().v4();
      
      final staff = StaffEntity(
        id: staffId,
        name: name,
        role: role,
        phone: phone,
        commissionPercentage: commissionPercentage ?? 0,
        createdAt: isNew ? DateTime.now() : DateTime.now(), // Simplified
      );

      if (isNew) {
        await ref.read(staffListProvider.notifier).addStaff(staff);
      } else {
        await ref.read(staffListProvider.notifier).updateStaff(staff);
      }
      
      state = state.copyWith(isLoading: false, isSuccess: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void reset() => state = const StaffFormState();
}
