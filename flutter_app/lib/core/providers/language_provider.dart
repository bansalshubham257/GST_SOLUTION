// lib/core/providers/language_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/local_storage.dart';

/// Supported app languages for chat + voice + UI.
enum AppLanguage {
  english('en-IN', 'EN', 'English'),
  hindi('hi-IN', 'हि', 'हिंदी');

  const AppLanguage(this.locale, this.shortLabel, this.label);
  final String locale;
  final String shortLabel;
  final String label;

  static AppLanguage fromLocale(String locale) {
    return AppLanguage.values.firstWhere(
      (l) => l.locale == locale,
      orElse: () => AppLanguage.english,
    );
  }
}

/// Persistent language preference.
final appLanguageProvider = StateNotifierProvider<AppLanguageNotifier, AppLanguage>(
  (ref) => AppLanguageNotifier(),
);

class AppLanguageNotifier extends StateNotifier<AppLanguage> {
  AppLanguageNotifier() : super(AppLanguage.fromLocale(LocalStorage.getLanguage()));

  void setLanguage(AppLanguage lang) {
    if (lang == state) return;
    state = lang;
    LocalStorage.setLanguage(lang.locale);
  }
}
