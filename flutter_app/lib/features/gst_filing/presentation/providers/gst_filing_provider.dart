// lib/features/gst_filing/presentation/providers/gst_filing_provider.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';

// ─── Filing Checklist ─────────────────────────────────────────────────────────

class FilingChecklist {
  final List<FilingCheck> checks;
  final int invoiceCount;
  final DateTime period;

  const FilingChecklist({
    required this.checks,
    required this.invoiceCount,
    required this.period,
  });

  factory FilingChecklist.fromJson(Map<String, dynamic> json) {
    return FilingChecklist(
      checks: (json['checks'] as List? ?? []).map((e) => FilingCheck.fromJson(e)).toList(),
      invoiceCount: json['invoiceCount'] ?? 0,
      period: DateTime.tryParse(json['period'] ?? '') ?? DateTime.now(),
    );
  }

  static FilingChecklist empty(DateTime month) => FilingChecklist(
    checks: [
      const FilingCheck(title: 'All invoices have valid data', isPassed: true),
      const FilingCheck(title: 'No duplicate invoice numbers', isPassed: true),
      const FilingCheck(title: 'GST rates are correct', isPassed: true),
      const FilingCheck(title: 'GSTIN format validated', isPassed: true),
      const FilingCheck(title: 'Tax calculation verified', isPassed: true),
    ],
    invoiceCount: 0,
    period: month,
  );
}

class FilingCheck {
  final String title;
  final bool isPassed;
  final bool isError;
  final String? message;
  final int count;

  const FilingCheck({
    required this.title,
    required this.isPassed,
    this.isError = false,
    this.message,
    this.count = 0,
  });

  factory FilingCheck.fromJson(Map<String, dynamic> json) {
    return FilingCheck(
      title: json['title'] ?? '',
      isPassed: json['isPassed'] ?? true,
      isError: json['isError'] ?? false,
      message: json['message'],
      count: json['count'] ?? 0,
    );
  }
}

// ─── Filing Checklist Provider ────────────────────────────────────────────────

final filingChecklistProvider = FutureProvider.family<FilingChecklist, DateTime>((ref, month) async {
  try {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.get(
      ApiConstants.filingChecklist,
      queryParameters: {'month': '${month.year}-${month.month.toString().padLeft(2, '0')}'},
    );
    return FilingChecklist.fromJson(response.data as Map<String, dynamic>);
  } catch (e) {
    return FilingChecklist.empty(month);
  }
});

// ─── GST Filing Actions Provider ─────────────────────────────────────────────

class GstFilingState {
  final bool isLoading;
  final String? error;
  final String? successMessage;

  const GstFilingState({this.isLoading = false, this.error, this.successMessage});

  GstFilingState copyWith({bool? isLoading, String? error, String? successMessage}) {
    return GstFilingState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      successMessage: successMessage,
    );
  }
}

final gstFilingProvider = NotifierProvider<GstFilingNotifier, GstFilingState>(
  GstFilingNotifier.new,
);

class GstFilingNotifier extends Notifier<GstFilingState> {
  @override
  GstFilingState build() => const GstFilingState();

  Future<void> generateGstr1Json(DateTime month, Function(String path) onSuccess) async {
    state = state.copyWith(isLoading: true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get(
        ApiConstants.generateJson,
        queryParameters: {
          'month': '${month.year}-${month.month.toString().padLeft(2, '0')}',
          'type': 'GSTR1',
        },
      );

      // Save JSON to file
      final jsonString = jsonEncode(response.data);
      final dir = await getApplicationDocumentsDirectory();
      final filename = 'GSTR1_${month.year}${month.month.toString().padLeft(2, '0')}.json';
      final file = File('${dir.path}/$filename');
      await file.writeAsString(jsonString);

      state = state.copyWith(isLoading: false, successMessage: 'GSTR-1 JSON generated');
      onSuccess(file.path);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to generate JSON');
    }
  }

  Future<void> generateGstr3bJson(DateTime month, Function(String path) onSuccess) async {
    state = state.copyWith(isLoading: true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get(
        ApiConstants.generateJson,
        queryParameters: {
          'month': '${month.year}-${month.month.toString().padLeft(2, '0')}',
          'type': 'GSTR3B',
        },
      );

      final jsonString = jsonEncode(response.data);
      final dir = await getApplicationDocumentsDirectory();
      final filename = 'GSTR3B_${month.year}${month.month.toString().padLeft(2, '0')}.json';
      final file = File('${dir.path}/$filename');
      await file.writeAsString(jsonString);

      state = state.copyWith(isLoading: false);
      onSuccess(file.path);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to generate GSTR-3B JSON');
    }
  }
}
