// lib/features/chat_flow/presentation/providers/chat_flow_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;

import '../../../../core/storage/local_storage.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../customer/presentation/providers/customer_provider.dart';
import '../../../staff/presentation/providers/staff_provider.dart';
import '../../../purchase/presentation/providers/purchase_provider.dart';
import '../../../settings/presentation/providers/feature_settings_provider.dart';
import '../../../invoice/presentation/providers/item_catalog_provider.dart';
import 'sale_settings_provider.dart';

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
  saleDiscount,
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

  AppLanguage get _lang => _ref.read(appLanguageProvider);

  SaleSettings get _saleSettings => _ref.read(saleSettingsProvider);

  FeatureSettings get _featureSettings => _ref.read(featureSettingsProvider);

  String _t(String en, String hi) => _lang == AppLanguage.hindi ? hi : en;

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
    _addBotMessage(AppStrings.welcome(_lang));
    _setStep(ChatFlowStep.mainMenu, options: [
      AppStrings.menuAddStaff(_lang),
      AppStrings.menuAddCustomer(_lang),
      AppStrings.menuCreateSale(_lang),
      AppStrings.menuCreatePurchase(_lang),
      AppStrings.menuHelp(_lang),
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
    } else if (step == ChatFlowStep.saleDiscount) {
      _handleSaleDiscount(text);
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
      _addBotMessage(AppStrings.helpText(_lang));
      _setStep(ChatFlowStep.mainMenu, options: [
        AppStrings.menuAddStaff(_lang),
        AppStrings.menuAddCustomer(_lang),
        AppStrings.menuCreateSale(_lang),
        AppStrings.menuCreatePurchase(_lang),
      ]);
    } else {
      _addBotMessage(AppStrings.chooseOption(_lang));
    }
  }

  // ─── Staff Flow ────────────────────────────────────────────────────────────

  void _startStaffFlow() {
    state = state.copyWith(draft: {}, activeEntity: FlowEntity.staff);
    _addBotMessage(AppStrings.staffWelcome(_lang));
    _setStep(ChatFlowStep.staffName);
  }

  void _handleStaffName(String text) {
    state = state.copyWith(draft: {...state.draft, 'name': text});
    _addBotMessage(AppStrings.staffPhone(text, _lang));
    _setStep(ChatFlowStep.staffPhone);
  }

  void _handleStaffPhone(String text) {
    state = state.copyWith(draft: {...state.draft, 'phone': text});
    _addBotMessage(AppStrings.staffRole(_lang));
    _setStep(ChatFlowStep.staffRole);
  }

  void _handleStaffRole(String text) {
    state = state.copyWith(draft: {...state.draft, 'role': text});
    _addBotMessage(AppStrings.staffCommission(_lang));
    _setStep(ChatFlowStep.staffCommission);
  }

  void _handleStaffCommission(String text) {
    final commission = double.tryParse(text) ?? 0;
    state = state.copyWith(draft: {...state.draft, 'commission': commission});
    final d = state.draft;
    _addBotMessage(AppStrings.staffConfirm(d['name'], d['phone'], d['role'], commission.toStringAsFixed(0), _lang));
    _setStep(ChatFlowStep.staffConfirm, options: [AppStrings.save(_lang), AppStrings.cancel(_lang)]);
  }

  void _handleStaffConfirm(String text) {
    if (text.contains('Save') || text.contains('✅') || text.contains('सहेजें')) {
      _botTyping(() async {
        final d = state.draft;
        await _ref.read(staffFormProvider.notifier).saveStaff(
              name: d['name'] ?? '',
              phone: d['phone'] as String?,
              role: d['role'] as String?,
              commissionPercentage: (d['commission'] as num?)?.toDouble(),
            );
        _addBotMessage(AppStrings.staffSaved(d['name'], _lang));
        _goBackToMenu();
      });
    } else {
      _addBotMessage(AppStrings.cancelled(_lang));
      _goBackToMenu();
    }
  }

  // ─── Customer Flow ────────────────────────────────────────────────────────

  void _startCustomerFlow() {
    state = state.copyWith(draft: {}, activeEntity: FlowEntity.customer);
    _addBotMessage(AppStrings.customerWelcome(_lang));
    _setStep(ChatFlowStep.customerName);
  }

  void _handleCustomerName(String text) {
    state = state.copyWith(draft: {...state.draft, 'name': text});
    _addBotMessage(AppStrings.customerPhone(text, _lang));
    _setStep(ChatFlowStep.customerPhone);
  }

  void _handleCustomerPhone(String text) {
    state = state.copyWith(draft: {...state.draft, 'phone': text});
    _addBotMessage(AppStrings.customerGstin(_lang));
    _setStep(ChatFlowStep.customerGstin, options: [AppStrings.skipGstin(_lang)]);
  }

  void _handleCustomerGstin(String text) {
    if (text.toLowerCase().contains('skip')) {
      state = state.copyWith(draft: {...state.draft, 'gstin': ''});
    } else {
      state = state.copyWith(draft: {...state.draft, 'gstin': text});
    }
    _addBotMessage(AppStrings.customerState(_lang));
    _setStep(ChatFlowStep.customerState);
  }

  void _handleCustomerState(String text) {
    state = state.copyWith(draft: {...state.draft, 'state': text});
    _addBotMessage(AppStrings.customerAddress(_lang));
    _setStep(ChatFlowStep.customerAddress, options: [AppStrings.skipAddress(_lang)]);
  }

  void _handleCustomerAddress(String text) {
    if (!text.toLowerCase().contains('skip')) {
      state = state.copyWith(draft: {...state.draft, 'address': text});
    }
    final d = state.draft;
    _addBotMessage(AppStrings.customerConfirm(
      d['name'] ?? '',
      d['phone']?.toString() ?? '',
      d['gstin']?.toString().isNotEmpty == true ? d['gstin'].toString() : AppStrings.dash(_lang),
      d['state'] ?? '',
      d['address']?.toString().isNotEmpty == true ? d['address'].toString() : AppStrings.dash(_lang),
      _lang,
    ));
    _setStep(ChatFlowStep.customerConfirm, options: [AppStrings.save(_lang), AppStrings.cancel(_lang)]);
  }

  void _handleCustomerConfirm(String text) {
    if (text.contains('Save') || text.contains('✅') || text.contains('सहेजें')) {
      _botTyping(() async {
        final d = state.draft;
        await _ref.read(addCustomerProvider.notifier).addCustomer({
          'name': d['name'] ?? '',
          'phone': d['phone']?.toString() ?? '',
          'gstin': d['gstin']?.toString().isNotEmpty == true ? d['gstin']?.toString() : null,
          'stateName': d['state'],
          'address': d['address']?.toString().isNotEmpty == true ? d['address']?.toString() : null,
        });
        _addBotMessage(AppStrings.customerSaved(d['name'], _lang));
        _goBackToMenu();
      });
    } else {
      _addBotMessage(AppStrings.cancelled(_lang));
      _goBackToMenu();
    }
  }

  /// Called by UI when barcode scanner returns a value.
  void handleBarcodeResult(String barcode) {
    final items = LocalStorage.itemCatalogBox.values.toList();
    final matched = items.where((item) => item['barcode']?.toString() == barcode).firstOrNull;

    if (matched != null) {
      final price = (matched['unitPrice'] ?? 0).toDouble();
      final gstRate = (matched['gstRate'] ?? 0).toDouble();
      state = state.copyWith(
        draft: {
          ...state.draft,
          '_currentItem': {'name': matched['name'], 'price': price, 'gstRate': gstRate, '_fromCatalog': true},
          '_awaitingBarcode': false,
        },
      );
      _addBotMessage(_t('📷 Scanned: ${matched['name']} (₹$price, GST: $gstRate%)', '📷 स्कैन किया: ${matched['name']} (₹$price, GST: $gstRate%)'));
      _setStep(ChatFlowStep.saleItemQty);
    } else {
      _addBotMessage(_t('📷 Barcode not found in catalog. Type the item name:', '📷 बारकोड कैटलॉग में नहीं मिला। आइटम नाम टाइप करें:'));
      _setStep(ChatFlowStep.saleItemName);
      state = state.copyWith(draft: {...state.draft, '_awaitingBarcode': false});
    }
  }

  // ─── Sale Flow ─────────────────────────────────────────────────────────────

  void _startSaleFlow() {
    final s = _saleSettings;
    state = state.copyWith(
      draft: {'items': <Map<String, dynamic>>[], 'paymentMode': 'cash'},
      activeEntity: FlowEntity.sale,
    );
    if (s.askCustomer && _featureSettings.showCustomers) {
      _askSaleCustomer();
    } else {
      _askSaleStaff();
    }
  }

  void _askSaleCustomer() {
    final customers = LocalStorage.customerBox.values.toList();
    final options = customers.map((c) => '👥 ${c['name']}').toList();
    options.add(AppStrings.walkinCustomer(_lang));
    _addBotMessage(AppStrings.saleCustomerSelect(_lang));
    _setStep(ChatFlowStep.saleCustomerSelect, options: options);
  }

  void _handleSaleCustomerSelect(String text) {
    if (text.contains('Skip') || text.contains('⏭️') || text.contains('वॉक-इन')) {
      _addBotMessage(_t('Walk-in Customer selected.', 'वॉक-इन ग्राहक चुना गया।'));
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
        _addBotMessage(AppStrings.customerSelected(matched['name'], _lang));
      } else {
        _addBotMessage(AppStrings.notFoundUsingWalkin(_lang));
      }
    }
    _askSaleStaff();
  }

  void _askSaleStaff() {
    final s = _saleSettings;
    if (!s.askStaff || !_featureSettings.showStaff) {
      _askSaleItemName();
      return;
    }
    final staffList = LocalStorage.staffBox.values.toList();
    if (staffList.isEmpty) {
      _addBotMessage(AppStrings.noStaff(_lang));
      _askSaleItemName();
    } else {
      final options = staffList.map((s) => '👤 ${s['name']}').toList();
      options.add(AppStrings.skipStaff(_lang));
      _addBotMessage(AppStrings.staffSelect(_lang));
      _setStep(ChatFlowStep.saleStaffSelect, options: options);
    }
  }

  void _handleSaleStaffSelect(String text) {
    if (text.contains('Skip') || text.contains('⏭️') || text.contains('स्टाफ़')) {
      _addBotMessage(AppStrings.staffSkipped(_lang));
    } else {
      final name = text.replaceFirst('👤 ', '').trim();
      final staffList = LocalStorage.staffBox.values.toList();
      final matched = staffList.where((s) => s['name'].toString().toLowerCase() == name.toLowerCase()).firstOrNull;
      if (matched != null) {
        state = state.copyWith(
          draft: {...state.draft, 'staffId': matched['id'], 'staffName': matched['name']},
        );
        _addBotMessage(AppStrings.staffSelected(matched['name'], _lang));
      } else {
        _addBotMessage(AppStrings.staffSkipped(_lang));
      }
    }
    _askSaleItemName();
  }

  void _askSaleItemName() {
    final s = _saleSettings;
    final items = s.enableCatalog ? LocalStorage.itemCatalogBox.values.toList() : [];
    if (items.isEmpty && !s.enableBarcode) {
      _addBotMessage(AppStrings.typeItemName(_lang));
      _setStep(ChatFlowStep.saleItemName);
    } else {
      final options = items.map((item) => '📦 ${item['name']}').toList();
      if (s.enableBarcode) {
        options.add('📷 Scan Barcode');
      }
      options.add(AppStrings.otherItem(_lang));
      _addBotMessage(AppStrings.itemSelect(_lang));
      _setStep(ChatFlowStep.saleItemName, options: options);
    }
  }

  void _handleSaleItemName(String text) {
    if (text.startsWith('➕')) {
      _addBotMessage(AppStrings.typeItemName(_lang));
      _setStep(ChatFlowStep.saleItemName);
    } else if (text == '📷 Scan Barcode') {
      // Signal the UI to open scanner — the scanner result will call back with barcode value
      _addBotMessage(_t('📷 Open the barcode scanner below.', '📷 नीचे बारकोड स्कैनर खोलें।'));
      _setStep(ChatFlowStep.saleItemName);
      state = state.copyWith(draft: {...state.draft, '_awaitingBarcode': true});
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
        _addBotMessage(AppStrings.itemSelected(matched['name'], price.toStringAsFixed(2), gstRate.toStringAsFixed(0), _lang));
        _setStep(ChatFlowStep.saleItemQty);
      } else {
        _addBotMessage(AppStrings.itemNotFound(_lang));
        _setStep(ChatFlowStep.saleItemName);
      }
    } else {
      final s = _saleSettings;
      final itemName = text.trim();
      if (!s.askQty && !s.askPrice && !s.askGst) {
        // Add item immediately with defaults
        final items = List<Map<String, dynamic>>.from(state.draft['items'] as List? ?? []);
        items.add({
          'name': itemName,
          'qty': s.defaultQty,
          'price': 0,
          'gstRate': s.defaultGst,
        });
        state = state.copyWith(
          draft: {...state.draft, 'items': items, '_currentItem': null, '_awaitingBarcode': false},
        );
        _addBotMessage(AppStrings.itemAdded(itemName, s.defaultQty.toStringAsFixed(0), '0', s.defaultGst.toStringAsFixed(0), _lang));
        _setStep(ChatFlowStep.saleMoreItems, options: [AppStrings.addMore(_lang), AppStrings.doneReview(_lang)]);
      } else {
        state = state.copyWith(
          draft: {...state.draft, '_currentItem': {'name': itemName}},
        );
        if (s.askQty) {
          _addBotMessage(AppStrings.qtyPrompt(_lang));
          _setStep(ChatFlowStep.saleItemQty);
        } else if (s.askPrice) {
          _addBotMessage(AppStrings.pricePrompt(_lang));
          _setStep(ChatFlowStep.saleItemPrice);
        } else {
          _addBotMessage(AppStrings.gstPrompt(_lang));
          _setStep(ChatFlowStep.saleItemGst, options: ['0%', '5%', '12%', '18%', '28%']);
        }
      }
    }
  }

  void _handleSaleItemQty(String text) {
    final s = _saleSettings;
    final qty = s.askQty ? (double.tryParse(text) ?? 1) : s.defaultQty;
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
      _addBotMessage(AppStrings.itemAdded(
        currentItem['name'], qty.toString(), currentItem['price'].toStringAsFixed(2), currentItem['gstRate'].toStringAsFixed(0), _lang));
      _setStep(ChatFlowStep.saleMoreItems, options: [AppStrings.addMore(_lang), AppStrings.doneReview(_lang)]);
    } else {
      state = state.copyWith(draft: {...state.draft, '_currentItem': currentItem});
      if (s.askPrice) {
        _addBotMessage(AppStrings.pricePrompt(_lang));
        _setStep(ChatFlowStep.saleItemPrice);
      } else if (s.askGst) {
        // default price = 0, ask gst
        currentItem['price'] = 0;
        state = state.copyWith(draft: {...state.draft, '_currentItem': currentItem});
        _addBotMessage(AppStrings.gstPrompt(_lang));
        _setStep(ChatFlowStep.saleItemGst, options: ['0%', '5%', '12%', '18%', '28%']);
      } else {
        // no price, no gst — add item with defaults
        final items = List<Map<String, dynamic>>.from(state.draft['items'] as List? ?? []);
        items.add({
          'name': currentItem['name'],
          'qty': qty,
          'price': 0,
          'gstRate': s.defaultGst,
        });
        state = state.copyWith(draft: {...state.draft, 'items': items, '_currentItem': null});
        _addBotMessage(AppStrings.itemAdded(
          currentItem['name'], qty.toStringAsFixed(0), '0', s.defaultGst.toStringAsFixed(0), _lang));
        _setStep(ChatFlowStep.saleMoreItems, options: [AppStrings.addMore(_lang), AppStrings.doneReview(_lang)]);
      }
    }
  }

  void _handleSaleItemPrice(String text) {
    final s = _saleSettings;
    if (!s.askPrice) {
      // Should not normally be called; skip handling
      return;
    }
    final price = double.tryParse(text) ?? 0;
    state = state.copyWith(
      draft: {...state.draft, '_currentItem': {...(state.draft['_currentItem'] as Map<String, dynamic>? ?? {}), 'price': price}},
    );
    if (s.askGst) {
      _addBotMessage(AppStrings.gstPrompt(_lang));
      _setStep(ChatFlowStep.saleItemGst, options: ['0%', '5%', '12%', '18%', '28%']);
    } else {
      // Skip GST — add item with default gst
      final currentItem = (state.draft['_currentItem'] as Map<String, dynamic>? ?? {});
      final items = List<Map<String, dynamic>>.from(state.draft['items'] as List? ?? []);
      items.add({
        'name': currentItem['name'],
        'qty': currentItem['qty'] ?? s.defaultQty,
        'price': price,
        'gstRate': s.defaultGst,
      });
      state = state.copyWith(
        draft: {...state.draft, 'items': items, '_currentItem': null},
      );
      _addBotMessage(AppStrings.itemAdded(
        currentItem['name'], currentItem['qty']?.toString() ?? '1', price.toStringAsFixed(2), s.defaultGst.toStringAsFixed(0), _lang));
      _setStep(ChatFlowStep.saleMoreItems, options: [AppStrings.addMore(_lang), AppStrings.doneReview(_lang)]);
    }
  }

  void _handleSaleItemGst(String text) {
    final s = _saleSettings;
    if (!s.askGst) return;
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
    _addBotMessage(AppStrings.itemAdded(
      currentItem['name'], currentItem['qty'].toString(), currentItem['price'].toStringAsFixed(2), gst.toStringAsFixed(0), _lang));
    _setStep(ChatFlowStep.saleMoreItems, options: [AppStrings.addMore(_lang), AppStrings.doneReview(_lang)]);
  }

  void _handleSaleMoreItems(String text) {
    if (text.contains('Add') || text.contains('✅') || text.contains('जोड़ें')) {
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

    final itemLines = items.asMap().entries.map((e) => '${e.key + 1}. **${e.value['name']}** — ${e.value['qty']} × ₹${e.value['price']}').join('\n');
    _addBotMessage(AppStrings.saleSummary(itemLines, subTotal.toStringAsFixed(2), totalGst.toStringAsFixed(2), grandTotal.toStringAsFixed(2), _lang));
    _setStep(ChatFlowStep.salePaymentMode, options: [AppStrings.cash(_lang), AppStrings.card(_lang), AppStrings.upi(_lang), AppStrings.bank(_lang)]);
  }

  void _handleSalePaymentMode(String text) {
    final s = _saleSettings;
    String mode;
    if (text.contains('Cash') || text.contains('💵') || text.contains('नकद')) mode = 'cash';
    else if (text.contains('Card') || text.contains('💳') || text.contains('कार्ड')) mode = 'card';
    else if (text.contains('UPI') || text.contains('📱')) mode = 'upi';
    else mode = 'bank';

    state = state.copyWith(draft: {...state.draft, 'paymentMode': mode});
    _addBotMessage(_t('Payment mode: **${mode.toUpperCase()}**', 'भुगतान विधि: **${mode.toUpperCase()}**'));
    if (s.askDiscount) {
      _addBotMessage(_t('Enter discount percentage (default: ${s.defaultDiscount.toStringAsFixed(0)}%):', 'डिस्काउंट प्रतिशत दर्ज करें (डिफ़ॉल्ट: ${s.defaultDiscount.toStringAsFixed(0)}%):'));
      _setStep(ChatFlowStep.saleDiscount, options: ['${s.defaultDiscount.toStringAsFixed(0)}%', '0%', '5%', '10%', '15%', '20%']);
    } else {
      state = state.copyWith(draft: {...state.draft, 'discount': s.defaultDiscount});
      _addBotMessage(AppStrings.saveOrCancel(_lang));
      _setStep(ChatFlowStep.saleConfirm, options: [AppStrings.saveSale(_lang), AppStrings.cancel(_lang)]);
    }
  }

  void _handleSaleDiscount(String text) {
    final s = _saleSettings;
    final discountStr = text.replaceAll('%', '');
    final discount = double.tryParse(discountStr) ?? s.defaultDiscount;
    state = state.copyWith(draft: {...state.draft, 'discount': discount});
    _addBotMessage(_t('Discount: **${discount.toStringAsFixed(0)}%**', 'डिस्काउंट: **${discount.toStringAsFixed(0)}%**'));
    _addBotMessage(AppStrings.saveOrCancel(_lang));
    _setStep(ChatFlowStep.saleConfirm, options: [AppStrings.saveSale(_lang), AppStrings.cancel(_lang)]);
  }

  void _handleSaleConfirm(String text) {
    if (text.contains('Save') || text.contains('✅') || text.contains('सहेजें')) {
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
        final discountPercent = (d['discount'] as num?)?.toDouble() ?? 0;
                final discountAmount = subTotal * discountPercent / 100;
        final grandTotal = subTotal + totalTax - discountAmount;

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
          'discountPercent': discountPercent,
          'discountAmount': discountAmount,
          'grandTotal': grandTotal,
          'paymentMode': d['paymentMode'] ?? 'cash',
          'paymentStatus': 'paid',
          'status': 'completed',
          if (d['staffId'] != null) 'staffId': d['staffId'],
          if (d['staffName'] != null) 'staffName': d['staffName'],
        };

        await LocalStorage.cacheInvoice(id, invoice);

        // Reduce stock for sold items
        final catalog = _ref.read(itemCatalogProvider.notifier);
        for (final i in items) {
          final name = i['name']?.toString() ?? '';
          final qty = (i['qty'] as num?)?.toDouble() ?? 0;
          if (name.isEmpty || qty == 0) continue;
          final match = catalog.findByName(name);
          if (match != null && !match.isService) {
            await catalog.adjustStock(match.id, -qty);
          }
        }

        _addBotMessage(AppStrings.saleSaved(invoiceNum, grandTotal.toStringAsFixed(2), d['paymentMode'], _lang));
        _goBackToMenu();
      });
    } else {
      _addBotMessage(AppStrings.cancelled(_lang));
      _goBackToMenu();
    }
  }

  // ─── Purchase Flow ─────────────────────────────────────────────────────────

  void _startPurchaseFlow() {
    state = state.copyWith(
      draft: {'items': <Map<String, dynamic>>[]},
      activeEntity: FlowEntity.purchase,
    );
    _addBotMessage(AppStrings.purchaseSupplier(_lang));
    _setStep(ChatFlowStep.purchaseSupplier);
  }

  void _handlePurchaseSupplier(String text) {
    state = state.copyWith(draft: {...state.draft, 'supplier': text});
    _askPurchaseItemName();
  }

  void _askPurchaseItemName() {
    final items = LocalStorage.itemCatalogBox.values.toList();
    if (items.isEmpty) {
      _addBotMessage(AppStrings.typeItemName(_lang));
      _setStep(ChatFlowStep.purchaseItemName);
    } else {
      final options = items.map((item) => '📦 ${item['name']}').toList();
      options.add(AppStrings.otherItem(_lang));
      _addBotMessage(AppStrings.itemSelect(_lang));
      _setStep(ChatFlowStep.purchaseItemName, options: options);
    }
  }

  void _handlePurchaseItemName(String text) {
    if (text.startsWith('➕')) {
      _addBotMessage(AppStrings.typeItemName(_lang));
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
        _addBotMessage(AppStrings.itemSelected(matched['name'], price.toStringAsFixed(2), gstRate.toStringAsFixed(0), _lang));
        _setStep(ChatFlowStep.purchaseItemQty);
      } else {
        _addBotMessage(AppStrings.itemNotFound(_lang));
        _setStep(ChatFlowStep.purchaseItemName);
      }
    } else {
      state = state.copyWith(
        draft: {...state.draft, '_currentItem': {'name': text}},
      );
      _addBotMessage(AppStrings.qtyPromptPurchase(_lang));
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
      _addBotMessage(AppStrings.itemAdded(
        currentItem['name'], qty.toString(), currentItem['price'].toStringAsFixed(2), currentItem['gstRate'].toStringAsFixed(0), _lang));
      _setStep(ChatFlowStep.purchaseMoreItems, options: [AppStrings.addMore(_lang), AppStrings.doneReview(_lang)]);
    } else {
    state = state.copyWith(draft: {...state.draft, '_currentItem': currentItem});
      _addBotMessage(AppStrings.pricePromptPurchase(_lang));
      _setStep(ChatFlowStep.purchaseItemPrice);
    }
  }

  void _handlePurchaseItemPrice(String text) {
    final price = double.tryParse(text) ?? 0;
    state = state.copyWith(
      draft: {...state.draft, '_currentItem': {...(state.draft['_currentItem'] as Map<String, dynamic>? ?? {}), 'price': price}},
    );
    _addBotMessage(AppStrings.gstPrompt(_lang));
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
    _addBotMessage(AppStrings.itemAdded(
      currentItem['name'], currentItem['qty'].toString(), currentItem['price'].toStringAsFixed(2), gst.toStringAsFixed(0), _lang));
    _setStep(ChatFlowStep.purchaseMoreItems, options: [AppStrings.addMore(_lang), AppStrings.doneReview(_lang)]);
  }

  void _handlePurchaseMoreItems(String text) {
    if (text.contains('Add') || text.contains('✅') || text.contains('जोड़ें')) {
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

    final itemLines = items.asMap().entries.map((e) => '${e.key + 1}. **${e.value['name']}** — ${e.value['qty']} × ₹${e.value['price']}').join('\n');
    _addBotMessage(AppStrings.purchaseSummary(
      state.draft['supplier'], itemLines, subTotal.toStringAsFixed(2), totalGst.toStringAsFixed(2), grandTotal.toStringAsFixed(2), _lang));
    _setStep(ChatFlowStep.purchaseConfirm, options: [AppStrings.savePurchase(_lang), AppStrings.cancel(_lang)]);
  }

  void _handlePurchaseConfirm(String text) {
    if (text.contains('Save') || text.contains('✅') || text.contains('सहेजें')) {
      _botTyping(() async {
        final d = state.draft;
        await _ref.read(createPurchaseProvider.notifier).createPurchase({
          'supplierName': d['supplier'],
          'lineItems': d['items'],
          'invoiceDate': DateTime.now().toIso8601String(),
          'status': 'completed',
        });
        _addBotMessage(AppStrings.purchaseSaved(d['supplier'], _lang));
        _goBackToMenu();
      });
    } else {
      _addBotMessage(AppStrings.cancelled(_lang));
      _goBackToMenu();
    }
  }

  // ─── Item Management ──────────────────────────────────────────────────────

  void removeItem(int index) {
    final items = List<Map<String, dynamic>>.from(state.draft['items'] as List? ?? []);
    if (index < 0 || index >= items.length) return;
    final removed = items.removeAt(index);
    state = state.copyWith(draft: {...state.draft, 'items': items});
    _addBotMessage(AppStrings.removedItem(removed['name'], _lang));
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
    _addBotMessage(AppStrings.updatedItem(item['name'], item['qty'].toString(), item['price'].toStringAsFixed(2), item['gstRate'].toStringAsFixed(0), _lang));
  }

  // ─── Back to Menu ──────────────────────────────────────────────────────────

  void _goBackToMenu() {
    state = state.copyWith(
      step: ChatFlowStep.done,
      draft: {},
      activeEntity: null,
    );
    _setStep(ChatFlowStep.mainMenu, options: [
      AppStrings.menuAddStaff(_lang),
      AppStrings.menuAddCustomer(_lang),
      AppStrings.menuCreateSale(_lang),
      AppStrings.menuCreatePurchase(_lang),
    ]);
  }

  void reset() {
    state = ChatFlowState();
    _sendMainMenu();
  }
}
