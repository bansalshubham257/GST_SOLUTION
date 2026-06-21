import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/storage/local_storage.dart';
import '../../../invoice/data/models/item_catalog_entry.dart';
import '../../../invoice/presentation/providers/item_catalog_provider.dart';
import '../../../staff/domain/entities/staff_entity.dart';

class ServiceEntryState {
  final String? selectedStaffId;
  final String? selectedStaffName;
  final double staffCommissionPercentage;
  final List<ServiceEntryItem> services;
  final String paymentMode;
  final String paymentStatus; // 'paid' or 'unpaid'
  final String? customerId;
  final String? customerName;
  final String? customerPhone;
  final String? customerGstin;
  final String? customerState;
  final double discountPercent;
  final bool isSaving;
  final bool isSuccess;
  final String? error;

  const ServiceEntryState({
    this.selectedStaffId,
    this.selectedStaffName,
    this.staffCommissionPercentage = 0,
    this.services = const [],
    this.paymentMode = 'cash',
    this.paymentStatus = 'paid',
    this.customerId,
    this.customerName,
    this.customerPhone,
    this.customerGstin,
    this.customerState,
    this.discountPercent = 0,
    this.isSaving = false,
    this.isSuccess = false,
    this.error,
  });

  ServiceEntryState copyWith({
    String? selectedStaffId,
    String? selectedStaffName,
    double? staffCommissionPercentage,
    List<ServiceEntryItem>? services,
    String? paymentMode,
    String? paymentStatus,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? customerGstin,
    String? customerState,
    double? discountPercent,
    bool? isSaving,
    bool? isSuccess,
    String? error,
  }) {
    return ServiceEntryState(
      selectedStaffId: selectedStaffId ?? this.selectedStaffId,
      selectedStaffName: selectedStaffName ?? this.selectedStaffName,
      staffCommissionPercentage:
          staffCommissionPercentage ?? this.staffCommissionPercentage,
      services: services ?? this.services,
      paymentMode: paymentMode ?? this.paymentMode,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerGstin: customerGstin ?? this.customerGstin,
      customerState: customerState ?? this.customerState,
      discountPercent: discountPercent ?? this.discountPercent,
      isSaving: isSaving ?? this.isSaving,
      isSuccess: isSuccess ?? this.isSuccess,
      error: error,
    );
  }

  double get subTotal =>
      services.fold(0, (sum, s) => sum + (s.quantity * s.unitPrice));

  double get totalGst => services.fold(0, (sum, s) {
        final taxable = s.quantity * s.unitPrice;
        return sum + (taxable * s.gstRate / 100);
      });

  double get discountAmount => subTotal * discountPercent / 100;

  double get grandTotal => subTotal + totalGst - discountAmount;

  double get totalCommission => services.fold(0, (sum, s) {
        final taxable = s.quantity * s.unitPrice;
        return sum + (taxable * staffCommissionPercentage / 100);
      });
}

class ServiceEntryItem {
  final String serviceId;
  final String serviceName;
  final double quantity;
  final double unitPrice;
  final double gstRate;
  final String? hsnCode;

  const ServiceEntryItem({
    required this.serviceId,
    required this.serviceName,
    this.quantity = 1,
    required this.unitPrice,
    required this.gstRate,
    this.hsnCode,
  });
}

final serviceEntryProvider =
    NotifierProvider<ServiceEntryNotifier, ServiceEntryState>(
  ServiceEntryNotifier.new,
);

class ServiceEntryNotifier extends Notifier<ServiceEntryState> {
  @override
  ServiceEntryState build() => const ServiceEntryState();

  void selectStaff(StaffEntity staff) {
    state = state.copyWith(
      selectedStaffId: staff.id,
      selectedStaffName: staff.name,
      staffCommissionPercentage: staff.commissionPercentage,
    );
  }

  void addService(ItemCatalogEntry service) {
    final exists = state.services.any((s) => s.serviceId == service.id);
    if (exists) return;

    final item = ServiceEntryItem(
      serviceId: service.id,
      serviceName: service.name,
      quantity: 1,
      unitPrice: service.unitPrice,
      gstRate: service.gstRate,
      hsnCode: service.hsnCode,
    );
    state = state.copyWith(services: [...state.services, item]);
  }

  void removeService(String serviceId) {
    state = state.copyWith(
      services: state.services.where((s) => s.serviceId != serviceId).toList(),
    );
  }

  void updateQuantity(String serviceId, double qty) {
    state = state.copyWith(
      services: state.services.map((s) {
        if (s.serviceId == serviceId) {
          return ServiceEntryItem(
            serviceId: s.serviceId,
            serviceName: s.serviceName,
            quantity: qty.clamp(0.5, 999),
            unitPrice: s.unitPrice,
            gstRate: s.gstRate,
            hsnCode: s.hsnCode,
          );
        }
        return s;
      }).toList(),
    );
  }

  void setPaymentMode(String mode) {
    state = state.copyWith(paymentMode: mode);
  }

  void setPaymentStatus(String status) {
    state = state.copyWith(paymentStatus: status);
  }

  void setDiscount(double percent) {
    state = state.copyWith(discountPercent: percent.clamp(0, 100));
  }

  void setCustomer(String id, String name, String phone, {String? gstin, String? stateName}) {
    state = state.copyWith(
      customerId: id,
      customerName: name,
      customerPhone: phone,
      customerGstin: gstin,
      customerState: stateName,
    );
  }

  void clearCustomer() {
    state = state.copyWith(
      customerId: null,
      customerName: null,
      customerPhone: null,
    );
  }

  Future<void> saveServiceEntry() async {
    if (state.services.isEmpty) return;

    state = state.copyWith(isSaving: true, error: null);
    try {
      final id = 'srv-${const Uuid().v4().substring(0, 8)}';
      final now = DateTime.now();
      final invoiceNum =
          'SRV${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';

      final lineItems = state.services.map((s) {
        final taxable = s.quantity * s.unitPrice;
        final gstAmt = taxable * s.gstRate / 100;
        return {
          'description': s.serviceName,
          'hsnCode': s.hsnCode,
          if (state.selectedStaffId != null) 'staffId': state.selectedStaffId,
          if (state.selectedStaffName != null) 'staffName': state.selectedStaffName,
          'quantity': s.quantity,
          'unit': 'Nos',
          'unitPrice': s.unitPrice,
          'gstRate': s.gstRate,
          'taxableAmount': taxable,
          'cgst': gstAmt / 2,
          'sgst': gstAmt / 2,
          'igst': 0,
          'totalAmount': taxable + gstAmt,
        };
      }).toList();

      final slabMap = <int, Map<String, dynamic>>{};
      for (final item in lineItems) {
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

      final invoiceData = {
        'id': id,
        'invoiceNumber': invoiceNum,
        'customerName': state.customerName ?? 'Walk-in Customer',
        'customerId': state.customerId,
        'customerPhone': state.customerPhone,
        'customerGstin': state.customerGstin,
        'state': state.customerState,
        'invoiceDate': now.toIso8601String(),
        'status': 'paid',
        'paymentStatus': state.paymentStatus,
        'paymentMode': state.paymentMode,
        'isInterState': false,
        'lineItems': lineItems,
        'subTotal': state.subTotal,
        'totalCgst': state.totalGst / 2,
        'totalSgst': state.totalGst / 2,
        'totalIgst': 0,
        'totalTax': state.totalGst,
        'discountPercent': state.discountPercent,
        'discountAmount': state.discountAmount,
        'grandTotal': state.grandTotal,
        'roundOff': 0,
        'commissionAmount': state.totalCommission,
        'createdAt': now.toIso8601String(),
        'gstSlabs': slabMap.values.toList(),
      };

      await LocalStorage.cacheInvoice(id, invoiceData);

      // Reduce stock for sold items
      final catalog = ref.read(itemCatalogProvider.notifier);
      for (final s in state.services) {
        final match = catalog.findByName(s.serviceName);
        if (match != null && !match.isService) {
          await catalog.adjustStock(match.id, -s.quantity);
        }
      }

      state = state.copyWith(isSaving: false, isSuccess: true);
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
    }
  }

  void reset() {
    state = const ServiceEntryState();
  }
}
