import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/local_storage.dart';

class FeatureSettings {
  final bool showStaff;
  final bool showCustomers;
  final bool showPurchases;
  final bool showGstReports;
  final bool showExpenses;
  final bool showItems;

  const FeatureSettings({
    this.showStaff = true,
    this.showCustomers = true,
    this.showPurchases = true,
    this.showGstReports = true,
    this.showExpenses = true,
    this.showItems = true,
  });

  FeatureSettings copyWith({
    bool? showStaff,
    bool? showCustomers,
    bool? showPurchases,
    bool? showGstReports,
    bool? showExpenses,
    bool? showItems,
  }) =>
      FeatureSettings(
        showStaff: showStaff ?? this.showStaff,
        showCustomers: showCustomers ?? this.showCustomers,
        showPurchases: showPurchases ?? this.showPurchases,
        showGstReports: showGstReports ?? this.showGstReports,
        showExpenses: showExpenses ?? this.showExpenses,
        showItems: showItems ?? this.showItems,
      );

  Map<String, dynamic> toMap() => {
        'feature_showStaff': showStaff,
        'feature_showCustomers': showCustomers,
        'feature_showPurchases': showPurchases,
        'feature_showGstReports': showGstReports,
        'feature_showExpenses': showExpenses,
        'feature_showItems': showItems,
      };

  factory FeatureSettings.fromBox() {
    final box = LocalStorage.settingsBox;
    return FeatureSettings(
      showStaff: box.get('feature_showStaff', defaultValue: true) as bool,
      showCustomers: box.get('feature_showCustomers', defaultValue: true) as bool,
      showPurchases: box.get('feature_showPurchases', defaultValue: true) as bool,
      showGstReports: box.get('feature_showGstReports', defaultValue: true) as bool,
      showExpenses: box.get('feature_showExpenses', defaultValue: true) as bool,
      showItems: box.get('feature_showItems', defaultValue: true) as bool,
    );
  }
}

class FeatureSettingsNotifier extends Notifier<FeatureSettings> {
  @override
  FeatureSettings build() => FeatureSettings.fromBox();

  Future<void> save(FeatureSettings settings) async {
    final box = LocalStorage.settingsBox;
    await box.put('feature_showStaff', settings.showStaff);
    await box.put('feature_showCustomers', settings.showCustomers);
    await box.put('feature_showPurchases', settings.showPurchases);
    await box.put('feature_showGstReports', settings.showGstReports);
    await box.put('feature_showExpenses', settings.showExpenses);
    await box.put('feature_showItems', settings.showItems);
    state = settings;
  }
}

final featureSettingsProvider =
    NotifierProvider<FeatureSettingsNotifier, FeatureSettings>(
  FeatureSettingsNotifier.new,
);
