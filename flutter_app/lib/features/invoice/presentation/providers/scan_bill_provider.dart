// lib/features/invoice/presentation/providers/scan_bill_provider.dart

import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/scanned_bill_model.dart';
import '../../data/services/bill_scanner_service.dart';

enum ScanBillStatus { idle, scanning, scanned, error }

class ScanBillState {
  final ScanBillStatus status;
  final File? imageFile;
  final ScannedBillData? scannedData;
  final String? error;

  const ScanBillState({
    this.status = ScanBillStatus.idle,
    this.imageFile,
    this.scannedData,
    this.error,
  });

  ScanBillState copyWith({
    ScanBillStatus? status,
    File? imageFile,
    ScannedBillData? scannedData,
    String? error,
  }) {
    return ScanBillState(
      status: status ?? this.status,
      imageFile: imageFile ?? this.imageFile,
      scannedData: scannedData ?? this.scannedData,
      error: error,
    );
  }

  bool get isIdle => status == ScanBillStatus.idle;
  bool get isScanning => status == ScanBillStatus.scanning;
  bool get isScanned => status == ScanBillStatus.scanned;
  bool get hasError => status == ScanBillStatus.error;
}

final scanBillProvider = NotifierProvider<ScanBillNotifier, ScanBillState>(
  ScanBillNotifier.new,
);

class ScanBillNotifier extends Notifier<ScanBillState> {
  @override
  ScanBillState build() => const ScanBillState();

  void setImageFile(File file) {
    state = ScanBillState(
      status: ScanBillStatus.idle,
      imageFile: file,
    );
  }

  Future<void> scanBill() async {
    final imageFile = state.imageFile;
    if (imageFile == null) return;

    state = state.copyWith(status: ScanBillStatus.scanning, error: null);
    try {
      final scannedData = await BillScannerService.scanBillFromFile(imageFile);
      state = state.copyWith(
        status: ScanBillStatus.scanned,
        scannedData: scannedData,
      );
    } catch (e) {
      state = state.copyWith(
        status: ScanBillStatus.error,
        error: 'Failed to scan bill: $e',
      );
    }
  }

  void reset() {
    state = const ScanBillState();
  }

  void updateScannedData(ScannedBillData data) {
    state = state.copyWith(scannedData: data);
  }
}

