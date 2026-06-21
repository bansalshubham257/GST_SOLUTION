// lib/core/services/voice_input_service.dart
//
// Voice input service (Android SpeechRecognizer via MethodChannel)
// + VoiceInputProvider state management
// + VoiceParser for extracting structured data from speech

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/chat_strings.dart' show HindiNLP;
import '../../core/providers/language_provider.dart';

// ═══════════════════════════════════════════════════════════════════
// MethodChannel service — wraps Android SpeechRecognizer
// ═══════════════════════════════════════════════════════════════════

class VoiceInputService {
  static const _channel = MethodChannel('gst_solution/voice_input');
  static bool _isListening = false;
  static bool get isListening => _isListening;

  static Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> startListening({
    required Function(String text) onResult,
    String locale = 'en-IN',
  }) async {
    if (_isListening) return;
    _isListening = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onResult') {
        final text = call.arguments as String?;
        if (text != null && text.isNotEmpty) onResult(text);
      }
    });
    try {
      final status = await _channel.invokeMethod<String>('startListening', {'locale': locale});
      if (status != 'READY') _isListening = false;
    } catch (_) {
      _isListening = false;
      rethrow;
    }
  }

  static Future<void> stopListening() async {
    if (!_isListening) return;
    _isListening = false;
    try {
      await _channel.invokeMethod<void>('stopListening');
    } catch (_) {}
    _channel.setMethodCallHandler(null);
  }
}

// ═══════════════════════════════════════════════════════════════════
// Voice Input Provider — manages listening lifecycle + transcript
// ═══════════════════════════════════════════════════════════════════

class VoiceInputState {
  final bool isListening;
  final bool isInitializing;
  final bool isDone;
  final String transcript;

  const VoiceInputState({
    this.isListening = false,
    this.isInitializing = false,
    this.isDone = false,
    this.transcript = '',
  });

  VoiceInputState copyWith({
    bool? isListening,
    bool? isInitializing,
    bool? isDone,
    String? transcript,
  }) =>
      VoiceInputState(
        isListening: isListening ?? this.isListening,
        isInitializing: isInitializing ?? this.isInitializing,
        isDone: isDone ?? this.isDone,
        transcript: transcript ?? this.transcript,
      );
}

class VoiceInputNotifier extends StateNotifier<VoiceInputState> {
  VoiceInputNotifier() : super(const VoiceInputState());

  void startListening({
    required String localeId,
    String? prompt,
    required Function(String) onFinal,
  }) async {
    final available = await VoiceInputService.isAvailable();
    if (!available) return;

    state = state.copyWith(isInitializing: true);
    await Future.delayed(const Duration(milliseconds: 300)); // show spinner briefly
    state = state.copyWith(isInitializing: false, isListening: true, isDone: false, transcript: '');

    try {
      await VoiceInputService.startListening(
        locale: localeId,
        onResult: (text) {
          if (text.isNotEmpty) {
            state = state.copyWith(transcript: text, isListening: false, isDone: true);
            onFinal(text);
          }
        },
      );
    } catch (_) {
      state = state.copyWith(isListening: false, isDone: true);
    }
  }

  void stopListening() {
    VoiceInputService.stopListening();
    state = state.copyWith(isListening: false, isDone: true);
  }

  void reset() {
    VoiceInputService.stopListening();
    state = const VoiceInputState();
  }
}

final voiceInputProvider = StateNotifierProvider<VoiceInputNotifier, VoiceInputState>((ref) {
  return VoiceInputNotifier();
});

// ═══════════════════════════════════════════════════════════════════
// Parsed Models
// ═══════════════════════════════════════════════════════════════════

class ParsedItem {
  final String? name;
  final double? price;
  final double? gstRate;
  final String? unit;
  final String? hsnCode;
  final bool isService;

  bool get hasAnyData =>
      name != null || price != null || gstRate != null || unit != null;

  ParsedItem({
    this.name,
    this.price,
    this.gstRate,
    this.unit,
    this.hsnCode,
    this.isService = false,
  });
}

class ParsedCustomer {
  final String? name;
  final String? phone;
  final String? email;
  final String? gstin;
  final String? city;
  final String? pincode;

  bool get hasAnyData => name != null || phone != null || email != null || gstin != null;

  ParsedCustomer({
    this.name,
    this.phone,
    this.email,
    this.gstin,
    this.city,
    this.pincode,
  });
}

// ═══════════════════════════════════════════════════════════════════
// Voice Parser — extract structured data from transcribed text
// ═══════════════════════════════════════════════════════════════════

class VoiceParser {
  VoiceParser._();

  static ParsedItem? parseItem(String text) {
    if (text.trim().isEmpty) return null;
    final t = HindiNLP.convertDevanagariDigits(text.trim());

    final lower = t.toLowerCase();

    // Detect service keywords
    final isService = lower.contains('service') ||
        lower.contains('सेवा') ||
        lower.contains('consult') ||
        lower.contains('परामर्श') ||
        lower.contains('design') ||
        lower.contains('डिज़ाइन') ||
        lower.contains('develop') ||
        lower.contains('डेवलप');

    // Extract GST rate
    final gstRate = HindiNLP.extractGstRate(t);

    // Extract price — find the first amount after a currency marker
    double? price;
    final pricePatterns = [
      RegExp(r'(?:₹|rupees?|रु|rs\.?|रुपये|price|कीमत)\s*([\d,]+\.?\d*)', caseSensitive: false),
      RegExp(r'(\d[\d,]*\.?\d*)\s*(?:₹|rupees?|रु|rs\.?|रुपये)', caseSensitive: false),
    ];
    for (final pat in pricePatterns) {
      final m = pat.firstMatch(t);
      if (m != null) {
        price = double.tryParse(m.group(1)!.replaceAll(',', ''));
        if (price != null) break;
      }
    }
    // Fallback: last number in text (not GST)
    if (price == null) {
      final allNums = RegExp(r'([\d,]+\.?\d*)').allMatches(t.replaceAll(',', '')).toList();
      if (allNums.length >= 2) {
        // If we have GST, the other number is price
        price = double.tryParse(allNums.last.group(1)!);
        if (gstRate != null && allNums.length >= 3) {
          price = double.tryParse(allNums[allNums.length - 2].group(1)!);
        } else if (gstRate != null) {
          price = double.tryParse(allNums.first.group(1)!);
        }
      } else if (allNums.isNotEmpty) {
        price = double.tryParse(allNums.first.group(1)!);
      }
    }

    // Extract unit
    final unit = HindiNLP.extractUnit(t);

    // Extract name — everything not a number/price/gst/unit
    String? name;
    final cleaned = t
        .replaceAll(RegExp(r'₹|rupees?|रु|rs\.?|रुपये|प्रति|per|at|@', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\d,]+\.?\d*\s*%?'), '')
        .replaceAll(RegExp(r'(?:gst|जीएसटी|प्रतिशत|percent|फीसदी)\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'(?:किलो|लीटर|नग|पीस|nos|pcs|box|bag|kg|ltr|mtr|hrs?)\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isNotEmpty && cleaned.length > 1) {
      name = cleaned.split(' ').where((w) => w.length > 1).join(' ');
      if (name.isEmpty) name = cleaned;
    }

    return ParsedItem(
      name: name,
      price: price,
      gstRate: gstRate,
      unit: unit ?? (name?.contains('service') == true || (name?.contains('consult') == true) ? 'Hr' : 'Pcs'),
      isService: isService,
    );
  }

  static ParsedCustomer? parseCustomer(String text) {
    if (text.trim().isEmpty) return null;
    final t = HindiNLP.convertDevanagariDigits(text.trim());
    final lower = t.toLowerCase();

    // Extract phone (10-digit)
    String? phone;
    final phoneM = RegExp(r'\b(\d{10})\b').firstMatch(t);
    if (phoneM != null) phone = phoneM.group(1);

    // Extract email
    String? email;
    final emailM = RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+').firstMatch(t);
    if (emailM != null) email = emailM.group(0);

    // Extract GSTIN (15 chars: 2 digits + 10 chars + 3 digits)
    String? gstin;
    final gstinM = RegExp(r'\b(\d{2}[A-Za-z0-9]{10}\d{3})\b').firstMatch(t);
    if (gstinM != null) gstin = gstinM.group(0)?.toUpperCase();

    // Extract city / pincode
    String? city;
    final cityM = RegExp(r'(?:city|शहर|in|at)\s+([A-Za-z\u0900-\u097F\s]+?)(?:\s+\d|$)', caseSensitive: false).firstMatch(t);
    if (cityM != null) city = cityM.group(1)?.trim();

    String? pincode;
    final pinM = RegExp(r'\b(\d{6})\b').firstMatch(t);
    if (pinM != null) {
      final pin = pinM.group(1)!;
      // avoid confusing phone with pincode
      if (phone == null || pin != phone) pincode = pin;
    }

    // Extract name — everything remaining
    String? name;
    var cleaned = t;
    if (phone != null) cleaned = cleaned.replaceFirst(phone, '');
    if (email != null) cleaned = cleaned.replaceFirst(email, '');
    if (gstin != null) cleaned = cleaned.replaceFirst(gstin, '');
    if (city != null) cleaned = cleaned.replaceFirst(city, '');
    if (pincode != null) cleaned = cleaned.replaceFirst(pincode, '');
    cleaned = cleaned
        .replaceAll(RegExp(r'phone|फोन|मोबाइल|email|ईमेल|gstin|city|शहर|pincode|पिनकोड|in|at', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isNotEmpty && cleaned.split(' ').any((w) => w.length > 1)) {
      name = cleaned;
    }

    return ParsedCustomer(
      name: name,
      phone: phone,
      email: email,
      gstin: gstin,
      city: city,
      pincode: pincode,
    );
  }
}
