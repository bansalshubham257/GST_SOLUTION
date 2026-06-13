// lib/features/expense/domain/entities/expense_entity.dart

import 'package:equatable/equatable.dart';

class ExpenseEntity extends Equatable {
  final String id;
  final String categoryId;
  final String categoryName;
  final String description;
  final double amount;
  final DateTime date;
  final String? receiptPath;
  final DateTime createdAt;

  const ExpenseEntity({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.description,
    required this.amount,
    required this.date,
    this.receiptPath,
    required this.createdAt,
  });

  factory ExpenseEntity.fromJson(Map<String, dynamic> json) {
    return ExpenseEntity(
      id: json['id']?.toString() ?? '',
      categoryId: json['categoryId'] ?? '',
      categoryName: json['categoryName'] ?? 'Uncategorized',
      description: json['description'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      receiptPath: json['receiptPath'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'categoryId': categoryId,
    'categoryName': categoryName,
    'description': description,
    'amount': amount,
    'date': date.toIso8601String(),
    'receiptPath': receiptPath,
    'createdAt': createdAt.toIso8601String(),
  };

  @override
  List<Object?> get props => [id, categoryId, amount, date];
}

class ExpenseCategoryEntity extends Equatable {
  final String id;
  final String name;
  final String? icon;

  const ExpenseCategoryEntity({
    required this.id,
    required this.name,
    this.icon,
  });

  factory ExpenseCategoryEntity.fromJson(Map<String, dynamic> json) {
    return ExpenseCategoryEntity(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      icon: json['icon'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'icon': icon,
  };

  @override
  List<Object?> get props => [id, name];
}
