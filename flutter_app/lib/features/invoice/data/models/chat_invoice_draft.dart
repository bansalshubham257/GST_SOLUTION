// lib/features/invoice/data/models/chat_invoice_draft.dart

/// Represents an item being built through the chat flow
class ChatLineItem {
  final String name;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double gstRate;
  final String? hsnCode;

  const ChatLineItem({
    required this.name,
    required this.quantity,
    this.unit = 'Nos',
    required this.unitPrice,
    required this.gstRate,
    this.hsnCode,
  });

  double get taxableAmount => quantity * unitPrice;
  double get totalAmount => taxableAmount * (1 + gstRate / 100);

  ChatLineItem copyWith({
    String? name,
    double? quantity,
    String? unit,
    double? unitPrice,
    double? gstRate,
    String? hsnCode,
  }) {
    return ChatLineItem(
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      gstRate: gstRate ?? this.gstRate,
      hsnCode: hsnCode ?? this.hsnCode,
    );
  }

  @override
  String toString() =>
      '${quantity.toStringAsFixed(quantity % 1 == 0 ? 0 : 2)} $unit × $name @ ₹${unitPrice.toStringAsFixed(0)} + ${gstRate.toStringAsFixed(0)}% GST';
}

/// Partial item being filled during conversation
class ChatLineItemDraft {
  final String? name;
  final double? quantity;
  final String? unit;
  final double? unitPrice;
  final double? gstRate;

  const ChatLineItemDraft({
    this.name,
    this.quantity,
    this.unit,
    this.unitPrice,
    this.gstRate,
  });

  ChatLineItemDraft copyWith({
    String? name,
    double? quantity,
    String? unit,
    double? unitPrice,
    double? gstRate,
  }) {
    return ChatLineItemDraft(
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      gstRate: gstRate ?? this.gstRate,
    );
  }

  bool get isComplete =>
      name != null && quantity != null && unitPrice != null && gstRate != null;

  ChatLineItem toLineItem() => ChatLineItem(
        name: name!,
        quantity: quantity!,
        unit: unit ?? 'Nos',
        unitPrice: unitPrice!,
        gstRate: gstRate!,
      );
}

/// Full draft of the invoice being built
class ChatInvoiceDraft {
  final String? customerName;
  final String? customerPhone;
  final String? customerGstin;
  final String? customerEmail;
  final String? customerAddress;
  final List<ChatLineItem> items;
  final ChatLineItemDraft currentItem;
  final bool isInterState;

  const ChatInvoiceDraft({
    this.customerName,
    this.customerPhone,
    this.customerGstin,
    this.customerEmail,
    this.customerAddress,
    this.items = const [],
    this.currentItem = const ChatLineItemDraft(),
    this.isInterState = false,
  });

  ChatInvoiceDraft copyWith({
    String? customerName,
    String? customerPhone,
    String? customerGstin,
    String? customerEmail,
    String? customerAddress,
    List<ChatLineItem>? items,
    ChatLineItemDraft? currentItem,
    bool? isInterState,
  }) {
    return ChatInvoiceDraft(
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerGstin: customerGstin ?? this.customerGstin,
      customerEmail: customerEmail ?? this.customerEmail,
      customerAddress: customerAddress ?? this.customerAddress,
      items: items ?? this.items,
      currentItem: currentItem ?? this.currentItem,
      isInterState: isInterState ?? this.isInterState,
    );
  }

  double get subTotal => items.fold(0, (sum, item) => sum + item.taxableAmount);
  double get totalGst => items.fold(0, (sum, item) => sum + (item.taxableAmount * item.gstRate / 100));
  double get grandTotal => subTotal + totalGst;
}

