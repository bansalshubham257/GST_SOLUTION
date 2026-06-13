// lib/core/services/tts_service.dart
//
// Text-to-Speech service for voice conversation mode.
// Uses flutter_tts; strips markdown/emojis before speaking.
// Uses a Completer+timeout so speak() reliably awaits completion on Android.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _speaking = false;

  bool get isSpeaking => _speaking;

  // ─── Init ────────────────────────────────────────────────────────────────────

  Future<void> _ensureInit() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _tts.setSharedInstance(true); // iOS audio session sharing
    } catch (_) {}
  }

  // ─── Public API ──────────────────────────────────────────────────────────────

  /// Speak [text] in [locale] (e.g. 'en-IN' or 'hi-IN').
  /// Awaits until speech fully completes or times out (15 s).
  Future<void> speak(
    String text, {
    String locale = 'en-IN',
    double rate = 0.48,
  }) async {
    await _ensureInit();

    final cleaned = _clean(text, locale);
    if (cleaned.trim().isEmpty) return;

    try {
      await _tts.stop();

      // Configure language — fall back to en-IN if locale unavailable
      final langResult = await _tts.setLanguage(locale);
      if (langResult != 1) {
        await _tts.setLanguage('en-IN');
      }
      await _tts.setSpeechRate(rate);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      // Use a Completer so we reliably await completion on all Android versions.
      final completer = Completer<void>();

      _tts.setCompletionHandler(() {
        _speaking = false;
        if (!completer.isCompleted) completer.complete();
      });
      _tts.setErrorHandler((msg) {
        _speaking = false;
        debugPrint('TtsService error: $msg');
        if (!completer.isCompleted) completer.complete(); // continue, don't throw
      });
      _tts.setCancelHandler(() {
        _speaking = false;
        if (!completer.isCompleted) completer.complete();
      });

      _speaking = true;
      await _tts.speak(cleaned);

      // Wait for speech to finish, with a safety timeout
      await completer.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          _speaking = false;
          debugPrint('TtsService: speak() timed out');
        },
      );
    } catch (e) {
      debugPrint('TtsService.speak() error: $e');
    } finally {
      _speaking = false;
    }
  }

  /// Stop any in-progress speech immediately.
  Future<void> stop() async {
    if (!_initialized) return;
    try {
      await _tts.stop();
    } catch (_) {}
    _speaking = false;
  }

  // ─── Text Cleaning ───────────────────────────────────────────────────────────

  /// Strips markdown, emojis and symbols so TTS reads naturally.
  static String _clean(String text, String locale) {
    var s = text;

    // Markdown bold → plain
    s = s.replaceAllMapped(
        RegExp(r'\*\*(.+?)\*\*', dotAll: true), (m) => m.group(1) ?? '');
    // Markdown italic → plain
    s = s.replaceAllMapped(
        RegExp(r'\*(.+?)\*', dotAll: true), (m) => m.group(1) ?? '');
    s = s.replaceAllMapped(
        RegExp(r'_(.+?)_', dotAll: true), (m) => m.group(1) ?? '');

    // ₹ → spoken currency word
    s = s.replaceAll(
        '₹', locale.startsWith('hi') ? ' रुपये ' : ' rupees ');

    // Separator lines like ━━━━━
    s = s.replaceAll(RegExp(r'━+'), '. ');

    // Backtick code
    s = s.replaceAll(RegExp(r'`+'), '');

    // Strip emojis & non-speakable symbols
    s = s.replaceAll(
      RegExp(
        r'[\u{1F000}-\u{1FFFF}]'
        r'|[\u{2600}-\u{27BF}]'
        r'|[\u{2300}-\u{23FF}]'
        r'|[\u{FE00}-\u{FEFF}]'
        r'|[\u{1F300}-\u{1F9FF}]',
        unicode: true,
      ),
      ' ',
    );

    // Keep only printable ASCII + Devanagari + basic Latin extended
    s = s.replaceAll(
      RegExp(
        r'[^\x09\x0A\x0D\x20-\x7E'
        r'\u0900-\u097F'
        r'\u00A0-\u00FF'
        r']',
      ),
      ' ',
    );

    // Collapse whitespace
    s = s.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    return s;
  }
}



