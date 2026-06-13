// lib/features/staff/domain/entities/staff_entity.dart

import 'package:equatable/equatable.dart';

class StaffEntity extends Equatable {
  final String id;
  final String name;
  final String? role;
  final String? phone;
  final double commissionPercentage;
  final double totalRevenue;
  final double totalCommission;
  final DateTime createdAt;

  const StaffEntity({
    required this.id,
    required this.name,
    this.role,
    this.phone,
    this.commissionPercentage = 0,
    this.totalRevenue = 0,
    this.totalCommission = 0,
    required this.createdAt,
  });

  factory StaffEntity.fromJson(Map<String, dynamic> json) {
    return StaffEntity(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      role: json['role'],
      phone: json['phone'],
      commissionPercentage: (json['commissionPercentage'] ?? 0).toDouble(),
      totalRevenue: (json['totalRevenue'] ?? 0).toDouble(),
      totalCommission: (json['totalCommission'] ?? 0).toDouble(),
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'role': role,
    'phone': phone,
    'commissionPercentage': commissionPercentage,
    'totalRevenue': totalRevenue,
    'totalCommission': totalCommission,
    'createdAt': createdAt.toIso8601String(),
  };

  StaffEntity copyWith({
    String? name,
    String? role,
    String? phone,
    double? commissionPercentage,
    double? totalRevenue,
    double? totalCommission,
  }) {
    return StaffEntity(
      id: id,
      name: name ?? this.name,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      commissionPercentage: commissionPercentage ?? this.commissionPercentage,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      totalCommission: totalCommission ?? this.totalCommission,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [id, name, role, phone, commissionPercentage];
}
