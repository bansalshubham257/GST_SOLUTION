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
    final file = await _writeBackupFile(temp: true);
    if (file == null) return;
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'GST Solution Backup',
      text: 'GST Solution data backup — ${DateTime.now().toIso8601String().split('T').first}',
    );
  }

  /// Save backup to the public Downloads folder and return the file path.
  static Future<String?> saveLocalBackup() async {
    try {
      Directory? targetDir = await _getPublicDownloadsDir();
      if (targetDir == null) {
        final external = await getExternalStorageDirectory();
        if (external != null) targetDir = external;
      }
      if (targetDir != null) {
        if (!await targetDir.exists()) await targetDir.create(recursive: true);
        final file = await _writeBackupToDir(targetDir);
        if (file != null) {
          await _cleanOldBackups(targetDir);
          return file.path;
        }
      }
    } catch (_) {}
    // Final fallback to app documents directory
    final file = await _writeBackupFile(temp: false);
    if (file == null) return null;
    try { await _cleanOldBackups(file.parent); } catch (_) {}
    return file.path;
  }

  /// Resolve the public Downloads directory on Android.
  static Future<Directory?> _getPublicDownloadsDir() async {
    if (!Platform.isAndroid) return null;
    for (final path in ['/storage/emulated/0/Download', '/sdcard/Download']) {
      final dir = Directory(path);
      if (await dir.exists()) return dir;
    }
    // Android 7+ compatible path
    final external = await getExternalStorageDirectory();
    if (external != null) {
      final legacy = Directory('${external.path.replaceAll('/Android/data/${external.path.split('/').last}', '')}/Download');
      if (await legacy.exists()) return legacy;
    }
    return null;
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

  /// Write backup file to temp directory (temp=true) or app documents (temp=false).
  static Future<File?> _writeBackupFile({bool temp = true}) async {
    try {
      final dir = temp
          ? await getTemporaryDirectory()
          : await getApplicationDocumentsDirectory();
      final backupDir = Directory('${dir.path}/backups');
      if (!await backupDir.exists()) await backupDir.create(recursive: true);
      final timestamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
      final file = File('${backupDir.path}/GST_Solution_Backup_$timestamp.json');

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

  /// Write backup file to a specific directory.
  static Future<File?> _writeBackupToDir(Directory dir) async {
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
  }

  /// Keep only the 5 most recent backups in a directory.
  static Future<void> _cleanOldBackups(Directory dir) async {
    final files = dir.listSync().whereType<File>().toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    while (files.length > 5) {
      files.last.deleteSync();
      files.removeLast();
    }
  }

  /// Restore data from a backup file.
  static Future<bool> _restore(File file) async {
    try {
      final content = await file.readAsString();
      final payload = jsonDecode(content) as Map<String, dynamic>;
      final data = payload['data'] as Map<String, dynamic>;

      // Preserve current session data before clearing
      final currentUser = LocalStorage.getUserData();
      final currentSettings = <String, dynamic>{};
      for (final key in LocalStorage.settingsBox.keys) {
        currentSettings[key.toString()] = LocalStorage.settingsBox.get(key);
      }

      // Clear all existing data first
      await LocalStorage.clearAll();

      // Write back ALL backup data (overwrites user/settings too — will fix below)
      for (final entry in _allBoxes().entries) {
        final boxData = data[entry.key] as Map<String, dynamic>?;
        if (boxData == null) continue;
        final box = entry.value;
        for (final key in boxData.keys) {
          await box.put(key, boxData[key]);
        }
      }

      // Restore current session user data (so offline re-launch still works)
      if (currentUser.isNotEmpty) {
        await LocalStorage.saveUserData(currentUser);
      }
      // Restore current settings that shouldn't be overwritten
      for (final entry in currentSettings.entries) {
        await LocalStorage.settingsBox.put(entry.key, entry.value);
      }

      return true;
    } catch (_) {
      return false;
    }
  }
}
