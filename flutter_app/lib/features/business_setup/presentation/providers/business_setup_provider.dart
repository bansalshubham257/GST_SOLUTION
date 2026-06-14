// lib/features/business_setup/presentation/providers/business_setup_provider.dart

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class BusinessSetupState {
  final bool isLoading;
  final bool isSuccess;
  final String? error;

  const BusinessSetupState({
    this.isLoading = false,
    this.isSuccess = false,
    this.error,
  });

  BusinessSetupState copyWith({bool? isLoading, bool? isSuccess, String? error}) {
    return BusinessSetupState(
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      error: error,
    );
  }
}

final businessSetupProvider = NotifierProvider<BusinessSetupNotifier, BusinessSetupState>(
  BusinessSetupNotifier.new,
);

class BusinessSetupNotifier extends Notifier<BusinessSetupState> {
  @override
  BusinessSetupState build() => const BusinessSetupState();

  Future<void> setupBusiness({
    required String businessName,
    required String gstin,
    required String pan,
    required String address,
    required String city,
    required String stateName,
    required String pincode,
    required String phone,
    required String email,
    required String businessType,
    File? logoFile,
  }) async {
    state = state.copyWith(isLoading: true);

    // Save locally first (works offline)
    await LocalStorage.saveBusinessData({
      'name': businessName,
      'gstin': gstin,
      'pan': pan,
      'address': address,
      'city': city,
      'state': stateName,
      'pincode': pincode,
      'phone': phone,
      'email': email,
      'businessType': businessType,
    });
    await LocalStorage.markBusinessSetupDone();

    // Try API in background — don't block on failure
    try {
      final apiClient = ref.read(apiClientProvider);

      String? logoUrl;
      if (logoFile != null) {
        final formData = FormData.fromMap({
          'logo': await MultipartFile.fromFile(logoFile.path),
        });
        final uploadResponse = await apiClient.uploadFile(ApiConstants.uploadLogo, formData);
        logoUrl = uploadResponse.data['url'];
      }

      final response = await apiClient.post(ApiConstants.businessSetup, data: {
        'name': businessName,
        'gstin': gstin.isEmpty ? null : gstin,
        'pan': pan.isEmpty ? null : pan,
        'address': address,
        'city': city,
        'state': stateName,
        'pincode': pincode,
        'phone': phone,
        'email': email.isEmpty ? null : email,
        'businessType': businessType,
        'logoUrl': logoUrl,
      });

      final businessId = response.data['business']?['id']?.toString();
      if (businessId != null) {
        await SecureStorage.write(AppConstants.businessIdKey, businessId);
      }
    } catch (_) {
      // API failed — local data is already saved, proceed
    }

    state = state.copyWith(isLoading: false, isSuccess: true);

    // Update auth state locally so router picks up isBusinessSetupDone without a full re-auth
    ref.read(authStateProvider.notifier).markBusinessSetupDone();
  }

  void reset() => state = const BusinessSetupState();
}
