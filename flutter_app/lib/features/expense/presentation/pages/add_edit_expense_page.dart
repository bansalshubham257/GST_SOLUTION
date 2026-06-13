// lib/features/expense/presentation/pages/add_edit_expense_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/app_widgets.dart';
import '../providers/expense_provider.dart';
import '../../domain/entities/expense_entity.dart';

class AddEditExpensePage extends ConsumerStatefulWidget {
  const AddEditExpensePage({super.key});

  @override
  ConsumerState<AddEditExpensePage> createState() => _AddEditExpensePageState();
}

class _AddEditExpensePageState extends ConsumerState<AddEditExpensePage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  ExpenseCategoryEntity? _selectedCategory;

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate() && _selectedCategory != null) {
      ref.read(addExpenseProvider.notifier).addExpense(
        categoryId: _selectedCategory!.id,
        categoryName: _selectedCategory!.name,
        description: _descriptionController.text.trim(),
        amount: double.parse(_amountController.text),
        date: _selectedDate,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addExpenseProvider);
    final categories = ref.watch(expenseCategoriesProvider);

    ref.listen(addExpenseProvider, (previous, next) {
      if (next.isSuccess) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense recorded')),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              categories.when(
                data: (list) => DropdownButtonFormField<ExpenseCategoryEntity>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: list.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                  onChanged: (v) => setState(() => _selectedCategory = v),
                  validator: (v) => v == null ? 'Category required' : null,
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, s) => Text('Error loading categories: $e'),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _descriptionController,
                label: 'Description',
                validator: (v) => v!.isEmpty ? 'Description required' : null,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _amountController,
                label: 'Amount (₹)',
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? 'Amount required' : null,
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Date'),
                subtitle: Text(DateFormat('dd MMMM yyyy').format(_selectedDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
              ),
              const SizedBox(height: 32),
              AppButton(
                onPressed: state.isLoading ? null : _save,
                label: 'Save Expense',
                isLoading: state.isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
