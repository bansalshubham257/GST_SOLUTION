// lib/core/network/api_interceptors.dart

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../storage/secure_storage.dart';

/// Adds Firebase JWT token to every request
class AuthInterceptor extends Interceptor {
  final Ref _ref;

  AuthInterceptor(this._ref);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      // Try to get fresh Firebase token first
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await user.getIdToken();
        options.headers['Authorization'] = 'Bearer $token';
      } else {
        // Fallback to stored token
        final token = await SecureStorage.read(AppConstants.tokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
      }
    } catch (e) {
      // Continue without token
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      try {
        // Try token refresh
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final token = await user.getIdToken(true); // Force refresh
          await SecureStorage.write(AppConstants.tokenKey, token!);

          // Retry the original request
          final opts = Options(
            method: err.requestOptions.method,
            headers: {
              ...err.requestOptions.headers,
              'Authorization': 'Bearer $token',
            },
          );

          final response = await Dio().request(
            err.requestOptions.path,
            options: opts,
            data: err.requestOptions.data,
            queryParameters: err.requestOptions.queryParameters,
          );

          return handler.resolve(response);
        }
      } catch (_) {
        await FirebaseAuth.instance.signOut();
        await SecureStorage.deleteAll();
      }
    }
    handler.next(err);
  }
}

/// Automatic retry interceptor for network errors
class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries;
  int _retryCount = 0;

  RetryInterceptor(this.dio, {this.maxRetries = 2});

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final shouldRetry = err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.unknown;

    if (shouldRetry && _retryCount < maxRetries) {
      _retryCount++;
      await Future.delayed(Duration(seconds: _retryCount));

      try {
        final response = await dio.fetch(err.requestOptions);
        _retryCount = 0;
        return handler.resolve(response);
      } catch (e) {
        // Fall through to error handler
      }
    }

    _retryCount = 0;
    handler.next(err);
  }
}

