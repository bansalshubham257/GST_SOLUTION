// lib/features/business_setup/presentation/pages/business_setup_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/gstin_validator.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../providers/business_setup_provider.dart';

class BusinessSetupPage extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existingData;
  const BusinessSetupPage({super.key, this.existingData});

  @override
  ConsumerState<BusinessSetupPage> createState() => _BusinessSetupPageState();
}

class _BusinessSetupPageState extends ConsumerState<BusinessSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _gstinController = TextEditingController();
  final _panController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  String _businessType = 'Retailer';
  String? _selectedState;
  File? _logoFile;
  int _currentStep = 0;

  bool get _isEditing => widget.existingData != null;

  @override
  void initState() {
    super.initState();
    final data = widget.existingData ?? {};
    if (data.isNotEmpty) {
      _businessNameController.text = data['name']?.toString() ?? '';
      _gstinController.text = data['gstin']?.toString() ?? '';
      _panController.text = data['pan']?.toString() ?? '';
      _addressController.text = data['address']?.toString() ?? '';
      _cityController.text = data['city']?.toString() ?? '';
      _pincodeController.text = data['pincode']?.toString() ?? '';
      _phoneController.text = data['phone']?.toString() ?? '';
      _emailController.text = data['email']?.toString() ?? '';
      _businessType = data['businessType']?.toString() ?? 'Retailer';
      _selectedState = data['state']?.toString();
    }
  }

  static const List<String> _businessTypes = [
    'Salon / Spa', 'Barbershop', 'Beauty Parlour', 'Tattoo Studio',
    'Nail Art Studio', 'Spa Centre', 'Retailer', 'Service Provider', 'Other',
  ];

  static const List<String> _indianStates = [
    'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar',
    'Chhattisgarh', 'Delhi', 'Goa', 'Gujarat', 'Haryana',
    'Himachal Pradesh', 'Jharkhand', 'Karnataka', 'Kerala',
    'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya',
    'Mizoram', 'Nagaland', 'Odisha', 'Punjab', 'Rajasthan',
    'Sikkim', 'Tamil Nadu', 'Telangana', 'Tripura', 'Uttar Pradesh',
    'Uttarakhand', 'West Bengal',
  ];

  @override
  void dispose() {
    _businessNameController.dispose();
    _gstinController.dispose();
    _panController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(businessSetupProvider);

    ref.listen(businessSetupProvider, (_, next) {
      if (next.isSuccess) {
        if (_isEditing) {
          context.pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Business details updated'), backgroundColor: AppColors.success),
          );
        } else {
          context.go(AppRoutes.dashboard);
        }
      }
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: AppColors.danger),
        );
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildStepIndicator(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: _currentStep == 0 ? _buildStep1() : _buildStep2(),
                ),
              ),
            ),
            _buildBottomActions(state),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.receipt_long, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'GST Solution',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            _isEditing ? 'Edit Business Details' : 'Setup Your Business',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 4),
          Text(
            _isEditing ? 'Update your business information' : 'This info will appear on your invoices',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _buildStep(0, 'Business Info'),
          Expanded(child: Container(height: 2, color: _currentStep >= 1 ? AppColors.primary : AppColors.borderLight)),
          _buildStep(1, 'GST Details'),
        ],
      ),
    );
  }

  Widget _buildStep(int step, String label) {
    final isActive = _currentStep == step;
    final isDone = _currentStep > step;
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isDone || isActive ? AppColors.primary : AppColors.surfaceVariantLight,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? AppColors.primary : AppColors.borderLight,
              width: isActive ? 2 : 1,
            ),
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      color: isActive ? Colors.white : AppColors.textSecondaryLight,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isActive ? AppColors.primary : AppColors.textSecondaryLight,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        // Logo Upload
        Center(
          child: GestureDetector(
            onTap: _pickLogo,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2),
              ),
              child: _logoFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(_logoFile!, fit: BoxFit.cover),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary, size: 28),
                        const SizedBox(height: 4),
                        Text('Add Logo', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w500)),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        AppTextField(
          label: 'Business Name *',
          hint: 'Your Business Name',
          controller: _businessNameController,
          textCapitalization: TextCapitalization.words,
          validator: (v) => v?.isEmpty == true ? 'Enter business name' : null,
        ),
        const SizedBox(height: 16),
        _buildBusinessTypeDropdown(),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Phone Number *',
          hint: '9876543210',
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          validator: (v) => v?.length != 10 ? 'Enter valid phone' : null,
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Email (Optional)',
          hint: 'business@email.com',
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        AppTextField(
          label: 'GSTIN (Optional)',
          hint: '27AABCU9603R1ZX',
          controller: _gstinController,
          textCapitalization: TextCapitalization.characters,
          maxLength: 15,
          helperText: 'Leave blank if not GST registered',
          validator: (v) {
            if (v == null || v.isEmpty) return null;
            final result = GstinValidator.validate(v);
            return result.isValid ? null : result.error;
          },
          onChanged: (v) {
            if (v.length == 15) {
              final result = GstinValidator.validate(v);
              if (result.isValid && result.pan != null) {
                _panController.text = result.pan!;
              }
            }
          },
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'PAN Number',
          hint: 'AABCU9603R',
          controller: _panController,
          textCapitalization: TextCapitalization.characters,
          maxLength: 10,
          validator: (v) {
            if (v == null || v.isEmpty) return null;
            return GstinValidator.isValidPan(v) ? null : 'Enter valid PAN';
          },
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Business Address *',
          hint: 'Shop No., Street Name',
          controller: _addressController,
          maxLines: 2,
          textCapitalization: TextCapitalization.words,
          validator: (v) => v?.isEmpty == true ? 'Enter address' : null,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                label: 'City *',
                hint: 'Mumbai',
                controller: _cityController,
                textCapitalization: TextCapitalization.words,
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                label: 'Pincode *',
                hint: '400001',
                controller: _pincodeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                validator: (v) => v?.length != 6 ? 'Invalid' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildStateDropdown(),
      ],
    );
  }

  Widget _buildBusinessTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Business Type *',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondaryLight)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _businessType,
          onChanged: (v) => setState(() => _businessType = v!),
          decoration: const InputDecoration(),
          items: _businessTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
        ),
      ],
    );
  }

  Widget _buildStateDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('State *',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondaryLight)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _selectedState,
          hint: const Text('Select State'),
          onChanged: (v) => setState(() => _selectedState = v),
          decoration: const InputDecoration(),
          validator: (v) => v == null ? 'Select state' : null,
          items: _indianStates.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
        ),
      ],
    );
  }

  Widget _buildBottomActions(BusinessSetupState state) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.borderLight)),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: AppButton(
                label: 'Back',
                isOutlined: true,
                onPressed: () => setState(() => _currentStep--),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: AppButton(
              label: _currentStep == 0 ? 'Next' : 'Save & Continue',
              onPressed: () {
                if (_currentStep == 0) {
                  if (_formKey.currentState!.validate()) {
                    setState(() => _currentStep = 1);
                  }
                } else {
                  _submitBusinessSetup();
                }
              },
              isLoading: state.isLoading,
              icon: _currentStep == 0 ? Icons.arrow_forward : Icons.check,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
    if (image != null) setState(() => _logoFile = File(image.path));
  }

  void _submitBusinessSetup() {
    if (!_formKey.currentState!.validate()) return;

    ref.read(businessSetupProvider.notifier).setupBusiness(
      businessName: _businessNameController.text.trim(),
      gstin: _gstinController.text.trim(),
      pan: _panController.text.trim(),
      address: _addressController.text.trim(),
      city: _cityController.text.trim(),
      stateName: _selectedState ?? '',
      pincode: _pincodeController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      businessType: _businessType,
      logoFile: _logoFile,
    );
  }
}

