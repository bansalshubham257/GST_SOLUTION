// lib/core/services/voice_input_service.dart
//
// Voice recognition via native platform channel (RecognizerIntent on Android).
// No third-party package needed — uses the device's built-in Google speech UI.

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Channel ─────────────────────────────────────────────────────────────────

const _channel = MethodChannel('com.gstsolution.gst_solution/voice');

// ─── Status ───────────────────────────────────────────────────────────────────

enum VoiceStatus { idle, listening, done, unavailable, error }

// ─── State ────────────────────────────────────────────────────────────────────

class VoiceInputState {
  final VoiceStatus status;
  final String transcript;
  final String? errorMessage;

  const VoiceInputState({
    this.status = VoiceStatus.idle,
    this.transcript = '',
    this.errorMessage,
  });

  bool get isListening => status == VoiceStatus.listening;
  bool get isInitializing => false;
  bool get hasError => status == VoiceStatus.error;
  bool get isDone => status == VoiceStatus.done;
  bool get isUnavailable => status == VoiceStatus.unavailable;

  VoiceInputState copyWith({
    VoiceStatus? status,
    String? transcript,
    String? errorMessage,
  }) =>
      VoiceInputState(
        status: status ?? this.status,
        transcript: transcript ?? this.transcript,
        errorMessage: errorMessage,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class VoiceInputNotifier extends StateNotifier<VoiceInputState> {
  VoiceInputNotifier() : super(const VoiceInputState());

  Future<void> startListening({
    String localeId = 'en_IN',
    String prompt = 'Speak now...',
    void Function(String transcript)? onPartial,
    void Function(String transcript)? onFinal,
  }) async {
    if (state.isListening) return;
    state = const VoiceInputState(status: VoiceStatus.listening);

    try {
      final result = await _channel.invokeMethod<String>(
        'startVoiceInput',
        {'prompt': prompt},
      );
      final text = (result ?? '').trim();
      state = VoiceInputState(status: VoiceStatus.done, transcript: text);
      onFinal?.call(text);
    } on PlatformException catch (e) {
      state = VoiceInputState(
        status: e.code == 'UNAVAILABLE'
            ? VoiceStatus.unavailable
            : VoiceStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      state = VoiceInputState(
          status: VoiceStatus.error, errorMessage: e.toString());
    }
  }

  Future<void> stopListening() async {
    if (state.isListening) state = state.copyWith(status: VoiceStatus.done);
  }

  void reset() => state = const VoiceInputState();
}

// ─── Provider ──────────────────────────────────────────────────────────────────

final voiceInputProvider =
    StateNotifierProvider.autoDispose<VoiceInputNotifier, VoiceInputState>(
  (ref) => VoiceInputNotifier(),
);

// ─── Voice Parsing Utils ──────────────────────────────────────────────────────

class VoiceParser {
  VoiceParser._();

  static ParsedItem parseItem(String text) {
    final lower = text.toLowerCase().trim();
    double? price;
    final pricePatterns = [
      RegExp(r'(?:₹|rs\.?|rupees?)\s*([\d,]+(?:\.\d{1,2})?)'),
      RegExp(r'(?:at|@|price\s*(?:is)?|worth)\s*([\d,]+(?:\.\d{1,2})?)'),
      RegExp(r'([\d,]+(?:\.\d{1,2})?)\s*(?:₹|rs\.?|rupees?)'),
    ];
    for (final p in pricePatterns) {
      final m = p.firstMatch(lower);
      if (m != null) {
        price = double.tryParse(m.group(1)!.replaceAll(',', ''));
        if (price != null) break;
      }
    }

    double? gstRate;
    final gstM = RegExp(r'(\d+)\s*(?:%|percent|gst)').firstMatch(lower);
    if (gstM != null) {
      final r = double.tryParse(gstM.group(1)!);
      const valid = [0.0, 5.0, 12.0, 18.0, 28.0];
      if (r != null && valid.contains(r)) gstRate = r;
    }

    String? unit;
    final unitM = RegExp(
            r'\b(kg|kgs|kilogram|litre|liter|ltr|pcs|piece|pieces|nos|units?|box|boxes|bag|bags|hour|hours|hr|hrs|meter|metres?|mtr|day|days|month|months)\b',
            caseSensitive: false)
        .firstMatch(lower);
    if (unitM != null) unit = _normalizeUnit(unitM.group(1)!);

    final isService = lower.contains('service') ||
        lower.contains('consulting') ||
        lower.contains('labour') ||
        lower.contains('labor') ||
        lower.contains('maintenance') ||
        lower.contains('repair') ||
        lower.contains('support');

    String? hsnCode;
    final hsnM =
        RegExp(r'(?:hsn|sac|code)\s*[:\-]?\s*(\d{6,8})').firstMatch(lower);
    if (hsnM != null) hsnCode = hsnM.group(1);

    final name = _extractName(text, [
      RegExp(r'\d+(?:\.\d+)?'),
      RegExp(
          r'\b(rupees?|rs\.?|percent|gst|at|per|unit|units?|kg|ltr|pcs|nos|box|bag|hr|meter|mtr|day|month|product|service|hsn|sac|code|price|is|worth|with|and|for)\b',
          caseSensitive: false),
    ]);

    return ParsedItem(
      name: name.isEmpty ? null : _capitalize(name),
      price: price,
      gstRate: gstRate,
      unit: unit,
      isService: isService,
      hsnCode: hsnCode,
    );
  }

  // Hindi field keywords supported:
  //   फोन / मोबाइल / नंबर / संपर्क  → phone
  //   ईमेल                           → email
  //   जीएसटी                         → gstin
  //   शहर                            → city
  static const _phoneKeywords =
      r'phone|mobile|mob|call|contact|number|no\.?|फोन|मोबाइल|नंबर|संपर्क';
  static const _allFieldKeywords =
      r'phone|mobile|mob|call|contact|email|mail|gstin|gst|city|pincode|'
      r'address|pin|number|no\.|from|located|'
      r'फोन|मोबाइल|नंबर|संपर्क|ईमेल|जीएसटी|शहर';

  static ParsedCustomer parseCustomer(String text) {
    final lower = text.toLowerCase().trim();

    // ── Phone ── (English + Hindi keywords)
    String? phone;
    final phoneM = RegExp(
      '(?:$_phoneKeywords)\\s*[:\\-]?\\s*(\\d[\\d\\s\\-]{8,13}\\d)',
      caseSensitive: false,
    ).firstMatch(lower);
    if (phoneM != null) {
      phone = phoneM.group(1)!.replaceAll(RegExp(r'[\s\-]'), '');
      if (phone.length > 10) phone = phone.substring(phone.length - 10);
    } else {
      // Fallback: bare 10-digit number
      phone = RegExp(r'\b(\d{10})\b').firstMatch(lower)?.group(1);
    }

    // ── Email ── (English + Hindi keyword)
    String? email;
    final emailM = RegExp(
      r'(?:email|mail|e-mail|ईमेल)\s*[:\-]?\s*'
      r'([a-z0-9._]+(?:\s+at\s+|\s*@\s*)(?:[a-z0-9]+(?:\s+dot\s+|\.)[a-z]{2,})+)',
      caseSensitive: false,
    ).firstMatch(lower);
    if (emailM != null) {
      email = emailM
          .group(1)!
          .replaceAll(' at ', '@')
          .replaceAll(' dot ', '.')
          .replaceAll(' ', '');
    }

    // ── GSTIN ── (English + Hindi keyword)
    String? gstin;
    final gstinM = RegExp(
      r'(?:gstin|gst\s+(?:number|no\.?)?|जीएसटी)\s*[:\-]?\s*([A-Z0-9]{15})',
      caseSensitive: false,
    ).firstMatch(text);
    if (gstinM != null) gstin = gstinM.group(1)!.toUpperCase();

    // ── City ── (English + Hindi keyword)
    String? city;
    final cityM = RegExp(
      r'(?:city|from|located\s+in|lives?\s+in|शहर)\s+([^\d\n]+?)'
      r'(?=\s*(?:phone|mobile|email|gstin|gst|pincode|pin|फोन|मोबाइल|ईमेल|जीएसटी|\d{5,})|$)',
      caseSensitive: false,
    ).firstMatch(lower);
    if (cityM != null) city = _smartCapitalize(cityM.group(1)!.trim());

    // ── Pincode ──
    final pincode = RegExp(r'\b(\d{6})\b').firstMatch(lower)?.group(1);

    // ── Name: position-based extraction ──────────────────────────────────────
    // Everything before the first recognised field keyword is the name.
    // e.g. "राहुल शर्मा फोन 9876543210"  →  name = "राहुल शर्मा"
    //      "Rahul Sharma phone 9876543210" →  name = "Rahul Sharma"
    final kwMatch = RegExp(
      _allFieldKeywords,
      caseSensitive: false,
    ).firstMatch(lower);

    String name;
    if (kwMatch != null) {
      // Name = text before the keyword position (use original case)
      name = text.substring(0, kwMatch.start).trim();
      // Strip stray punctuation
      name = name.replaceAll(RegExp(r'[,:;.!?@#\$%^&*()\[\]{}<>]'), '').trim();
    } else {
      // Fallback: strip digits and known English field words
      name = _extractName(
        text,
        [
          RegExp(
            r'\b(phone|mobile|email|gstin|gst|city|pincode|address|pin|no\.?|number|from|located)\b',
            caseSensitive: false,
          ),
          RegExp(r'\d+'),
        ],
        maxWords: 5,
      );
    }

    return ParsedCustomer(
      name: name.isEmpty ? null : _smartCapitalize(name),
      phone: phone,
      email: email,
      gstin: gstin,
      city: city,
      pincode: pincode,
    );
  }

  static String _extractName(String text, List<RegExp> excludePatterns,
      {int maxWords = 6}) {
    String cleaned = text;
    for (final p in excludePatterns) {
      cleaned = cleaned.replaceAll(p, ' ');
    }
    return cleaned
        .split(RegExp(r'\s+'))
        .map((w) => w.trim())
        .where((w) => w.isNotEmpty && w.length > 1)
        .take(maxWords)
        .join(' ')
        .trim();
  }

  /// Capitalises English words; leaves Devanagari/Hindi words unchanged
  /// (they have no concept of case).
  static String _smartCapitalize(String s) {
    return s.split(' ').map((w) {
      if (w.isEmpty) return '';
      // Word contains at least one ASCII letter → treat as English
      if (RegExp(r'[a-zA-Z]').hasMatch(w)) {
        return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
      }
      // Hindi/Devanagari or other scripts — keep as-is
      return w;
    }).join(' ');
  }

  // Keep the old helper so nothing else breaks
  static String _capitalize(String s) => _smartCapitalize(s);

  static String _normalizeUnit(String raw) {
    switch (raw.toLowerCase()) {
      case 'kg':
      case 'kgs':
      case 'kilogram':
        return 'Kg';
      case 'litre':
      case 'liter':
      case 'ltr':
        return 'Ltr';
      case 'pcs':
      case 'piece':
      case 'pieces':
        return 'Pcs';
      case 'box':
      case 'boxes':
        return 'Box';
      case 'bag':
      case 'bags':
        return 'Bag';
      case 'hour':
      case 'hours':
      case 'hr':
      case 'hrs':
        return 'Hr';
      case 'meter':
      case 'metres':
      case 'metre':
      case 'mtr':
        return 'Mtr';
      case 'day':
      case 'days':
        return 'Day';
      case 'month':
      case 'months':
        return 'Month';
      default:
        return 'Nos';
    }
  }
}

// ─── Parsed Data Models ───────────────────────────────────────────────────────

class ParsedItem {
  final String? name;
  final double? price;
  final double? gstRate;
  final String? unit;
  final bool isService;
  final String? hsnCode;

  const ParsedItem({
    this.name,
    this.price,
    this.gstRate,
    this.unit,
    this.isService = false,
    this.hsnCode,
  });

  bool get hasAnyData =>
      name != null || price != null || gstRate != null || unit != null;
}

class ParsedCustomer {
  final String? name;
  final String? phone;
  final String? email;
  final String? gstin;
  final String? city;
  final String? pincode;

  const ParsedCustomer({
    this.name,
    this.phone,
    this.email,
    this.gstin,
    this.city,
    this.pincode,
  });

  bool get hasAnyData =>
      name != null ||
      phone != null ||
      email != null ||
      gstin != null ||
      city != null ||
      pincode != null;
}
