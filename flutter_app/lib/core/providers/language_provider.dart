// lib/core/providers/language_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Supported app languages for chat + voice.
enum AppLanguage {
  english('en-IN', 'EN', 'English'),
  hindi('hi-IN', 'हि', 'हिंदी');

  const AppLanguage(this.locale, this.shortLabel, this.label);
  final String locale;   // BCP-47 locale for voice recognition
  final String shortLabel; // shown in toggle button
  final String label;
}

/// Global language preference — persists for the session.
final appLanguageProvider = StateProvider<AppLanguage>(
  (ref) => AppLanguage.english,
);

