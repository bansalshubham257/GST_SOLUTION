import 'package:equatable/equatable.dart';
import '../../../invoice/domain/entities/invoice_entity.dart';

class PurchaseEntity extends Equatable {
  final String id;
  final String purchaseNumber;
  final String businessId;
  final String supplierName;
  final String? supplierGstin;
  final String? supplierPhone;
  final String? supplierEmail;
  final String? supplierAddress;
  final DateTime invoiceDate;
  final DateTime? dueDate;
  final List<PurchaseLineItemEntity> lineItems;
  final double subTotal;
  final double totalCgst;
  final double totalSgst;
  final double totalIgst;
  final double totalCess;
  final double totalTax;
  final double discountAmount;
  final double grandTotal;
  final double roundOff;
  final String status;
  final String paymentStatus;
  final bool isInterState;
  final String? notes;
  final String? termsAndConditions;
  final List<GstSlabEntity> gstSlabs;
  final DateTime createdAt;

  const PurchaseEntity({
    required this.id,
    required this.purchaseNumber,
    required this.businessId,
    required this.supplierName,
    this.supplierGstin,
    this.supplierPhone,
    this.supplierEmail,
    this.supplierAddress,
    required this.invoiceDate,
    this.dueDate,
    required this.lineItems,
    required this.subTotal,
    required this.totalCgst,
    required this.totalSgst,
    required this.totalIgst,
    required this.totalCess,
    required this.totalTax,
    required this.discountAmount,
    required this.grandTotal,
    required this.roundOff,
    required this.status,
    this.paymentStatus = 'unpaid',
    required this.isInterState,
    this.notes,
    this.termsAndConditions,
    required this.gstSlabs,
    required this.createdAt,
  });

  bool get isDraft => status == 'draft';
  bool get isPaid => status == 'paid';
  bool get isCancelled => status == 'cancelled';

  @override
  List<Object?> get props => [id, purchaseNumber];
}

class PurchaseLineItemEntity extends Equatable {
  final String? id;
  final String description;
  final String? hsnSacCode;
  final bool isService;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double discountPercent;
  final double discountAmount;
  final double taxableAmount;
  final double gstRate;
  final double cgst;
  final double sgst;
  final double igst;
  final double cess;
  final double totalAmount;

  const PurchaseLineItemEntity({
    this.id,
    required this.description,
    this.hsnSacCode,
    this.isService = false,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    this.discountPercent = 0,
    required this.discountAmount,
    required this.taxableAmount,
    required this.gstRate,
    required this.cgst,
    required this.sgst,
    required this.igst,
    this.cess = 0,
    required this.totalAmount,
  });

  @override
  List<Object?> get props => [id, description];
}


