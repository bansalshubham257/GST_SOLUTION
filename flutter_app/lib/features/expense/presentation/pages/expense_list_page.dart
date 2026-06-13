// lib/features/expense/presentation/pages/expense_list_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/expense_provider.dart';

class ExpenseListPage extends ConsumerWidget {
  const ExpenseListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(expenseListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
      ),
      body: expenses.when(
        data: (list) => list.isEmpty
            ? const Center(child: Text('No expenses recorded.'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final expense = list[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.dangerLight,
                        child: const Icon(Icons.outbound, color: AppColors.danger),
                      ),
                      title: Text(expense.description),
                      subtitle: Text('${expense.categoryName} • ${DateFormat('dd MMM').format(expense.date)}'),
                      trailing: Text(
                        '₹${expense.amount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.danger,
                          fontSize: 16,
                        ),
                      ),
                      onLongPress: () {
                        // Delete confirm
                      },
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.addExpense),
        label: const Text('Add Expense'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
