import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/local_storage.dart';

class InvoiceSettings {
  final String prefix;
  final String defaultTerms;
  final String signatureText;
  final String templateStyle;

  const InvoiceSettings({
    this.prefix = 'INV',
    this.defaultTerms = '',
    this.signatureText = 'This is a computer-generated invoice and does not require a signature.',
    this.templateStyle = 'classic',
  });

  InvoiceSettings copyWith({
    String? prefix,
    String? defaultTerms,
    String? signatureText,
    String? templateStyle,
  }) {
    return InvoiceSettings(
      prefix: prefix ?? this.prefix,
      defaultTerms: defaultTerms ?? this.defaultTerms,
      signatureText: signatureText ?? this.signatureText,
      templateStyle: templateStyle ?? this.templateStyle,
    );
  }

  Map<String, dynamic> toMap() => {
        'invoice_prefix': prefix,
        'invoice_terms': defaultTerms,
        'invoice_signature': signatureText,
        'invoice_template': templateStyle,
      };

  factory InvoiceSettings.fromBox() {
    final box = LocalStorage.settingsBox;
    return InvoiceSettings(
      prefix: box.get('invoice_prefix', defaultValue: 'INV') as String,
      defaultTerms: box.get('invoice_terms', defaultValue: '') as String,
      signatureText: box.get('invoice_signature',
              defaultValue:
                  'This is a computer-generated invoice and does not require a signature.')
          as String,
      templateStyle: box.get('invoice_template', defaultValue: 'classic') as String,
    );
  }
}

class InvoiceSettingsNotifier extends Notifier<InvoiceSettings> {
  @override
  InvoiceSettings build() => InvoiceSettings.fromBox();

  Future<void> save(InvoiceSettings settings) async {
    final box = LocalStorage.settingsBox;
    await box.put('invoice_prefix', settings.prefix);
    await box.put('invoice_terms', settings.defaultTerms);
    await box.put('invoice_signature', settings.signatureText);
    await box.put('invoice_template', settings.templateStyle);
    state = settings;
  }
}

final invoiceSettingsProvider =
    NotifierProvider<InvoiceSettingsNotifier, InvoiceSettings>(
  InvoiceSettingsNotifier.new,
);
