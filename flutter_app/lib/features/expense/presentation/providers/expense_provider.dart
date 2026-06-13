// lib/features/expense/presentation/providers/expense_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/storage/local_storage.dart';
import '../../domain/entities/expense_entity.dart';

// ─── Expense Categories ──────────────────────────────────────────────────────

final expenseCategoriesProvider = FutureProvider<List<ExpenseCategoryEntity>>((ref) async {
  final cached = LocalStorage.expenseCategoryBox.values.toList();
  if (cached.isEmpty) {
    // Seed default categories
    final defaults = [
      const ExpenseCategoryEntity(id: 'products', name: 'Products (Shampoo, Color)'),
      const ExpenseCategoryEntity(id: 'rent', name: 'Rent'),
      const ExpenseCategoryEntity(id: 'electricity', name: 'Electricity'),
      const ExpenseCategoryEntity(id: 'water', name: 'Water'),
      const ExpenseCategoryEntity(id: 'salary', name: 'Staff Salary'),
      const ExpenseCategoryEntity(id: 'supplies', name: 'Supplies & Products'),
      const ExpenseCategoryEntity(id: 'equipment', name: 'Equipment'),
      const ExpenseCategoryEntity(id: 'marketing', name: 'Marketing'),
      const ExpenseCategoryEntity(id: 'maintenance', name: 'Maintenance'),
      const ExpenseCategoryEntity(id: 'other', name: 'Other'),
    ];
    for (final cat in defaults) {
      await LocalStorage.expenseCategoryBox.put(cat.id, cat.toJson());
    }
    return defaults;
  }
  return cached.map((m) => ExpenseCategoryEntity.fromJson(Map<String, dynamic>.from(m))).toList();
});

// ─── Expense List Notifier ───────────────────────────────────────────────────

final expenseListProvider = AsyncNotifierProvider<ExpenseListNotifier, List<ExpenseEntity>>(
  ExpenseListNotifier.new,
);

class ExpenseListNotifier extends AsyncNotifier<List<ExpenseEntity>> {
  @override
  Future<List<ExpenseEntity>> build() async {
    return _fetchExpenses();
  }

  Future<List<ExpenseEntity>> _fetchExpenses() async {
    final cached = LocalStorage.expenseBox.values.toList();
    return cached
        .map((m) => ExpenseEntity.fromJson(Map<String, dynamic>.from(m)))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> addExpense(ExpenseEntity expense) async {
    state = const AsyncLoading();
    await LocalStorage.expenseBox.put(expense.id, expense.toJson());
    state = AsyncData(await _fetchExpenses());
  }

  Future<void> deleteExpense(String id) async {
    state = const AsyncLoading();
    await LocalStorage.expenseBox.delete(id);
    state = AsyncData(await _fetchExpenses());
  }
}

// ─── Add Expense State ────────────────────────────────────────────────────────

class AddExpenseState {
  final bool isLoading;
  final bool isSuccess;
  final String? error;

  const AddExpenseState({this.isLoading = false, this.isSuccess = false, this.error});

  AddExpenseState copyWith({bool? isLoading, bool? isSuccess, String? error}) {
    return AddExpenseState(
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      error: error,
    );
  }
}

final addExpenseProvider = NotifierProvider<AddExpenseNotifier, AddExpenseState>(
  AddExpenseNotifier.new,
);

class AddExpenseNotifier extends Notifier<AddExpenseState> {
  @override
  AddExpenseState build() => const AddExpenseState();

  Future<void> addExpense({
    required String categoryId,
    required String categoryName,
    required String description,
    required double amount,
    required DateTime date,
    String? receiptPath,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final id = const Uuid().v4();
      final expense = ExpenseEntity(
        id: id,
        categoryId: categoryId,
        categoryName: categoryName,
        description: description,
        amount: amount,
        date: date,
        receiptPath: receiptPath,
        createdAt: DateTime.now(),
      );

      await ref.read(expenseListProvider.notifier).addExpense(expense);
      state = state.copyWith(isLoading: false, isSuccess: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void reset() => state = const AddExpenseState();
}
