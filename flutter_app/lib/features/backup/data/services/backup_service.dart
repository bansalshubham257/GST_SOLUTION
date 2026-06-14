import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart' show Share, XFile;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/local_storage.dart';

class BackupService {
  BackupService._();

  static const _version = 1;

  static Map<String, Box> _allBoxes() => {
        AppConstants.invoiceBox: LocalStorage.invoiceBox,
        AppConstants.customerBox: LocalStorage.customerBox,
        AppConstants.businessBox: LocalStorage.businessBox,
        AppConstants.userBox: LocalStorage.userBox,
        AppConstants.settingsBox: LocalStorage.settingsBox,
        AppConstants.draftBox: LocalStorage.draftBox,
        AppConstants.itemCatalogBox: LocalStorage.itemCatalogBox,
        AppConstants.staffBox: LocalStorage.staffBox,
        AppConstants.expenseBox: LocalStorage.expenseBox,
        AppConstants.expenseCategoryBox: LocalStorage.expenseCategoryBox,
        AppConstants.purchaseBox: LocalStorage.purchaseBox,
      };

  /// Export all local data to a JSON file and share it via the system share sheet.
  static Future<void> exportAndShare() async {
    final file = await _writeBackupFile();
    if (file == null) return;
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'GST Solution Backup',
      text: 'GST Solution data backup — ${DateTime.now().toIso8601String().split('T').first}',
    );
  }

  /// Let the user pick a backup file and restore data from it.
  static Future<bool> importFromPicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: false,
      withReadStream: false,
    );
    if (result == null || result.files.isEmpty) return false;
    final file = File(result.files.single.path!);
    if (!await file.exists()) return false;
    return _restore(file);
  }

  /// Write backup file to temp directory.
  static Future<File?> _writeBackupFile() async {
    try {
      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
      final file = File('${dir.path}/GST_Solution_Backup_$timestamp.json');

      final data = <String, dynamic>{};
      for (final entry in _allBoxes().entries) {
        final box = entry.value;
        final boxData = <String, dynamic>{};
        for (final key in box.keys) {
          boxData[key.toString()] = box.get(key);
        }
        data[entry.key] = boxData;
      }

      final payload = {
        'version': _version,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'data': data,
      };

      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
      return file;
    } catch (_) {
      return null;
    }
  }

  /// Restore data from a backup file.
  static Future<bool> _restore(File file) async {
    try {
      final content = await file.readAsString();
      final payload = jsonDecode(content) as Map<String, dynamic>;
      final data = payload['data'] as Map<String, dynamic>;

      // Clear all existing data first
      await LocalStorage.clearAll();

      // Write data back box by box
      for (final entry in _allBoxes().entries) {
        final boxData = data[entry.key] as Map<String, dynamic>?;
        if (boxData == null) continue;
        final box = entry.value;
        for (final key in boxData.keys) {
          await box.put(key, boxData[key]);
        }
      }

      return true;
    } catch (_) {
      return false;
    }
  }
}
