import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/local_storage.dart';

enum BackupFrequency { manual, hourly, daily, weekly, monthly }

extension BackupFrequencyLabel on BackupFrequency {
  String get label {
    switch (this) {
      case BackupFrequency.manual: return 'Manual Only';
      case BackupFrequency.hourly: return 'Every Hour';
      case BackupFrequency.daily: return 'Daily';
      case BackupFrequency.weekly: return 'Weekly';
      case BackupFrequency.monthly: return 'Monthly';
    }
  }
}

class BackupSettings {
  final BackupFrequency frequency;
  final DateTime? lastBackupAt;

  const BackupSettings({
    this.frequency = BackupFrequency.manual,
    this.lastBackupAt,
  });

  BackupSettings copyWith({
    BackupFrequency? frequency,
    DateTime? lastBackupAt,
    bool clearLastBackup = false,
  }) =>
      BackupSettings(
        frequency: frequency ?? this.frequency,
        lastBackupAt: clearLastBackup ? null : (lastBackupAt ?? this.lastBackupAt),
      );

  Duration get interval {
    switch (frequency) {
      case BackupFrequency.manual: return Duration.zero;
      case BackupFrequency.hourly: return const Duration(hours: 1);
      case BackupFrequency.daily: return const Duration(days: 1);
      case BackupFrequency.weekly: return const Duration(days: 7);
      case BackupFrequency.monthly: return const Duration(days: 30);
    }
  }

  bool get isDue {
    if (frequency == BackupFrequency.manual) return false;
    if (lastBackupAt == null) return true;
    return DateTime.now().difference(lastBackupAt!) >= interval;
  }

  Map<String, dynamic> toMap() => {
        'backup_frequency': frequency.name,
        'backup_last_at': lastBackupAt?.toIso8601String(),
      };

  factory BackupSettings.fromBox() {
    final box = LocalStorage.settingsBox;
    final freqStr = box.get('backup_frequency', defaultValue: 'manual') as String;
    final lastAtStr = box.get('backup_last_at') as String?;
    return BackupSettings(
      frequency: BackupFrequency.values.firstWhere(
        (f) => f.name == freqStr,
        orElse: () => BackupFrequency.manual,
      ),
      lastBackupAt: lastAtStr != null ? DateTime.tryParse(lastAtStr) : null,
    );
  }
}

final backupSettingsProvider =
    NotifierProvider<BackupSettingsNotifier, BackupSettings>(
  BackupSettingsNotifier.new,
);

class BackupSettingsNotifier extends Notifier<BackupSettings> {
  @override
  BackupSettings build() => BackupSettings.fromBox();

  Future<void> updateFrequency(BackupFrequency frequency) async {
    final updated = state.copyWith(frequency: frequency);
    await _persist(updated);
  }

  Future<void> markBackupDone() async {
    final updated = state.copyWith(lastBackupAt: DateTime.now());
    await _persist(updated);
  }

  Future<void> _persist(BackupSettings settings) async {
    final box = LocalStorage.settingsBox;
    await box.put('backup_frequency', settings.frequency.name);
    if (settings.lastBackupAt != null) {
      await box.put('backup_last_at', settings.lastBackupAt!.toIso8601String());
    } else {
      await box.delete('backup_last_at');
    }
    state = settings;
  }
}
