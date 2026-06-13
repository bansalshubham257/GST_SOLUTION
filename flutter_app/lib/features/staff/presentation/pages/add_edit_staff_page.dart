// lib/features/staff/presentation/pages/add_edit_staff_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/plan_limits.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/staff_provider.dart';
import '../../domain/entities/staff_entity.dart';

class AddEditStaffPage extends ConsumerStatefulWidget {
  final StaffEntity? staff;
  const AddEditStaffPage({super.key, this.staff});

  @override
  ConsumerState<AddEditStaffPage> createState() => _AddEditStaffPageState();
}

class _AddEditStaffPageState extends ConsumerState<AddEditStaffPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _roleController;
  late TextEditingController _phoneController;
  late TextEditingController _commissionController;

  bool get _isEditing => widget.staff != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.staff?.name);
    _roleController = TextEditingController(text: widget.staff?.role);
    _phoneController = TextEditingController(text: widget.staff?.phone);
    _commissionController = TextEditingController(
      text: widget.staff?.commissionPercentage.toString() ?? '0',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _phoneController.dispose();
    _commissionController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    // Plan limit check for new staff
    if (!_isEditing) {
      final authState = ref.read(authStateProvider).valueOrNull;
      final staffList = ref.read(staffListProvider).valueOrNull ?? [];
      final maxStaff = authState?.user?.maxStaff ?? 999;
      if (PlanLimits.isLimitReached(staffList.length, maxStaff)) {
        PlanLimits.showLimitDialog(context, 'staff members', staffList.length, maxStaff);
        return;
      }
    }

    ref.read(staffFormProvider.notifier).saveStaff(
      id: widget.staff?.id,
      name: _nameController.text.trim(),
      role: _roleController.text.trim(),
      phone: _phoneController.text.trim(),
      commissionPercentage: double.tryParse(_commissionController.text) ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(staffFormProvider);

    ref.listen(staffFormProvider, (previous, next) {
      if (next.isSuccess) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditing ? 'Staff updated' : 'Staff added')),
        );
      }
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${next.error}')),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Staff' : 'Add Staff'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              AppTextField(
                controller: _nameController,
                label: 'Full Name',
                validator: (v) => v!.isEmpty ? 'Name required' : null,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _roleController,
                label: 'Role (e.g. Senior Stylist)',
                hint: 'Stylist, Barber, Assistant, etc.',
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _phoneController,
                label: 'Phone Number',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _commissionController,
                label: 'Commission Percentage (%)',
                keyboardType: TextInputType.number,
                validator: (v) {
                  final val = double.tryParse(v ?? '');
                  if (val == null) return 'Invalid number';
                  if (val < 0 || val > 100) return 'Must be between 0-100';
                  return null;
                },
              ),
              const SizedBox(height: 32),
              AppButton(
                onPressed: state.isLoading ? null : _save,
                label: _isEditing ? 'Update Staff' : 'Save Staff',
                isLoading: state.isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
