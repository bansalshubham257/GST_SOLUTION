// lib/core/network/api_client.dart

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../constants/api_constants.dart';
import '../constants/app_constants.dart';
import '../storage/secure_storage.dart';
import '../services/sync_service.dart';
import 'api_interceptors.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(milliseconds: AppConstants.connectTimeout),
      receiveTimeout: const Duration(milliseconds: AppConstants.receiveTimeout),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  dio.interceptors.addAll([
    AuthInterceptor(ref),
    RetryInterceptor(dio),
    PrettyDioLogger(
      requestHeader: false,
      requestBody: true,
      responseBody: true,
      responseHeader: false,
      compact: true,
    ),
  ]);

  return dio;
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(dioProvider));
});

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(ref.watch(apiClientProvider));
});

class ApiClient {
  final Dio _dio;

  ApiClient(this._dio);

  /// Throws a [DioException] if no auth token is stored (local-only plan).
  /// Pass [forceSync]=true to skip this check (e.g. for login/signup).
  Future<void> _checkSync({bool forceSync = false}) async {
    if (forceSync) return;
    final token = await SecureStorage.read(AppConstants.tokenKey);
    if (token == null || token.isEmpty) {
      throw DioException(
        type: DioExceptionType.connectionError,
        message: 'API calls disabled on local-only plan',
        requestOptions: RequestOptions(path: ''),
      );
    }
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    bool forceSync = false,
  }) async {
    await _checkSync(forceSync: forceSync);
    return await _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    bool forceSync = false,
  }) async {
    await _checkSync(forceSync: forceSync);
    return await _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    bool forceSync = false,
  }) async {
    await _checkSync(forceSync: forceSync);
    return await _dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    bool forceSync = false,
  }) async {
    await _checkSync(forceSync: forceSync);
    return await _dio.patch<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    bool forceSync = false,
  }) async {
    await _checkSync(forceSync: forceSync);
    return await _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response> uploadFile(
    String path,
    FormData formData, {
    ProgressCallback? onSendProgress,
    bool forceSync = false,
  }) async {
    await _checkSync(forceSync: forceSync);
    return await _dio.post(
      path,
      data: formData,
      onSendProgress: onSendProgress,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  Future<Response> downloadFile(
    String path,
    String savePath, {
    ProgressCallback? onReceiveProgress,
    bool forceSync = false,
  }) async {
    await _checkSync(forceSync: forceSync);
    return await _dio.download(
      path,
      savePath,
      onReceiveProgress: onReceiveProgress,
    );
  }
}
