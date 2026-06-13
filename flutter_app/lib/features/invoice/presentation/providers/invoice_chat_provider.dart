// lib/features/invoice/presentation/providers/invoice_chat_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;

import '../../data/models/chat_invoice_draft.dart';
import '../../data/models/item_catalog_entry.dart';
import '../../domain/entities/invoice_entity.dart';
import '../providers/item_catalog_provider.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/utils/gst_calculator.dart';
import '../../../../core/utils/chat_strings.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../features/customer/presentation/providers/customer_provider.dart';
import '../../../../features/dashboard/presentation/providers/dashboard_provider.dart';

// ─── Chat Step Enum ───────────────────────────────────────────────────────────

enum ChatStep {
  welcome,
  askCustomerName,
  askCustomerPhone,
  askCustomerGstin,
  askItemName,
  askItemQuantity,
  askItemPrice,
  askItemGst,
  askMoreItems,
  showSummary,
  askSaveCustomer,
  askSaveItem,
  done,
}

// ─── Chat State ───────────────────────────────────────────────────────────────

class InvoiceChatState {
  final List<types.Message> messages;
  final ChatStep step;
  final ChatInvoiceDraft draft;
  final bool isBotTyping;
  final bool isInvoiceCreated;
  final String? createdInvoiceId;
  final InvoiceEntity? createdInvoice;
  final List<String> dynamicQuickReplies;
  final String sessionId;
  final AppLanguage lang;

  InvoiceChatState({
    this.messages = const [],
    this.step = ChatStep.welcome,
    this.draft = const ChatInvoiceDraft(),
    this.isBotTyping = false,
    this.isInvoiceCreated = false,
    this.createdInvoiceId,
    this.createdInvoice,
    this.dynamicQuickReplies = const [],
    String? sessionId,
    this.lang = AppLanguage.english,
  }) : sessionId = sessionId ?? DateTime.now().millisecondsSinceEpoch.toString();

  InvoiceChatState copyWith({
    List<types.Message>? messages,
    ChatStep? step,
    ChatInvoiceDraft? draft,
    bool? isBotTyping,
    bool? isInvoiceCreated,
    String? createdInvoiceId,
    InvoiceEntity? createdInvoice,
    List<String>? dynamicQuickReplies,
    AppLanguage? lang,
  }) {
    return InvoiceChatState(
      messages: messages ?? this.messages,
      step: step ?? this.step,
      draft: draft ?? this.draft,
      isBotTyping: isBotTyping ?? this.isBotTyping,
      isInvoiceCreated: isInvoiceCreated ?? this.isInvoiceCreated,
      createdInvoiceId: createdInvoiceId ?? this.createdInvoiceId,
      createdInvoice: createdInvoice ?? this.createdInvoice,
      dynamicQuickReplies: dynamicQuickReplies ?? this.dynamicQuickReplies,
      sessionId: sessionId,
      lang: lang ?? this.lang,
    );
  }
}

// ─── Chat Users ───────────────────────────────────────────────────────────────

const chatUser = types.User(id: 'invoice-user', firstName: 'You');
const chatBot = types.User(id: 'invoice-bot', firstName: 'Invoice', lastName: 'Assistant');

// ─── Provider ─────────────────────────────────────────────────────────────────

/// AutoDispose — provider resets automatically when the chat page is popped.
final invoiceChatProvider =
    StateNotifierProvider.autoDispose<InvoiceChatNotifier, InvoiceChatState>(
  (ref) => InvoiceChatNotifier(ref),
);

class InvoiceChatNotifier extends StateNotifier<InvoiceChatState> {
  InvoiceChatNotifier(Ref ref)
      : _ref = ref,
        super(InvoiceChatState(lang: ref.read(appLanguageProvider))) {
    // Auto-sync with the global voice language (changed on Home page or any toggle).
    // Lifecycle is tied to this ref — cancelled automatically when provider disposes.
    ref.listen<AppLanguage>(appLanguageProvider, (_, newLang) {
      if (state.lang == newLang) return;
      if (state.step == ChatStep.welcome ||
          state.step == ChatStep.askCustomerName) {
        // Still at the very beginning — restart welcome in the new language
        state = InvoiceChatState(lang: newLang);
        _sendWelcome();
      } else {
        // Mid-conversation: silently switch language; future bot messages use new lang
        state = state.copyWith(lang: newLang);
      }
    });
    _sendWelcome();
  }

  final Ref _ref;
  final _uuid = const Uuid();

  ChatStrings get _s => ChatStrings(state.lang);

  List<CustomerEntity> get _savedCustomers =>
      _ref.read(customerListProvider).valueOrNull ?? [];

  List<ItemCatalogEntry> get _catalogItems => _ref.read(itemCatalogProvider);

  List<String> _customerQuickReplies() =>
      _savedCustomers.map((c) => c.name).take(5).toList();

  List<String> _itemQuickReplies() =>
      _catalogItems.map((i) => i.name).take(5).toList();

  // ─── Select Customer (from picker) ──────────────────────────────────────────

  /// Called when the user picks a customer from the customer-picker sheet.
  /// Fills name/phone/GSTIN/address from the saved record and jumps to items.
  Future<void> selectCustomer(CustomerEntity customer) async {
    // Post a user-style message so the chat shows what was picked
    final userMsg = _userMessage(customer.name);
    state = state.copyWith(
      messages: [userMsg, ...state.messages],
      isBotTyping: true,
      dynamicQuickReplies: [],
      draft: state.draft.copyWith(
        customerName: customer.name,
        customerPhone: customer.phone,
        customerGstin: customer.gstin,
        customerAddress: customer.address,
      ),
      step: ChatStep.askItemName,
    );
    await Future.delayed(const Duration(milliseconds: 500));
    _addBotMessage(
      _s.customerFoundAskItem(
        customer.name,
        customer.phone,
        customer.gstin,
        hasCatalog: _catalogItems.isNotEmpty,
      ),
      replies: _itemQuickReplies(),
    );
  }

  // ─── Language Switch ─────────────────────────────────────────────────────────

  void changeLanguage(AppLanguage lang) {
    // Handled internally by the ref.listen in the constructor.
    // This method kept for external calls; state already updated by listener.
    if (state.lang == lang) return;
    state = state.copyWith(lang: lang);
    // No bot message — user already sees they changed the toggle
  }

  // ─── Welcome ─────────────────────────────────────────────────────────────────

  void _sendWelcome() {
    final msg = _botMessage(_s.welcome(
      hasCustomers: _savedCustomers.isNotEmpty,
      hasCatalog: _catalogItems.isNotEmpty,
    ));
    state = state.copyWith(
      messages: [msg],
      step: ChatStep.askCustomerName,
      dynamicQuickReplies: _customerQuickReplies(),
    );
  }

  // ─── Handle user message ─────────────────────────────────────────────────────

  Future<void> handleUserMessage(String text) async {
    // Normalize Devanagari digits
    text = HindiNLP.convertDevanagariDigits(text);
    final userMsg = _userMessage(text);
    state = state.copyWith(
      messages: [userMsg, ...state.messages],
      isBotTyping: true,
      dynamicQuickReplies: [],
    );
    await Future.delayed(const Duration(milliseconds: 600));
    final trimmed = text.trim();

    if (_looksLikeFullInvoice(trimmed)) {
      final parsed = _parseFullInvoice(trimmed);
      if (parsed != null) { await _handleFullParse(parsed); return; }
    }

    switch (state.step) {
      case ChatStep.askCustomerName: await _handleCustomerName(trimmed); break;
      case ChatStep.askCustomerPhone: await _handleCustomerPhone(trimmed); break;
      case ChatStep.askCustomerGstin: await _handleCustomerGstin(trimmed); break;
      case ChatStep.askItemName: await _handleItemName(trimmed); break;
      case ChatStep.askItemQuantity: await _handleItemQuantity(trimmed); break;
      case ChatStep.askItemPrice: await _handleItemPrice(trimmed); break;
      case ChatStep.askItemGst: await _handleItemGst(trimmed); break;
      case ChatStep.askMoreItems: await _handleMoreItems(trimmed); break;
      case ChatStep.showSummary: await _handleSummaryConfirm(trimmed); break;
      case ChatStep.askSaveCustomer: await _handleSaveCustomer(trimmed); break;
      case ChatStep.askSaveItem: await _handleSaveItem(trimmed); break;
      default: _addBotMessage(_s.typeRestart(), replies: []);
    }
  }

  void handleQuickReply(String text) => handleUserMessage(text);

  // ─── Customer Name ───────────────────────────────────────────────────────────

  Future<void> _handleCustomerName(String rawInput) async {
    // ── Step 1: Extract embedded phone / GSTIN from the raw voice input ────────
    final embeddedPhone = _extractPhoneFrom(rawInput);
    final embeddedGstin = _extractGstinFrom(rawInput);

    // ── Step 2: Clean the name (remove digits, phone, gstin, keywords) ─────────
    final name = _cleanCustomerName(rawInput);

    if (name.length < 2) {
      _addBotMessage(_s.invalidName(), replies: _customerQuickReplies());
      return;
    }

    // ── Step 3: Look up saved customer ─────────────────────────────────────────
    final saved = _savedCustomers
        .where((c) => c.name.toLowerCase() == name.toLowerCase())
        .firstOrNull;

    state = state.copyWith(
      draft: state.draft.copyWith(
        customerName: name,
        customerPhone: saved?.phone ?? embeddedPhone,
        customerGstin: saved?.gstin ?? embeddedGstin,
      ),
    );

    if (saved != null) {
      state = state.copyWith(step: ChatStep.askItemName);
      _addBotMessage(
        _s.customerFoundAskItem(name, saved.phone, saved.gstin,
            hasCatalog: _catalogItems.isNotEmpty),
        replies: _itemQuickReplies(),
      );
      return;
    }

    // ── Step 4: Route based on what was extracted ───────────────────────────────
    if (embeddedPhone != null && embeddedGstin != null) {
      // Have name + phone + GSTIN — jump straight to items
      state = state.copyWith(step: ChatStep.askItemName);
      _addBotMessage(
        _s.customerFoundAskItem(name, embeddedPhone, embeddedGstin,
            hasCatalog: _catalogItems.isNotEmpty),
        replies: _itemQuickReplies(),
      );
    } else if (embeddedPhone != null) {
      // Have name + phone — skip phone step, ask GSTIN
      state = state.copyWith(step: ChatStep.askCustomerGstin);
      _addBotMessage(
        _s.phoneSavedAskGstin(embeddedPhone, false),
        replies: [_s.skip()],
      );
    } else {
      // Only name — ask phone normally
      state = state.copyWith(step: ChatStep.askCustomerPhone);
      _addBotMessage(_s.askCustomerPhone(name), replies: [_s.skip()]);
    }
  }

  /// Extracts a 10-digit Indian phone from free text.
  /// Handles: "फोन 9876543210", "phone: 9876543210", standalone 10-digit
  String? _extractPhoneFrom(String input) {
    // With keyword prefix (Hindi + English)
    final keyM = RegExp(
      r'(?:phone|mobile|mob|call|contact|number|no\.?|फोन|मोबाइल|नंबर|मो\.?)'
      r'\s*[:\-]?\s*'
      r'(\+?91[-\s]?\d{10}|\d{10})',
      caseSensitive: false,
    ).firstMatch(input);
    if (keyM != null) {
      final digits = keyM.group(1)!.replaceAll(RegExp(r'[^\d]'), '');
      final ten = digits.length >= 10 ? digits.substring(digits.length - 10) : null;
      return ten != null ? '+91$ten' : null;
    }
    // Standalone 10-digit number
    final standalone = RegExp(r'\b(\d{10})\b').firstMatch(input);
    if (standalone != null) return '+91${standalone.group(1)!}';
    return null;
  }

  /// Extracts a 15-character GSTIN from free text.
  String? _extractGstinFrom(String input) {
    final m = RegExp(
      r'(?:gstin|gst|जीएसटी|जी\.एस\.टी\.?)\s*[:\-]?\s*([A-Z0-9]{15})',
      caseSensitive: false,
    ).firstMatch(input);
    return m != null ? m.group(1)!.toUpperCase() : null;
  }

  /// Cleans a raw voice input to extract just the person/company name.
  /// Removes: phone numbers, GSTIN, phone/gstin keywords, digits, punctuation.
  String _cleanCustomerName(String input) {
    var text = input;
    // Remove GSTIN (15-char alphanum after keyword)
    text = text.replaceAll(
        RegExp(r'(?:gstin|gst|जीएसटी|जी\.एस\.टी\.?)\s*[:\-]?\s*[A-Z0-9]{15}',
            caseSensitive: false),
        '');
    // Remove phone with keyword
    text = text.replaceAll(
        RegExp(
          r'(?:phone|mobile|mob|call|contact|number|no\.?|फोन|मोबाइल|नंबर|मो\.?)'
          r'\s*[:\-]?\s*\+?91[-\s]?\d{10}',
          caseSensitive: false,
        ),
        '');
    text = text.replaceAll(
        RegExp(
          r'(?:phone|mobile|mob|call|contact|number|no\.?|फोन|मोबाइल|नंबर|मो\.?)'
          r'\s*[:\-]?\s*\d+',
          caseSensitive: false,
        ),
        '');
    // Remove standalone phone / 6-digit+ number chains
    text = text.replaceAll(RegExp(r'\+?91[-\s]?\d{10}'), '');
    text = text.replaceAll(RegExp(r'\b\d{6,}\b'), '');
    text = text.replaceAll(RegExp(r'\b\d+\b'), '');
    // Remove leftover keywords
    text = text.replaceAll(
        RegExp(
          r'\b(phone|mobile|mob|gstin|gst|फोन|मोबाइल|नंबर|जीएसटी|call|contact)\b',
          caseSensitive: false,
        ),
        '');
    // Collapse whitespace and trim
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  // ─── Customer Phone ──────────────────────────────────────────────────────────

  Future<void> _handleCustomerPhone(String input) async {
    final lower = input.toLowerCase();
    final skip = HindiNLP.isSkip(lower) || lower.startsWith('skip');
    final phone = input.replaceAll(RegExp(r'[^\d]'), '');
    if (!skip && phone.length != 10) {
      _addBotMessage(_s.invalidPhone(), replies: [_s.skip()]);
      return;
    }
    state = state.copyWith(
      draft: state.draft.copyWith(customerPhone: skip ? null : '+91$phone'),
      step: ChatStep.askCustomerGstin,
    );
    _addBotMessage(
      _s.phoneSavedAskGstin('+91$phone', skip),
      replies: [_s.skip()],
    );
  }

  // ─── Customer GSTIN ──────────────────────────────────────────────────────────

  Future<void> _handleCustomerGstin(String input) async {
    final lower = input.toLowerCase();
    final skip = HindiNLP.isSkip(lower) || lower.startsWith('skip');
    final gstin = input.toUpperCase().trim();
    if (!skip && !_isValidGstin(gstin)) {
      _addBotMessage(_s.invalidGstin(), replies: [_s.skip()]);
      return;
    }
    state = state.copyWith(
      draft: state.draft.copyWith(customerGstin: skip ? null : gstin),
      step: ChatStep.askItemName,
    );
    _addBotMessage(
      _s.gstinSavedAskItem(gstin, skip, hasCatalog: _catalogItems.isNotEmpty),
      replies: _itemQuickReplies(),
    );
  }

  // ─── Item Name ───────────────────────────────────────────────────────────────

  Future<void> _handleItemName(String name) async {
    if (name.length < 2) {
      _addBotMessage(_s.invalidItemName(), replies: _itemQuickReplies());
      return;
    }

    // ── Fast path: "N unit itemName" e.g. "1 kg sugar", "2 ltr milk" ──────────
    final qun = _parseQtyUnitName(name);
    if (qun != null) {
      // Check catalog first
      final catalog = _catalogItems
          .where((i) => i.name.toLowerCase() == qun['name']!.toLowerCase())
          .firstOrNull;
      if (catalog != null) {
        state = state.copyWith(
          draft: state.draft.copyWith(
            currentItem: ChatLineItemDraft(
              name: catalog.name,
              quantity: qun['qty'] as double,
              unit: qun['unit'] as String,
              unitPrice: catalog.unitPrice,
              gstRate: catalog.gstRate,
            ),
          ),
          step: ChatStep.askItemQuantity, // reuse qty step to confirm qty
        );
        _addBotMessage(
          _s.catalogItemFound(
              catalog.name, catalog.unitPrice, catalog.gstRate, qun['unit'] as String),
          replies: ['1', '2', '5', '10', '25'],
        );
      } else {
        state = state.copyWith(
          draft: state.draft.copyWith(
            currentItem: ChatLineItemDraft(
              name: qun['name'] as String,
              quantity: qun['qty'] as double,
              unit: qun['unit'] as String,
            ),
          ),
          step: ChatStep.askItemPrice,
        );
        _addBotMessage(
          _s.qtySavedAskPrice(qun['qty'] as double, qun['unit'] as String),
          replies: [],
        );
      }
      return;
    }

    // ── Standard path ─────────────────────────────────────────────────────────
    final quick = _tryParseItemInOneLine(name);
    if (quick != null && quick.isComplete) {
      _addItemThenAskMore(quick.toLineItem()); return;
    }

    // Partial parse: have price/qty/gst but no name → pre-fill and ask for name
    if (quick != null && quick.unitPrice != null && quick.name == null) {
      state = state.copyWith(
        draft: state.draft.copyWith(
          currentItem: ChatLineItemDraft(
            quantity: quick.quantity,
            unitPrice: quick.unitPrice,
            gstRate: quick.gstRate,
            unit: quick.unit,
          ),
        ),
        step: ChatStep.askItemName,
      );
      _addBotMessage(_s.invalidItemName(), replies: _itemQuickReplies());
      return;
    }

    final catalog = _catalogItems
        .where((i) => i.name.toLowerCase() == name.toLowerCase())
        .firstOrNull;
    if (catalog != null) {
      state = state.copyWith(
        draft: state.draft.copyWith(
          currentItem: ChatLineItemDraft(
            name: catalog.name, unitPrice: catalog.unitPrice,
            gstRate: catalog.gstRate, unit: catalog.unit,
          ),
        ),
        step: ChatStep.askItemQuantity,
      );
      _addBotMessage(
        _s.catalogItemFound(catalog.name, catalog.unitPrice,
            catalog.gstRate, catalog.unit),
        replies: ['1', '2', '5', '10', '25'],
      );
    } else {
      state = state.copyWith(
        draft: state.draft.copyWith(
            currentItem: state.draft.currentItem.copyWith(name: name)),
        step: ChatStep.askItemQuantity,
      );
      _addBotMessage(_s.itemNameSavedAskQty(name),
          replies: ['1', '2', '5', '10']);
    }
  }

  /// Parses patterns like "1 kg sugar", "2 ltr milk", "5 पीस बिस्किट".
  /// Returns {qty, unit, name} or null if pattern not matched.
  Map<String, dynamic>? _parseQtyUnitName(String input) {
    final normalized = HindiNLP.convertDevanagariDigits(input);
    final lower = normalized.toLowerCase().trim();

    // English/digit pattern: "2 kg sugar", "1.5 ltr milk"
    final m = RegExp(
      r'^(\d+\.?\d*)\s*'
      r'(kg|kgs?|kilogram|gram|grams?|gm|litre?s?|ltr|pcs?|pieces?|nos?|units?|box(?:es)?|bags?|hours?|hrs?|meter|metres?|mtr|day|days|month|months?)'
      r'\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(lower);

    if (m != null) {
      final qty = double.tryParse(m.group(1)!);
      final unit = _normalizeUnit(m.group(2)!);
      final itemName = _capitalize(m.group(3)!.trim());
      if (qty != null && qty > 0 && itemName.length >= 2) {
        return {'qty': qty, 'unit': unit, 'name': itemName};
      }
    }

    // Hindi unit pattern: "2 किलो चीनी", "1 लीटर दूध"
    final hindiUnitMap = {
      r'किलो|किलोग्राम': 'Kg',
      r'ग्राम': 'Gm',
      r'लीटर|लिटर': 'Ltr',
      r'नग|पीस|पीस': 'Pcs',
      r'बॉक्स': 'Box',
      r'बैग|थैला': 'Bag',
      r'घंटा|घंटे': 'Hr',
    };
    for (final entry in hindiUnitMap.entries) {
      final mH = RegExp(r'^(\d+\.?\d*)\s*(' + entry.key + r')\s+(.+)$')
          .firstMatch(lower);
      if (mH != null) {
        final qty = double.tryParse(mH.group(1)!);
        final itemName = _capitalize(mH.group(3)!.trim());
        if (qty != null && qty > 0 && itemName.length >= 2) {
          return {'qty': qty, 'unit': entry.value, 'name': itemName};
        }
      }
    }

    return null;
  }

  // ─── Item Quantity ───────────────────────────────────────────────────────────

  Future<void> _handleItemQuantity(String input) async {
    // Try Hindi number extraction first, then standard
    double? qty = HindiNLP.extractNumber(input) ??
        double.tryParse(input.replaceAll(RegExp(r'[^\d.]'), ''));
    if (qty == null || qty <= 0) {
      _addBotMessage(_s.invalidQty(), replies: ['1', '2', '5', '10']);
      return;
    }
    String unit = state.draft.currentItem.unit ??
        HindiNLP.extractUnit(input) ??
        'Nos';
    final unitMatch = RegExp(
            r'(kg|kgs|litre|ltr|pcs|nos|units?|box|bags?|hours?|hrs?)',
            caseSensitive: false)
        .firstMatch(input);
    if (unitMatch != null) unit = _normalizeUnit(unitMatch.group(0)!);

    state = state.copyWith(
      draft: state.draft.copyWith(
        currentItem: state.draft.currentItem.copyWith(quantity: qty, unit: unit),
      ),
    );
    if (state.draft.currentItem.unitPrice != null) {
      state = state.copyWith(step: ChatStep.askItemGst);
      _addBotMessage(
        _s.qtyCatalogAskGst(
            qty, unit, state.draft.currentItem.unitPrice!),
        replies: ['0%', '5%', '12%', '18%', '28%'],
      );
    } else {
      state = state.copyWith(step: ChatStep.askItemPrice);
      _addBotMessage(_s.qtySavedAskPrice(qty, unit), replies: []);
    }
  }

  // ─── Item Price ──────────────────────────────────────────────────────────────

  Future<void> _handleItemPrice(String input) async {
    final price = HindiNLP.extractNumber(input) ??
        double.tryParse(
            input.replaceAll(RegExp(r'[₹,\s]'), '').replaceAll(RegExp(r'[^\d.]'), ''));
    if (price == null || price <= 0) {
      _addBotMessage(_s.invalidPrice(), replies: []);
      return;
    }
    state = state.copyWith(
      draft: state.draft.copyWith(
          currentItem: state.draft.currentItem.copyWith(unitPrice: price)),
      step: ChatStep.askItemGst,
    );
    _addBotMessage(_s.priceSavedAskGst(price),
        replies: ['0%', '5%', '12%', '18%', '28%']);
  }

  // ─── Item GST ────────────────────────────────────────────────────────────────

  Future<void> _handleItemGst(String input) async {
    final rate = HindiNLP.extractGstRate(input) ??
        double.tryParse(input.replaceAll(RegExp(r'[%\s]'), ''));
    const validRates = [0.0, 5.0, 12.0, 18.0, 28.0];
    if (rate == null || !validRates.contains(rate)) {
      _addBotMessage(_s.invalidGstRate(),
          replies: ['0%', '5%', '12%', '18%', '28%']);
      return;
    }
    final item = state.draft.currentItem.copyWith(gstRate: rate).toLineItem();
    final isNew = _catalogItems
        .where((i) => i.name.toLowerCase() == item.name.toLowerCase())
        .isEmpty;
    final updatedItems = [...state.draft.items, item];
    state = state.copyWith(
      draft: state.draft.copyWith(
          items: updatedItems, currentItem: const ChatLineItemDraft()),
    );
    if (isNew) {
      state = state.copyWith(step: ChatStep.askSaveItem);
      _addBotMessage(
        _s.itemAddedAskSave(item.name, item.quantity, item.unitPrice, rate),
        replies: [_s.saveItem(), _s.skip()],
      );
    } else {
      _askMoreItems(item);
    }
  }

  // ─── Save Item ───────────────────────────────────────────────────────────────

  Future<void> _handleSaveItem(String input) async {
    final lower = input.toLowerCase();
    final lastItem = state.draft.items.isEmpty ? null : state.draft.items.last;
    if ((HindiNLP.isYes(lower) || lower.contains('save') || lower == 'yes') &&
        lastItem != null) {
      await _ref.read(itemCatalogProvider.notifier).addItem(
        name: lastItem.name,
        unitPrice: lastItem.unitPrice,
        gstRate: lastItem.gstRate,
        unit: lastItem.unit,
      );
      _askMoreItems(lastItem, saved: true);
    } else {
      _askMoreItems(lastItem);
    }
  }

  void _addItemThenAskMore(ChatLineItem item) {
    state = state.copyWith(
      draft: state.draft.copyWith(
        items: [...state.draft.items, item],
        currentItem: const ChatLineItemDraft(),
      ),
    );
    _askMoreItems(item);
  }

  void _askMoreItems(ChatLineItem? item, {bool saved = false}) {
    final count = state.draft.items.length;
    state = state.copyWith(step: ChatStep.askMoreItems);
    _addBotMessage(
      item != null
          ? _s.askMoreItems(item.name, count, saved: saved)
          : _s.needAtLeastOneItem(),
      replies: [_s.addMoreItems(), _s.reviewConfirm()],
    );
  }

  // ─── More Items ──────────────────────────────────────────────────────────────

  Future<void> _handleMoreItems(String input) async {
    final lower = input.toLowerCase();
    if (HindiNLP.isAddMore(lower)) {
      state = state.copyWith(step: ChatStep.askItemName);
      _addBotMessage(
        _s.nextItemAsk(hasCatalog: _catalogItems.isNotEmpty),
        replies: _itemQuickReplies(),
      );
    } else {
      _showSummary();
    }
  }

  // ─── Summary Confirm ─────────────────────────────────────────────────────────

  Future<void> _handleSummaryConfirm(String input) async {
    final lower = input.toLowerCase();
    if (lower == 'confirm' || lower == 'yes' || lower == 'create' ||
        lower == 'ok' || lower.contains('✅') ||
        HindiNLP.isYes(lower) || HindiNLP.isReview(lower)) {
      final invoice = _buildInvoiceEntity(state.draft);
      await LocalStorage.cacheInvoice(invoice.id, _invoiceToJson(invoice));
      _ref.invalidate(dashboardStatsProvider);
      _ref.invalidate(recentInvoicesProvider);

      state = state.copyWith(
        step: ChatStep.askSaveCustomer,
        isInvoiceCreated: true,
        createdInvoiceId: invoice.id,
        createdInvoice: invoice,
        isBotTyping: false,
      );
      _addBotMessage(
        _s.invoiceCreated(
          invoiceNumber: invoice.invoiceNumber,
          customerName: invoice.customerName,
          itemCount: invoice.lineItems.length,
          grandTotal: invoice.grandTotal,
        ),
        replies: [_s.saveCustomer(), _s.skip()],
      );
    } else if (HindiNLP.isEdit(lower)) {
      state = state.copyWith(
          draft: state.draft.copyWith(items: []),
          step: ChatStep.askItemName);
      _addBotMessage(_s.editItems(), replies: _itemQuickReplies());
    } else if (HindiNLP.isRestart(lower)) {
      _restart();
    } else {
      _addBotMessage(_s.confirmHint(),
          replies: [_s.confirm(), _s.editItemsBtn(), _s.restart()]);
    }
  }

  // ─── Save Customer ───────────────────────────────────────────────────────────

  Future<void> _handleSaveCustomer(String input) async {
    final lower = input.toLowerCase();
    final draft = state.draft;
    if (HindiNLP.isYes(lower) || lower.contains('save') || lower == 'yes') {
      final id = 'cust-${_uuid.v4().substring(0, 8)}';
      final data = {
        'id': id,
        'name': draft.customerName ?? 'Customer',
        'phone': draft.customerPhone,
        'gstin': draft.customerGstin,
        'email': draft.customerEmail,
        'invoiceCount': 1,
        'totalBusiness': state.createdInvoice?.grandTotal ?? 0,
        'createdAt': DateTime.now().toIso8601String(),
      };
      await LocalStorage.cacheCustomer(id, data);
      try {
        _ref
            .read(customerListProvider.notifier)
            .addCustomer(CustomerEntity.fromJson(data));
      } catch (_) {}
      state = state.copyWith(step: ChatStep.done, dynamicQuickReplies: []);
      _addBotMessage(_s.customerSaved(draft.customerName ?? 'Customer'),
          replies: []);
    } else {
      state = state.copyWith(step: ChatStep.done, dynamicQuickReplies: []);
      _addBotMessage(_s.skippedViewInvoice(), replies: []);
    }
  }

  // ─── Show Summary ────────────────────────────────────────────────────────────

  void _showSummary() {
    if (state.draft.items.isEmpty) {
      state = state.copyWith(step: ChatStep.askItemName);
      _addBotMessage(_s.needAtLeastOneItem(), replies: _itemQuickReplies());
      return;
    }
    final draft = state.draft;
    final itemsStr = draft.items.asMap().entries.map((e) {
      final i = e.value;
      return '${e.key + 1}. **${i.name}** × ${i.quantity.toStringAsFixed(i.quantity % 1 == 0 ? 0 : 1)}'
          ' @ ₹${i.unitPrice.toStringAsFixed(0)} + ${i.gstRate.toStringAsFixed(0)}% = ₹${i.totalAmount.toStringAsFixed(2)}';
    }).join('\n');

    state = state.copyWith(step: ChatStep.showSummary);
    _addBotMessage(
      _s.summary(
        customerName: draft.customerName ?? 'N/A',
        phone: draft.customerPhone,
        gstin: draft.customerGstin,
        itemsStr: itemsStr,
        itemCount: draft.items.length,
        subTotal: draft.subTotal,
        totalGst: draft.totalGst,
        grandTotal: draft.grandTotal,
      ),
      replies: [_s.confirm(), _s.editItemsBtn(), _s.restart()],
    );
  }

  void _restart() {
    // Always pick up the current global language when restarting
    final lang = _ref.read(appLanguageProvider);
    state = InvoiceChatState(lang: lang);
    _sendWelcome();
  }

  void resetChat() => _restart();

  // ─── Build Invoice ───────────────────────────────────────────────────────────

  InvoiceEntity _buildInvoiceEntity(ChatInvoiceDraft draft) {
    final id = 'chat-${_uuid.v4().substring(0, 8)}';
    final invoiceNumber = 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final now = DateTime.now();

    final lineItems = draft.items.map((item) {
      final b = GstCalculator.calculate(
          taxableAmount: item.taxableAmount, gstRate: item.gstRate, isInterState: false);
      return InvoiceLineItemEntity(
        description: item.name, quantity: item.quantity, unit: item.unit,
        unitPrice: item.unitPrice, discountAmount: 0, taxableAmount: item.taxableAmount,
        gstRate: item.gstRate, cgst: b.cgst, sgst: b.sgst, igst: b.igst,
        totalAmount: b.totalAmount,
      );
    }).toList();

    final totals = GstCalculator.calculateInvoiceTotals(
      lineItems: draft.items.map((i) => InvoiceLineItem(
        description: i.name, quantity: i.quantity, unitPrice: i.unitPrice, gstRate: i.gstRate)).toList(),
      isInterState: false,
    );

    return InvoiceEntity(
      id: id, invoiceNumber: invoiceNumber, businessId: 'demo-business-001',
      customerName: draft.customerName ?? 'Customer',
      customerPhone: draft.customerPhone, customerGstin: draft.customerGstin,
      customerAddress: draft.customerAddress,
      invoiceDate: now, dueDate: now.add(const Duration(days: 30)),
      lineItems: lineItems, subTotal: totals.subTotal,
      totalCgst: totals.totalCgst, totalSgst: totals.totalSgst,
      totalIgst: totals.totalIgst, totalCess: totals.totalCess,
      totalTax: totals.totalTax, discountAmount: 0,
      grandTotal: totals.grandTotal, roundOff: totals.roundOff,
      status: 'draft', isInterState: false,
      gstSlabs: totals.gstSlabs.map((s) => GstSlabEntity(
        rate: s.gstRate, taxableAmount: s.taxableAmount,
        cgst: s.cgst, sgst: s.sgst, igst: s.igst)).toList(),
      createdAt: now,
    );
  }

  Map<String, dynamic> _invoiceToJson(InvoiceEntity inv) => {
    'id': inv.id, 'invoiceNumber': inv.invoiceNumber, 'businessId': inv.businessId,
    'customerName': inv.customerName, 'customerPhone': inv.customerPhone,
    'customerGstin': inv.customerGstin, 'customerAddress': inv.customerAddress,
    'invoiceDate': inv.invoiceDate.toIso8601String(),
    'dueDate': inv.dueDate?.toIso8601String(), 'subTotal': inv.subTotal,
    'totalCgst': inv.totalCgst, 'totalSgst': inv.totalSgst, 'totalIgst': inv.totalIgst,
    'totalCess': inv.totalCess, 'totalTax': inv.totalTax, 'discountAmount': inv.discountAmount,
    'grandTotal': inv.grandTotal, 'roundOff': inv.roundOff, 'status': inv.status,
    'isInterState': inv.isInterState, 'createdAt': inv.createdAt.toIso8601String(),
    'lineItems': inv.lineItems.map((li) => {
      'description': li.description, 'quantity': li.quantity, 'unit': li.unit,
      'unitPrice': li.unitPrice, 'discountAmount': li.discountAmount,
      'taxableAmount': li.taxableAmount, 'gstRate': li.gstRate,
      'cgst': li.cgst, 'sgst': li.sgst, 'igst': li.igst, 'cess': li.cess,
      'totalAmount': li.totalAmount,
    }).toList(),
    'gstSlabs': inv.gstSlabs.map((s) => {
      'rate': s.rate, 'taxableAmount': s.taxableAmount,
      'cgst': s.cgst, 'sgst': s.sgst, 'igst': s.igst,
    }).toList(),
  };

  // ─── NLP Helpers ─────────────────────────────────────────────────────────────

  /// Robustly parses a single-line item description like:
  ///   "1 laptop 5000 rs 18% gst"
  ///   "2 chairs at 1500 5% gst"
  ///   "laptop rs 5000 18%"
  ///   "1 kg sugar 100 rs 5%"  ← but _parseQtyUnitName handles that first
  ChatLineItemDraft? _tryParseItemInOneLine(String input) {
    final lower = HindiNLP.convertDevanagariDigits(input).toLowerCase().trim();

    // ── 1. Price — try in priority order ──────────────────────────────────────
    //   a) number-then-rs:  "5000 rs"  / "5000₹"
    //   b) keyword-then-number: "at 500" / "@ 500" / "price: 500"
    //   c) rs-then-number:  "rs 5000"
    double? price;
    Match? priceMatch;

    final priceRegexPairs = <RegExp>[
      RegExp(r'(\d[\d,]*(?:\.\d{1,2})?)\s*(?:rs\.?|₹|rupees?)(?!\d)'),
      RegExp(r'(?:at|@|price|cost|rate)\s*[:\-]?\s*(\d[\d,]*(?:\.\d{1,2})?)'),
      RegExp(r'(?:rs\.?|₹|rupees?)\s*(\d[\d,]*(?:\.\d{1,2})?)'),
    ];
    for (final priceRe in priceRegexPairs) {
      priceMatch = priceRe.firstMatch(lower);
      if (priceMatch != null) {
        price = double.tryParse(priceMatch.group(1)!.replaceAll(',', ''));
        if (price != null && price > 0) break;
        priceMatch = null;
      }
    }

    // ── 2. GST rate ────────────────────────────────────────────────────────────
    double? gstRate;
    final gstM = RegExp(
      r'(\d+)\s*(?:%|percent|प्रतिशत|फीसदी)\s*(?:gst|जीएसटी)?'
      r'|(?:gst|जीएसटी)\s*[:\-]?\s*(\d+)\s*%?',
      caseSensitive: false,
    ).firstMatch(lower);
    if (gstM != null) {
      final r = double.tryParse((gstM.group(1) ?? gstM.group(2)) ?? '');
      const valid = [0.0, 5.0, 12.0, 18.0, 28.0];
      if (r != null && valid.contains(r)) gstRate = r;
    }

    // ── 3. Quantity from start of input ────────────────────────────────────────
    double? qty;
    int qtyEnd = 0;
    final qtyM = RegExp(
      r'^(\d+\.?\d*)\s*'
      r'(?:kg|kgs?|gm|gram|ltr|litre|pcs?|nos?|units?|box(?:es)?|bags?)?'
      r'(?:\s|$)',
      caseSensitive: false,
    ).firstMatch(lower);
    if (qtyM != null) {
      qty = double.tryParse(qtyM.group(1)!);
      qtyEnd = qtyM.end;
    }

    // ── 4. Name = text between qty end and price start ────────────────────────
    String? name;
    final priceStart = priceMatch?.start ?? lower.length;

    if (qtyEnd <= priceStart) {
      var slice = lower.substring(qtyEnd, priceStart).trim();
      // Strip trailing gst/percent/% tokens and digits
      slice = slice
          .replaceAll(
              RegExp(r'\d+\s*(?:%|percent|प्रतिशत)?.*$',
                  caseSensitive: false),
              '')
          .replaceAll(
              RegExp(r'(?:gst|जीएसटी|percent|प्रतिशत)',
                  caseSensitive: false),
              '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (slice.length >= 2) name = _capitalize(slice);
    }

    // Fallback: keyword-based name extraction
    if (name == null || name.trim().isEmpty) {
      final nameM =
          RegExp(r'(?:of|for)\s+([a-zA-Z\u0900-\u097F][\w\u0900-\u097F\s]+?)(?:\s+at|\s+@|\s+\d|,|$)',
                  caseSensitive: false)
              .firstMatch(lower) ??
          RegExp(r'^([a-zA-Z\u0900-\u097F][\w\u0900-\u097F\s]+?)(?:\s*[\d,]|$)')
              .firstMatch(lower);
      if (nameM != null) name = _capitalize(nameM.group(1)!.trim());
    }

    if (qty == null && price == null && gstRate == null) return null;
    return ChatLineItemDraft(
      name: name?.isEmpty == true ? null : name,
      quantity: qty,
      unitPrice: price,
      gstRate: gstRate,
    );
  }

  bool _looksLikeFullInvoice(String input) {
    final l = input.toLowerCase();
    // Must express intent to create an invoice
    if (!l.contains('invoice') && !l.contains('create') &&
        !l.contains('बनाओ') && !l.contains('बनाएं') && !l.contains('बनाना')) {
      return false;
    }
    // Must have "for" indicating customer
    if (!l.contains('for') && !l.contains('के लिए')) return false;
    // Must have something that looks like an item (qty OR item name after for)
    return RegExp(r'\d').hasMatch(l) ||
        l.contains(' kg') || l.contains(' gm') ||
        l.contains(' ltr') || l.contains(' pcs') ||
        l.contains(' किलो') || l.contains(' लीटर');
  }

  ChatInvoiceDraft? _parseFullInvoice(String input) {
    final l = HindiNLP.convertDevanagariDigits(input).toLowerCase();

    // ── Extract customer name ─────────────────────────────────────────────────
    // Patterns: "for Shubham Bansal 1kg sugar" / "for shubham: 1kg sugar"
    final custM = RegExp(
      r'(?:for|के लिए)\s+([a-zA-Z\u0900-\u097F][a-zA-Z\u0900-\u097F\s.&]+?)'
      r'(?=\s*\d|\s*,|\s*:|\s*-|$)',
      caseSensitive: false,
    ).firstMatch(l);
    if (custM == null) return null;
    final customerName = _capitalize(custM.group(1)!.trim());

    // ── Extract item details from the text after the customer name ────────────
    final afterCust = l.substring(custM.end).trim();
    final qun = afterCust.isNotEmpty ? _parseQtyUnitName(afterCust) : null;

    // Try the whole input too (if item comes before "for" segment)
    final qunFull = _parseQtyUnitName(input);

    if (qun != null) {
      final draft = ChatInvoiceDraft(
        customerName: customerName,
        items: const [],
      );
      state = state.copyWith(
        draft: draft.copyWith(
          currentItem: ChatLineItemDraft(
            name: qun['name'] as String,
            quantity: qun['qty'] as double,
            unit: qun['unit'] as String,
          ),
        ),
        step: ChatStep.askItemPrice,
      );
      return draft; // signal that we handled it
    }

    // No qty/unit found — use tryParse for price-based full parse
    final item = _tryParseItemInOneLine(input);
    if (item != null && item.isComplete) {
      return ChatInvoiceDraft(customerName: customerName, items: [item.toLineItem()]);
    }

    // Partial: only customer found — jump to item step with customer pre-filled
    state = state.copyWith(
      draft: state.draft.copyWith(customerName: customerName),
      step: ChatStep.askItemName,
    );
    return ChatInvoiceDraft(customerName: customerName, items: const []);
  }

  Future<void> _handleFullParse(ChatInvoiceDraft parsed) async {
    // If state was already mutated by _parseFullInvoice (partial parse), just
    // send the appropriate next question.
    if (state.step == ChatStep.askItemPrice) {
      final item = state.draft.currentItem;
      _addBotMessage(
        _s.qtySavedAskPrice(item.quantity ?? 1, item.unit ?? 'Nos'),
        replies: [],
      );
      return;
    }
    if (state.step == ChatStep.askItemName) {
      final name = parsed.customerName ?? 'Customer';
      _addBotMessage(
        _s.customerFoundAskItem(name, null, null,
            hasCatalog: _catalogItems.isNotEmpty),
        replies: _itemQuickReplies(),
      );
      return;
    }
    // Full parse with items → show summary
    state = state.copyWith(draft: parsed, step: ChatStep.showSummary);
    _showSummary();
  }

  // ─── Validators ──────────────────────────────────────────────────────────────

  bool _isValidGstin(String gstin) =>
      RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$')
          .hasMatch(gstin) && gstin.length == 15;

  // ─── Message Helpers ─────────────────────────────────────────────────────────

  void _addBotMessage(String text, {List<String> replies = const []}) {
    state = state.copyWith(
      messages: [_botMessage(text), ...state.messages],
      isBotTyping: false,
      dynamicQuickReplies: replies,
    );
  }

  types.TextMessage _botMessage(String text) => types.TextMessage(
      author: chatBot, id: _uuid.v4(), text: text,
      createdAt: DateTime.now().millisecondsSinceEpoch);

  types.TextMessage _userMessage(String text) => types.TextMessage(
      author: chatUser, id: _uuid.v4(), text: text,
      createdAt: DateTime.now().millisecondsSinceEpoch);

  String _capitalize(String s) => s.split(' ')
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

  String _normalizeUnit(String raw) {
    switch (raw.toLowerCase()) {
      case 'kg': case 'kgs': return 'Kg';
      case 'litre': case 'litres': case 'ltr': return 'Ltr';
      case 'pcs': case 'pieces': case 'piece': return 'Pcs';
      case 'box': case 'boxes': return 'Box';
      case 'bag': case 'bags': return 'Bag';
      case 'hour': case 'hours': case 'hr': case 'hrs': return 'Hr';
      default: return 'Nos';
    }
  }
}

