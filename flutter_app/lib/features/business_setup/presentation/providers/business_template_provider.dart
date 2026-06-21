import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/local_storage.dart';
import '../../../settings/presentation/providers/feature_settings_provider.dart';
import '../../../invoice/presentation/providers/invoice_settings_provider.dart';
import '../../../chat_flow/presentation/providers/sale_settings_provider.dart';
import '../../../invoice/presentation/providers/item_settings_provider.dart';
import '../../data/models/business_template.dart';

final businessTemplateProvider =
    StateNotifierProvider<BusinessTemplateNotifier, BusinessTemplate>((ref) {
  return BusinessTemplateNotifier();
});

class BusinessTemplateNotifier extends StateNotifier<BusinessTemplate> {
  BusinessTemplateNotifier() : super(_load());

  static BusinessTemplate _load() {
    final saved = LocalStorage.settingsBox.get('business_template', defaultValue: 'custom') as String;
    return BusinessTemplate.values.firstWhere(
      (t) => t.id == saved,
      orElse: () => BusinessTemplate.custom,
    );
  }

  Future<void> select(BusinessTemplate template, WidgetRef ref) async {
    state = template;
    await LocalStorage.settingsBox.put('business_template', template.id);

    if (template == BusinessTemplate.custom) return;

    // Apply presets to all settings
    await ref.read(featureSettingsProvider.notifier).save(template.featurePreset);
    await ref.read(saleSettingsProvider.notifier).save(template.salePreset);
    await ref.read(invoiceSettingsProvider.notifier).save(template.invoicePreset);
    await ref.read(itemSettingsProvider.notifier).save(template.itemPreset);
  }
}
