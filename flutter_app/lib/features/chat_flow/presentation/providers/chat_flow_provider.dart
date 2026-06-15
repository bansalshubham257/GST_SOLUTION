// lib/features/chat_flow/presentation/providers/chat_flow_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;

import '../../../../core/storage/local_storage.dart';
import '../../../customer/presentation/providers/customer_provider.dart';
import '../../../staff/presentation/providers/staff_provider.dart';
import '../../../purchase/presentation/providers/purchase_provider.dart';

// ─── Chat Flow Step Enum ─────────────────────────────────────────────────────

enum ChatFlowStep {
  mainMenu,
  // Staff
  staffName,
  staffPhone,
  staffRole,
  staffCommission,
  staffConfirm,
  // Customer
  customerName,
  customerPhone,
  customerGstin,
  customerState,
  customerAddress,
  customerConfirm,
  // Sale
  saleCustomerSelect,
  saleStaffSelect,
  saleItemName,
  saleItemQty,
  saleItemPrice,
  saleItemGst,
  saleMoreItems,
  salePaymentMode,
  saleConfirm,
  // Purchase
  purchaseSupplier,
  purchaseItemName,
  purchaseItemQty,
  purchaseItemPrice,
  purchaseItemGst,
  purchaseMoreItems,
  purchaseConfirm,
  done,
}

// ─── Flow Entity Type ────────────────────────────────────────────────────────

enum FlowEntity { staff, customer, sale, purchase }

// ─── Chat Flow State ─────────────────────────────────────────────────────────

class ChatFlowState {
  final List<types.Message> messages;
  final ChatFlowStep step;
  final bool isBotTyping;
  final Map<String, dynamic> draft;
  final List<String> quickReplyOptions;
  final FlowEntity? activeEntity;
  final bool isSuccess;

  ChatFlowState({
    this.messages = const [],
    this.step = ChatFlowStep.mainMenu,
    this.isBotTyping = false,
    this.draft = const {},
    this.quickReplyOptions = const [],
    this.activeEntity,
    this.isSuccess = false,
  });

  ChatFlowState copyWith({
    List<types.Message>? messages,
    ChatFlowStep? step,
    bool? isBotTyping,
    Map<String, dynamic>? draft,
    List<String>? quickReplyOptions,
    FlowEntity? activeEntity,
    bool? isSuccess,
  }) {
    return ChatFlowState(
      messages: messages ?? this.messages,
      step: step ?? this.step,
      isBotTyping: isBotTyping ?? this.isBotTyping,
      draft: draft ?? this.draft,
      quickReplyOptions: quickReplyOptions ?? this.quickReplyOptions,
      activeEntity: activeEntity ?? this.activeEntity,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

// ─── Chat Users ──────────────────────────────────────────────────────────────

final _user = types.User(id: 'chatflow-user', firstName: 'You');
final _bot = types.User(id: 'chatflow-bot', firstName: 'Assistant');
final _uuid = const Uuid();

types.TextMessage _botMsg(String text) => types.TextMessage(
      author: _bot,
      id: _uuid.v4(),
      text: text,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

types.TextMessage _userMsg(String text) => types.TextMessage(
      author: _user,
      id: _uuid.v4(),
      text: text,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

// ─── Provider ─────────────────────────────────────────────────────────────────

final chatFlowProvider =
    StateNotifierProvider.autoDispose<ChatFlowNotifier, ChatFlowState>(
  (ref) => ChatFlowNotifier(ref),
);

class ChatFlowNotifier extends StateNotifier<ChatFlowState> {
  final Ref _ref;
  ChatFlowNotifier(this._ref) : super(ChatFlowState()) {
    _sendMainMenu();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  void _addMessage(types.Message msg) {
    state = state.copyWith(messages: [msg, ...state.messages]);
  }

  void _addBotMessage(String text) {
    _addMessage(_botMsg(text));
  }

  Future<void> _botTyping(Future<void> Function() action) async {
    state = state.copyWith(isBotTyping: true);
    await Future.delayed(const Duration(milliseconds: 600));
    await action();
    state = state.copyWith(isBotTyping: false);
  }

  void _setQuickReplies(List<String> options) {
    state = state.copyWith(quickReplyOptions: options);
  }

  void _setStep(ChatFlowStep step, {List<String>? options}) {
    state = state.copyWith(
      step: step,
      quickReplyOptions: options ?? const [],
    );
  }

  // ─── Main Menu ─────────────────────────────────────────────────────────────

  void _sendMainMenu() {
    _addBotMessage(
      '👋 Welcome! I can help you manage everything.\n\n'
      'Choose an option below:',
    );
    _setStep(ChatFlowStep.mainMenu, options: [
      '👤 Add Staff',
      '👥 Add Customer',
      '🧾 Create Sale',
      '📦 Create Purchase',
      '❓ Help',
    ]);
  }

  // ─── Handle User Input ─────────────────────────────────────────────────────

  void handleInput(String text) {
    _addMessage(_userMsg(text));
    _processInput(text);
  }

  void _processInput(String text) {
    final step = state.step;

    if (step == ChatFlowStep.mainMenu) {
      _handleMenu(text);
    } else if (step == ChatFlowStep.staffName) {
      _handleStaffName(text);
    } else if (step == ChatFlowStep.staffPhone) {
      _handleStaffPhone(text);
    } else if (step == ChatFlowStep.staffRole) {
      _handleStaffRole(text);
    } else if (step == ChatFlowStep.staffCommission) {
      _handleStaffCommission(text);
    } else if (step == ChatFlowStep.staffConfirm) {
      _handleStaffConfirm(text);
    } else if (step == ChatFlowStep.customerName) {
      _handleCustomerName(text);
    } else if (step == ChatFlowStep.customerPhone) {
      _handleCustomerPhone(text);
    } else if (step == ChatFlowStep.customerGstin) {
      _handleCustomerGstin(text);
    } else if (step == ChatFlowStep.customerState) {
      _handleCustomerState(text);
    } else if (step == ChatFlowStep.customerAddress) {
      _handleCustomerAddress(text);
    } else if (step == ChatFlowStep.customerConfirm) {
      _handleCustomerConfirm(text);
    } else if (step == ChatFlowStep.saleCustomerSelect) {
      _handleSaleCustomerSelect(text);
    } else if (step == ChatFlowStep.saleStaffSelect) {
      _handleSaleStaffSelect(text);
    } else if (step == ChatFlowStep.saleItemName) {
      _handleSaleItemName(text);
    } else if (step == ChatFlowStep.saleItemQty) {
      _handleSaleItemQty(text);
    } else if (step == ChatFlowStep.saleItemPrice) {
      _handleSaleItemPrice(text);
    } else if (step == ChatFlowStep.saleItemGst) {
      _handleSaleItemGst(text);
    } else if (step == ChatFlowStep.saleMoreItems) {
      _handleSaleMoreItems(text);
    } else if (step == ChatFlowStep.salePaymentMode) {
      _handleSalePaymentMode(text);
    } else if (step == ChatFlowStep.saleConfirm) {
      _handleSaleConfirm(text);
    } else if (step == ChatFlowStep.purchaseSupplier) {
      _handlePurchaseSupplier(text);
    } else if (step == ChatFlowStep.purchaseItemName) {
      _handlePurchaseItemName(text);
    } else if (step == ChatFlowStep.purchaseItemQty) {
      _handlePurchaseItemQty(text);
    } else if (step == ChatFlowStep.purchaseItemPrice) {
      _handlePurchaseItemPrice(text);
    } else if (step == ChatFlowStep.purchaseItemGst) {
      _handlePurchaseItemGst(text);
    } else if (step == ChatFlowStep.purchaseMoreItems) {
      _handlePurchaseMoreItems(text);
    } else if (step == ChatFlowStep.purchaseConfirm) {
      _handlePurchaseConfirm(text);
    } else if (step == ChatFlowStep.done) {
      _sendMainMenu();
    }
  }

  // ─── Menu Handler ──────────────────────────────────────────────────────────

  void _handleMenu(String text) {
    if (text.contains('Staff') || text.contains('staff') || text.contains('👤')) {
      _startStaffFlow();
    } else if (text.contains('Customer') || text.contains('customer') || text.contains('👥')) {
      _startCustomerFlow();
    } else if (text.contains('Sale') || text.contains('sale') || text.contains('🧾')) {
      _startSaleFlow();
    } else if (text.contains('Purchase') || text.contains('purchase') || text.contains('📦')) {
      _startPurchaseFlow();
    } else if (text.contains('Help') || text.contains('help') || text.contains('❓')) {
      _addBotMessage(
        'I can help you with:\n\n'
        '• **Add Staff** — Add a new staff member with commission\n'
        '• **Add Customer** — Add a new customer with GST details\n'
        '• **Create Sale** — Create a sale with items & quantities\n'
        '• **Create Purchase** — Record a purchase from suppliers\n\n'
        'Just tap any option above to get started!',
      );
      _setStep(ChatFlowStep.mainMenu, options: [
        '👤 Add Staff',
        '👥 Add Customer',
        '🧾 Create Sale',
        '📦 Create Purchase',
      ]);
    } else {
      _addBotMessage('Please choose from the options above ☝️');
    }
  }

  // ─── Staff Flow ────────────────────────────────────────────────────────────

  void _startStaffFlow() {
    state = state.copyWith(draft: {}, activeEntity: FlowEntity.staff);
    _addBotMessage('Let\'s add a new staff member! ✨\n\nWhat is the staff name?');
    _setStep(ChatFlowStep.staffName);
  }

  void _handleStaffName(String text) {
    state = state.copyWith(draft: {...state.draft, 'name': text});
    _addBotMessage('Great! What is **${text}**\'s phone number?');
    _setStep(ChatFlowStep.staffPhone);
  }

  void _handleStaffPhone(String text) {
    state = state.copyWith(draft: {...state.draft, 'phone': text});
    _addBotMessage('What is their role? (e.g., Salesperson, Technician, Accountant)');
    _setStep(ChatFlowStep.staffRole);
  }

  void _handleStaffRole(String text) {
    state = state.copyWith(draft: {...state.draft, 'role': text});
    _addBotMessage('What commission percentage do they get? (e.g., 5)');
    _setStep(ChatFlowStep.staffCommission);
  }

  void _handleStaffCommission(String text) {
    final commission = double.tryParse(text) ?? 0;
    state = state.copyWith(draft: {...state.draft, 'commission': commission});
    final d = state.draft;
    _addBotMessage(
      '📋 **Confirm Staff Details:**\n\n'
      'Name: **${d['name']}**\n'
      'Phone: **${d['phone']}**\n'
      'Role: **${d['role']}**\n'
      'Commission: **${commission.toStringAsFixed(0)}%**\n\n'
      'Save this staff member?',
    );
    _setStep(ChatFlowStep.staffConfirm, options: ['✅ Save', '❌ Cancel']);
  }

  void _handleStaffConfirm(String text) {
    if (text.contains('Save') || text.contains('✅')) {
      _botTyping(() async {
        final d = state.draft;
        await _ref.read(staffFormProvider.notifier).saveStaff(
              name: d['name'] ?? '',
              phone: d['phone'] as String?,
              role: d['role'] as String?,
              commissionPercentage: (d['commission'] as num?)?.toDouble(),
            );
        _addBotMessage('✅ Staff **${d['name']}** has been added successfully!');
        _goBackToMenu();
      });
    } else {
      _addBotMessage('Cancelled. Returning to menu...');
      _goBackToMenu();
    }
  }

  // ─── Customer Flow ────────────────────────────────────────────────────────

  void _startCustomerFlow() {
    state = state.copyWith(draft: {}, activeEntity: FlowEntity.customer);
    _addBotMessage('Let\'s add a new customer! ✨\n\nWhat is the customer name?');
    _setStep(ChatFlowStep.customerName);
  }

  void _handleCustomerName(String text) {
    state = state.copyWith(draft: {...state.draft, 'name': text});
    _addBotMessage('What is **${text}**\'s phone number?');
    _setStep(ChatFlowStep.customerPhone);
  }

  void _handleCustomerPhone(String text) {
    state = state.copyWith(draft: {...state.draft, 'phone': text});
    _addBotMessage('What is their GSTIN? (optional)');
    _setStep(ChatFlowStep.customerGstin, options: ['⏭️ Skip GSTIN']);
  }

  void _handleCustomerGstin(String text) {
    if (text.toLowerCase().contains('skip')) {
      state = state.copyWith(draft: {...state.draft, 'gstin': ''});
    } else {
      state = state.copyWith(draft: {...state.draft, 'gstin': text});
    }
    _addBotMessage('Which state are they in? (e.g., Maharashtra, Gujarat)');
    _setStep(ChatFlowStep.customerState);
  }

  void _handleCustomerState(String text) {
    state = state.copyWith(draft: {...state.draft, 'state': text});
    _addBotMessage('What is their address? (optional)');
    _setStep(ChatFlowStep.customerAddress, options: ['⏭️ Skip Address']);
  }

  void _handleCustomerAddress(String text) {
    if (!text.toLowerCase().contains('skip')) {
      state = state.copyWith(draft: {...state.draft, 'address': text});
    }
    final d = state.draft;
    _addBotMessage(
      '📋 **Confirm Customer Details:**\n\n'
      'Name: **${d['name']}**\n'
      'Phone: **${d['phone']}**\n'
      'GSTIN: **${d['gstin']?.toString().isNotEmpty == true ? d['gstin'] : '—'}**\n'
      'State: **${d['state']}**\n'
      'Address: **${d['address']?.toString().isNotEmpty == true ? d['address'] : '—'}**\n\n'
      'Save this customer?',
    );
    _setStep(ChatFlowStep.customerConfirm, options: ['✅ Save', '❌ Cancel']);
  }

  void _handleCustomerConfirm(String text) {
    if (text.contains('Save') || text.contains('✅')) {
      _botTyping(() async {
        final d = state.draft;
        await _ref.read(addCustomerProvider.notifier).addCustomer({
          'name': d['name'] ?? '',
          'phone': d['phone']?.toString() ?? '',
          'gstin': d['gstin']?.toString().isNotEmpty == true ? d['gstin']?.toString() : null,
          'stateName': d['state'],
          'address': d['address']?.toString().isNotEmpty == true ? d['address']?.toString() : null,
        });
        _addBotMessage('✅ Customer **${d['name']}** has been added successfully!');
        _goBackToMenu();
      });
    } else {
      _addBotMessage('Cancelled. Returning to menu...');
      _goBackToMenu();
    }
  }

  // ─── Sale Flow ─────────────────────────────────────────────────────────────

  void _startSaleFlow() {
    state = state.copyWith(
      draft: {'items': <Map<String, dynamic>>[], 'paymentMode': 'cash'},
      activeEntity: FlowEntity.sale,
    );
    _askSaleCustomer();
  }

  void _askSaleCustomer() {
    final customers = LocalStorage.customerBox.values.toList();
    final options = customers.map((c) => '👥 ${c['name']}').toList();
    options.add('⏭️ Walk-in Customer');
    _addBotMessage('Let\'s create a sale! 🧾\n\nSelect a customer (optional):');
    _setStep(ChatFlowStep.saleCustomerSelect, options: options);
  }

  void _handleSaleCustomerSelect(String text) {
    if (text.contains('Skip') || text.contains('⏭️')) {
      _addBotMessage('Walk-in Customer selected.');
    } else {
      final name = text.replaceFirst('👥 ', '').trim();
      final customers = LocalStorage.customerBox.values.toList();
      final matched = customers.where((c) => c['name'].toString().toLowerCase() == name.toLowerCase()).firstOrNull;
      if (matched != null) {
        state = state.copyWith(
          draft: {
            ...state.draft,
            'customerId': matched['id'],
            'customerName': matched['name'],
            'customerGstin': matched['gstin'],
          },
        );
        _addBotMessage('Customer **${matched['name']}** selected!');
      } else {
        _addBotMessage('Customer not found. Using Walk-in.');
      }
    }
    _askSaleStaff();
  }

  void _askSaleStaff() {
    final staffList = LocalStorage.staffBox.values.toList();
    if (staffList.isEmpty) {
      _addBotMessage('No staff members found. Proceeding without staff.');
      _askSaleItemName();
    } else {
      final options = staffList.map((s) => '👤 ${s['name']}').toList();
      options.add('⏭️ Skip Staff');
      _addBotMessage('Select a staff member (optional):');
      _setStep(ChatFlowStep.saleStaffSelect, options: options);
    }
  }

  void _handleSaleStaffSelect(String text) {
    if (text.contains('Skip') || text.contains('⏭️')) {
      _addBotMessage('Staff skipped.');
    } else {
      final name = text.replaceFirst('👤 ', '').trim();
      final staffList = LocalStorage.staffBox.values.toList();
      final matched = staffList.where((s) => s['name'].toString().toLowerCase() == name.toLowerCase()).firstOrNull;
      if (matched != null) {
        state = state.copyWith(
          draft: {...state.draft, 'staffId': matched['id'], 'staffName': matched['name']},
        );
        _addBotMessage('Staff **${matched['name']}** selected!');
      } else {
        _addBotMessage('Staff skipped.');
      }
    }
    _askSaleItemName();
  }

  void _askSaleItemName() {
    final items = LocalStorage.itemCatalogBox.values.toList();
    if (items.isEmpty) {
      _addBotMessage('What is the item name?');
      _setStep(ChatFlowStep.saleItemName);
    } else {
      final options = items.map((item) => '📦 ${item['name']}').toList();
      options.add('➕ Other (type name)');
      _addBotMessage('Select an item or add a new one:');
      _setStep(ChatFlowStep.saleItemName, options: options);
    }
  }

  void _handleSaleItemName(String text) {
    if (text.startsWith('➕')) {
      _addBotMessage('Type the item name:');
      _setStep(ChatFlowStep.saleItemName);
    } else if (text.startsWith('📦')) {
      final name = text.substring(2).trim();
      final items = LocalStorage.itemCatalogBox.values.toList();
      final matched = items.where((item) => item['name'].toString() == name).firstOrNull;
      if (matched != null) {
        final price = (matched['unitPrice'] ?? 0).toDouble();
        final gstRate = (matched['gstRate'] ?? 0).toDouble();
        state = state.copyWith(
          draft: {
            ...state.draft,
            '_currentItem': {'name': matched['name'], 'price': price, 'gstRate': gstRate, '_fromCatalog': true},
          },
        );
        _addBotMessage('**${matched['name']}** selected (₹$price, GST: ${gstRate.toStringAsFixed(0)}%).\nQuantity? (e.g., 1, 2.5)');
        _setStep(ChatFlowStep.saleItemQty);
      } else {
        _addBotMessage('Item not found. Type the name:');
        _setStep(ChatFlowStep.saleItemName);
      }
    } else {
      state = state.copyWith(
        draft: {...state.draft, '_currentItem': {'name': text}},
      );
      _addBotMessage('Quantity for **$text**? (e.g., 1, 2.5)');
      _setStep(ChatFlowStep.saleItemQty);
    }
  }

  void _handleSaleItemQty(String text) {
    final qty = double.tryParse(text) ?? 1;
    final currentItem = Map<String, dynamic>.from(state.draft['_currentItem'] as Map? ?? {});
    currentItem['qty'] = qty;
    if (currentItem['_fromCatalog'] == true) {
      final items = List<Map<String, dynamic>>.from(state.draft['items'] as List? ?? []);
      items.add({
        'name': currentItem['name'],
        'qty': qty,
        'price': currentItem['price'],
        'gstRate': currentItem['gstRate'],
      });
      state = state.copyWith(draft: {...state.draft, 'items': items, '_currentItem': null});
      _addBotMessage('✅ **${currentItem['name']}** added ($qty × ₹${currentItem['price']}, GST: ${currentItem['gstRate'].toStringAsFixed(0)}%)\n\nAdd more items?');
      _setStep(ChatFlowStep.saleMoreItems, options: ['✅ Add More', '📋 Done — Review']);
    } else {
      state = state.copyWith(draft: {...state.draft, '_currentItem': currentItem});
      _addBotMessage('Unit price? (e.g., 500)');
      _setStep(ChatFlowStep.saleItemPrice);
    }
  }

  void _handleSaleItemPrice(String text) {
    final price = double.tryParse(text) ?? 0;
    state = state.copyWith(
      draft: {...state.draft, '_currentItem': {...(state.draft['_currentItem'] as Map<String, dynamic>? ?? {}), 'price': price}},
    );
    _addBotMessage('GST rate? (0, 5, 12, 18, 28)');
    _setStep(ChatFlowStep.saleItemGst, options: ['0%', '5%', '12%', '18%', '28%']);
  }

  void _handleSaleItemGst(String text) {
    final gstStr = text.replaceAll('%', '');
    final gst = double.tryParse(gstStr) ?? 0;
    final currentItem = (state.draft['_currentItem'] as Map<String, dynamic>? ?? {});
    final items = List<Map<String, dynamic>>.from(state.draft['items'] as List? ?? []);
    items.add({
      'name': currentItem['name'],
      'qty': currentItem['qty'],
      'price': currentItem['price'],
      'gstRate': gst,
    });
    state = state.copyWith(
      draft: {...state.draft, 'items': items, '_currentItem': null},
    );
    _addBotMessage(
      '✅ **${currentItem['name']}** added (${currentItem['qty']} × ₹${currentItem['price']}, GST: ${gst.toStringAsFixed(0)}%)\n\n'
      'Add more items?',
    );
    _setStep(ChatFlowStep.saleMoreItems, options: ['✅ Add More', '📋 Done — Review']);
  }

  void _handleSaleMoreItems(String text) {
    if (text.contains('Add') || text.contains('✅')) {
      _askSaleItemName();
    } else {
      _showSaleSummary();
    }
  }

  void _showSaleSummary() {
    final items = (state.draft['items'] as List<Map<String, dynamic>>? ?? []);
    final subTotal = items.fold(0.0, (s, i) => s + ((i['qty'] as num) * (i['price'] as num)));
    final totalGst = items.fold(0.0, (s, i) => s + ((i['qty'] as num) * (i['price'] as num) * (i['gstRate'] as num) / 100));
    final grandTotal = subTotal + totalGst;

    _addBotMessage(
      '📋 **Sale Summary**\n\n'
      '${items.asMap().entries.map((e) => '${e.key + 1}. **${e.value['name']}** — ${e.value['qty']} × ₹${e.value['price']}').join('\n')}'
      '\n\nSubtotal: **₹${subTotal.toStringAsFixed(2)}**'
      '\nGST: **₹${totalGst.toStringAsFixed(2)}**'
      '\n**Grand Total: ₹${grandTotal.toStringAsFixed(2)}**'
      '\n\nSelect payment mode:',
    );
    _setStep(ChatFlowStep.salePaymentMode, options: ['💵 Cash', '💳 Card', '📱 UPI', '🏦 Bank']);
  }

  void _handleSalePaymentMode(String text) {
    String mode;
    if (text.contains('Cash') || text.contains('💵')) mode = 'cash';
    else if (text.contains('Card') || text.contains('💳')) mode = 'card';
    else if (text.contains('UPI') || text.contains('📱')) mode = 'upi';
    else mode = 'bank';

    state = state.copyWith(draft: {...state.draft, 'paymentMode': mode});
    _addBotMessage('Payment mode: **${mode.toUpperCase()}**\n\nSave this sale?');
    _setStep(ChatFlowStep.saleConfirm, options: ['✅ Save Sale', '❌ Cancel']);
  }

  void _handleSaleConfirm(String text) {
    if (text.contains('Save') || text.contains('✅')) {
      _botTyping(() async {
        final d = state.draft;
        final items = (d['items'] as List<Map<String, dynamic>>? ?? []);
        final id = const Uuid().v4();
        final now = DateTime.now();
        final invoiceNum = 'INV-${now.year}-${now.month.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch.toString().substring(6)}';

        final lineItems = items.map((i) => {
          'id': const Uuid().v4(),
          'description': i['name'],
          'quantity': (i['qty'] as num).toDouble(),
          'unitPrice': (i['price'] as num).toDouble(),
          'gstRate': (i['gstRate'] as num).toDouble(),
          'taxableAmount': (i['qty'] as num) * (i['price'] as num),
        }).toList();

        final subTotal = lineItems.fold(0.0, (s, i) => s + (i['taxableAmount'] as double));
        final totalTax = lineItems.fold(0.0, (s, i) => s + (i['taxableAmount'] as double) * (i['gstRate'] as double) / 100);

        final invoice = {
          'id': id,
          'invoiceNumber': invoiceNum,
          'customerName': d['customerName'] ?? 'Walk-in Customer',
          if (d['customerId'] != null) 'customerId': d['customerId'],
          if (d['customerGstin'] != null) 'customerGstin': d['customerGstin'],
          'invoiceDate': now.toIso8601String(),
          'createdAt': now.toIso8601String(),
          'lineItems': lineItems,
          'subTotal': subTotal,
          'totalTax': totalTax,
          'grandTotal': subTotal + totalTax,
          'paymentMode': d['paymentMode'] ?? 'cash',
          'status': 'completed',
          if (d['staffId'] != null) 'staffId': d['staffId'],
          if (d['staffName'] != null) 'staffName': d['staffName'],
        };

        await LocalStorage.cacheInvoice(id, invoice);
        _addBotMessage(
          '✅ **Sale created successfully!** 🎉\n\n'
          'Invoice: **$invoiceNum**\n'
          'Total: **₹${(subTotal + totalTax).toStringAsFixed(2)}**\n'
          'Payment: **${d['paymentMode']}**',
        );
        _goBackToMenu();
      });
    } else {
      _addBotMessage('Cancelled. Returning to menu...');
      _goBackToMenu();
    }
  }

  // ─── Purchase Flow ─────────────────────────────────────────────────────────

  void _startPurchaseFlow() {
    state = state.copyWith(
      draft: {'items': <Map<String, dynamic>>[]},
      activeEntity: FlowEntity.purchase,
    );
    _addBotMessage('Let\'s record a purchase! 📦\n\nWhat is the supplier name?');
    _setStep(ChatFlowStep.purchaseSupplier);
  }

  void _handlePurchaseSupplier(String text) {
    state = state.copyWith(draft: {...state.draft, 'supplier': text});
    _askPurchaseItemName();
  }

  void _askPurchaseItemName() {
    final items = LocalStorage.itemCatalogBox.values.toList();
    if (items.isEmpty) {
      _addBotMessage('What is the item name?');
      _setStep(ChatFlowStep.purchaseItemName);
    } else {
      final options = items.map((item) => '📦 ${item['name']}').toList();
      options.add('➕ Other (type name)');
      _addBotMessage('Select an item or add a new one:');
      _setStep(ChatFlowStep.purchaseItemName, options: options);
    }
  }

  void _handlePurchaseItemName(String text) {
    if (text.startsWith('➕')) {
      _addBotMessage('Type the item name:');
      _setStep(ChatFlowStep.purchaseItemName);
    } else if (text.startsWith('📦')) {
      final name = text.substring(2).trim();
      final items = LocalStorage.itemCatalogBox.values.toList();
      final matched = items.where((item) => item['name'].toString() == name).firstOrNull;
      if (matched != null) {
        final price = (matched['unitPrice'] ?? 0).toDouble();
        final gstRate = (matched['gstRate'] ?? 0).toDouble();
        state = state.copyWith(
          draft: {
            ...state.draft,
            '_currentItem': {'name': matched['name'], 'price': price, 'gstRate': gstRate, '_fromCatalog': true},
          },
        );
        _addBotMessage('**${matched['name']}** selected (₹$price, GST: ${gstRate.toStringAsFixed(0)}%).\nQuantity? (e.g., 10, 25)');
        _setStep(ChatFlowStep.purchaseItemQty);
      } else {
        _addBotMessage('Item not found. Type the name:');
        _setStep(ChatFlowStep.purchaseItemName);
      }
    } else {
      state = state.copyWith(
        draft: {...state.draft, '_currentItem': {'name': text}},
      );
      _addBotMessage('Quantity for **$text**? (e.g., 10, 25)');
      _setStep(ChatFlowStep.purchaseItemQty);
    }
  }

  void _handlePurchaseItemQty(String text) {
    final qty = double.tryParse(text) ?? 1;
    final currentItem = Map<String, dynamic>.from(state.draft['_currentItem'] as Map? ?? {});
    currentItem['qty'] = qty;
    if (currentItem['_fromCatalog'] == true) {
      final items = List<Map<String, dynamic>>.from(state.draft['items'] as List? ?? []);
      items.add({
        'name': currentItem['name'],
        'qty': qty,
        'price': currentItem['price'],
        'gstRate': currentItem['gstRate'],
      });
      state = state.copyWith(draft: {...state.draft, 'items': items, '_currentItem': null});
      _addBotMessage('✅ **${currentItem['name']}** added ($qty × ₹${currentItem['price']}, GST: ${currentItem['gstRate'].toStringAsFixed(0)}%)\n\nAdd more items?');
      _setStep(ChatFlowStep.purchaseMoreItems, options: ['✅ Add More', '📋 Done — Review']);
    } else {
      state = state.copyWith(draft: {...state.draft, '_currentItem': currentItem});
      _addBotMessage('Unit price? (e.g., 100)');
      _setStep(ChatFlowStep.purchaseItemPrice);
    }
  }

  void _handlePurchaseItemPrice(String text) {
    final price = double.tryParse(text) ?? 0;
    state = state.copyWith(
      draft: {...state.draft, '_currentItem': {...(state.draft['_currentItem'] as Map<String, dynamic>? ?? {}), 'price': price}},
    );
    _addBotMessage('GST rate? (0, 5, 12, 18, 28)');
    _setStep(ChatFlowStep.purchaseItemGst, options: ['0%', '5%', '12%', '18%', '28%']);
  }

  void _handlePurchaseItemGst(String text) {
    final gstStr = text.replaceAll('%', '');
    final gst = double.tryParse(gstStr) ?? 0;
    final currentItem = (state.draft['_currentItem'] as Map<String, dynamic>? ?? {});
    final items = List<Map<String, dynamic>>.from(state.draft['items'] as List? ?? []);
    items.add({
      'name': currentItem['name'],
      'qty': currentItem['qty'],
      'price': currentItem['price'],
      'gstRate': gst,
    });
    state = state.copyWith(
      draft: {...state.draft, 'items': items, '_currentItem': null},
    );
    _addBotMessage(
      '✅ **${currentItem['name']}** added (${currentItem['qty']} × ₹${currentItem['price']}, GST: ${gst.toStringAsFixed(0)}%)\n\n'
      'Add more items?',
    );
    _setStep(ChatFlowStep.purchaseMoreItems, options: ['✅ Add More', '📋 Done — Review']);
  }

  void _handlePurchaseMoreItems(String text) {
    if (text.contains('Add') || text.contains('✅')) {
      _askPurchaseItemName();
    } else {
      _showPurchaseSummary();
    }
  }

  void _showPurchaseSummary() {
    final items = (state.draft['items'] as List<Map<String, dynamic>>? ?? []);
    final subTotal = items.fold(0.0, (s, i) => s + ((i['qty'] as num) * (i['price'] as num)));
    final totalGst = items.fold(0.0, (s, i) => s + ((i['qty'] as num) * (i['price'] as num) * (i['gstRate'] as num) / 100));
    final grandTotal = subTotal + totalGst;

    _addBotMessage(
      '📋 **Purchase Summary**\n\n'
      'Supplier: **${state.draft['supplier']}**\n'
      '${items.asMap().entries.map((e) => '${e.key + 1}. **${e.value['name']}** — ${e.value['qty']} × ₹${e.value['price']}').join('\n')}'
      '\n\nSubtotal: **₹${subTotal.toStringAsFixed(2)}**'
      '\nGST: **₹${totalGst.toStringAsFixed(2)}**'
      '\n**Grand Total: ₹${grandTotal.toStringAsFixed(2)}**'
      '\n\nSave this purchase?',
    );
    _setStep(ChatFlowStep.purchaseConfirm, options: ['✅ Save Purchase', '❌ Cancel']);
  }

  void _handlePurchaseConfirm(String text) {
    if (text.contains('Save') || text.contains('✅')) {
      _botTyping(() async {
        final d = state.draft;
        await _ref.read(createPurchaseProvider.notifier).createPurchase({
          'supplierName': d['supplier'],
          'lineItems': d['items'],
          'invoiceDate': DateTime.now().toIso8601String(),
          'status': 'completed',
        });
        _addBotMessage('✅ Purchase from **${d['supplier']}** has been recorded successfully!');
        _goBackToMenu();
      });
    } else {
      _addBotMessage('Cancelled. Returning to menu...');
      _goBackToMenu();
    }
  }

  // ─── Item Management ──────────────────────────────────────────────────────

  void removeItem(int index) {
    final items = List<Map<String, dynamic>>.from(state.draft['items'] as List? ?? []);
    if (index < 0 || index >= items.length) return;
    final removed = items.removeAt(index);
    state = state.copyWith(draft: {...state.draft, 'items': items});
    _addBotMessage('Removed **${removed['name']}** from the list.');
  }

  void updateItem(int index, {double? qty, double? price, double? gstRate}) {
    final items = List<Map<String, dynamic>>.from(state.draft['items'] as List? ?? []);
    if (index < 0 || index >= items.length) return;
    final item = Map<String, dynamic>.from(items[index]);
    if (qty != null) item['qty'] = qty;
    if (price != null) item['price'] = price;
    if (gstRate != null) item['gstRate'] = gstRate;
    items[index] = item;
    state = state.copyWith(draft: {...state.draft, 'items': items});
    _addBotMessage('Updated **${item['name']}**: qty ${item['qty']}, ₹${item['price']}, GST ${item['gstRate']}%');
  }

  // ─── Back to Menu ──────────────────────────────────────────────────────────

  void _goBackToMenu() {
    state = state.copyWith(
      step: ChatFlowStep.done,
      draft: {},
      activeEntity: null,
    );
    _setStep(ChatFlowStep.mainMenu, options: [
      '👤 Add Staff',
      '👥 Add Customer',
      '🧾 Create Sale',
      '📦 Create Purchase',
    ]);
  }

  void reset() {
    state = ChatFlowState();
    _sendMainMenu();
  }
}
