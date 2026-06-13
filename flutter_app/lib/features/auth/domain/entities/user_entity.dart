// lib/features/auth/domain/entities/user_entity.dart

import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String id;
  final String? name;
  final String? email;
  final String? phone;
  final String? photoUrl;
  final bool emailVerified;
  final bool isBusinessSetupDone;
  final String? businessId;
  final String plan;
  final int maxStaff;
  final int maxServices;
  final int maxSales;
  final DateTime createdAt;

  const UserEntity({
    required this.id,
    this.name,
    this.email,
    this.phone,
    this.photoUrl,
    this.emailVerified = false,
    this.isBusinessSetupDone = false,
    this.businessId,
    this.plan = 'free',
    this.maxStaff = 999,
    this.maxServices = 999,
    this.maxSales = 999,
    required this.createdAt,
  });

  bool get isLoggedIn => id.isNotEmpty;

  UserEntity copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? photoUrl,
    bool? emailVerified,
    bool? isBusinessSetupDone,
    String? businessId,
    String? plan,
    int? maxStaff,
    int? maxServices,
    int? maxSales,
    DateTime? createdAt,
  }) {
    return UserEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      emailVerified: emailVerified ?? this.emailVerified,
      isBusinessSetupDone: isBusinessSetupDone ?? this.isBusinessSetupDone,
      businessId: businessId ?? this.businessId,
      plan: plan ?? this.plan,
      maxStaff: maxStaff ?? this.maxStaff,
      maxServices: maxServices ?? this.maxServices,
      maxSales: maxSales ?? this.maxSales,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, email, phone, isBusinessSetupDone, businessId, plan];
}

