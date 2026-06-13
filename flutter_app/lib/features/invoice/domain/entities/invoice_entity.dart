// lib/features/invoice/domain/entities/invoice_entity.dart

import 'package:equatable/equatable.dart';

class InvoiceEntity extends Equatable {
  final String id;
  final String invoiceNumber;
  final String businessId;
  final String? customerId;
  final String customerName;
  final String? customerGstin;
  final String? customerPhone;
  final String? customerEmail;
  final String? customerAddress;
  final String? customerState;
  final DateTime invoiceDate;
  final DateTime? dueDate;
  final List<InvoiceLineItemEntity> lineItems;
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
  final String paymentMode;
  final bool isInterState;
  final String? notes;
  final String? termsAndConditions;
  final List<GstSlabEntity> gstSlabs;
  final DateTime createdAt;

  const InvoiceEntity({
    required this.id,
    required this.invoiceNumber,
    required this.businessId,
    this.customerId,
    required this.customerName,
    this.customerGstin,
    this.customerPhone,
    this.customerEmail,
    this.customerAddress,
    this.customerState,
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
    this.paymentMode = 'cash',
    required this.isInterState,
    this.notes,
    this.termsAndConditions,
    required this.gstSlabs,
    required this.createdAt,
  });

  bool get isDraft => status == 'draft';
  bool get isSent => status == 'sent';
  bool get isPaid => status == 'paid';
  bool get isCancelled => status == 'cancelled';

  @override
  List<Object?> get props => [id, invoiceNumber];
}

class InvoiceLineItemEntity extends Equatable {
  final String? id;
  final String? staffId;
  final String? staffName;
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

  const InvoiceLineItemEntity({
    this.id,
    this.staffId,
    this.staffName,
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

class GstSlabEntity extends Equatable {
  final double rate;
  final double taxableAmount;
  final double cgst;
  final double sgst;
  final double igst;

  const GstSlabEntity({
    required this.rate,
    required this.taxableAmount,
    required this.cgst,
    required this.sgst,
    required this.igst,
  });

  @override
  List<Object?> get props => [rate];
}

