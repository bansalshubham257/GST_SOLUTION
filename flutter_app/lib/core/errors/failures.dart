// lib/core/errors/failures.dart

import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  final String? code;

  const Failure({required this.message, this.code});

  @override
  List<Object?> get props => [message, code];
}

class NetworkFailure extends Failure {
  const NetworkFailure({super.message = 'Network error. Check your connection.', super.code});
}

class ServerFailure extends Failure {
  const ServerFailure({required super.message, super.code});
}

class AuthFailure extends Failure {
  const AuthFailure({required super.message, super.code});
}

class ValidationFailure extends Failure {
  const ValidationFailure({required super.message, super.code});
}

class CacheFailure extends Failure {
  const CacheFailure({super.message = 'Cache error occurred.', super.code});
}

class NotFoundFailure extends Failure {
  const NotFoundFailure({super.message = 'Resource not found.', super.code});
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure({super.message = 'Session expired. Please login again.', super.code});
}

class PermissionFailure extends Failure {
  const PermissionFailure({required super.message, super.code});
}

class UnknownFailure extends Failure {
  const UnknownFailure({super.message = 'An unexpected error occurred.', super.code});
}

