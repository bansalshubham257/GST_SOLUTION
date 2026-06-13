// lib/features/customer/presentation/pages/add_customer_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/gstin_validator.dart';
import '../../../../core/utils/indian_states.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/services/voice_input_service.dart';
import '../../../../core/widgets/voice_mic_button.dart';
import '../../../../core/widgets/language_toggle_button.dart'; // LanguageToggleButton + VoiceLanguageRow
import '../../../../core/providers/language_provider.dart';
import '../../../../core/utils/chat_strings.dart';
import '../providers/customer_provider.dart';

class AddCustomerPage extends ConsumerStatefulWidget {
  const AddCustomerPage({super.key});

  @override
  ConsumerState<AddCustomerPage> createState() => _AddCustomerPageState();
}

class _AddCustomerPageState extends ConsumerState<AddCustomerPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _gstinController = TextEditingController();
  final _panController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _pincodeController = TextEditingController();
  String? _selectedState;

  @override
  void dispose() {
    _nameController.dispose();
    _gstinController.dispose();
    _panController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  // ─── Voice Fill ──────────────────────────────────────────────────────────────

  void _showVoiceFillSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CustomerVoiceFillSheet(
        onApply: (parsed) {
          setState(() {
            if (parsed.name != null) _nameController.text = parsed.name!;
            if (parsed.phone != null) _phoneController.text = parsed.phone!;
            if (parsed.email != null) _emailController.text = parsed.email!;
            if (parsed.gstin != null) {
              _gstinController.text = parsed.gstin!;
              final result = GstinValidator.validate(parsed.gstin!);
              if (result.isValid && result.pan != null) {
                _panController.text = result.pan!;
              }
            }
            if (parsed.city != null) _cityController.text = parsed.city!;
            if (parsed.pincode != null) _pincodeController.text = parsed.pincode!;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ChatStrings(ref.read(appLanguageProvider)).formFilledMsg()),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addCustomerProvider);

    ref.listen(addCustomerProvider, (_, next) {
      if (next.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer added!'), backgroundColor: AppColors.success),
        );
        ref.read(addCustomerProvider.notifier).reset();
        Navigator.pop(context, next.addedCustomer);
      }
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: AppColors.danger),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Customer'),
        actions: [
          Tooltip(
            message: 'Fill by Voice',
            child: IconButton(
              icon: const Icon(Icons.mic_rounded),
              onPressed: _showVoiceFillSheet,
              style: IconButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: state.isLoading,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Basic Info', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Customer Name *',
                      hint: 'Full name or company name',
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Phone',
                      hint: '9876543210',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Email',
                      hint: 'customer@email.com',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('GST & Tax', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'GSTIN',
                      hint: '27AABCU9603R1ZX',
                      controller: _gstinController,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 15,
                      suffix: IconButton(
                        icon: const Icon(Icons.verified_outlined, size: 18),
                        onPressed: _validateGstin,
                      ),
                      onChanged: (v) {
                        if (v.length == 15) {
                          final result = GstinValidator.validate(v);
                          if (result.isValid && result.pan != null) {
                            _panController.text = result.pan!;
                          }
                        }
                      },
                      validator: (v) {
                        if (v == null || v.isEmpty) return null;
                        final r = GstinValidator.validate(v);
                        return r.isValid ? null : r.error;
                      },
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'PAN',
                      hint: 'AABCU9603R',
                      controller: _panController,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 10,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Address', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Street Address',
                      hint: 'Shop No., Street Name',
                      controller: _addressController,
                      maxLines: 2,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),
                    _buildStateDropdown(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: AppTextField(
                            label: 'City',
                            hint: 'Mumbai',
                            controller: _cityController,
                            textCapitalization: TextCapitalization.words,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            label: 'Pincode',
                            hint: '400001',
                            controller: _pincodeController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              AppButton(
                label: 'Save Customer',
                onPressed: _submit,
                isLoading: state.isLoading,
                icon: Icons.check,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _validateGstin() {
    final gstin = _gstinController.text.trim();
    if (gstin.isEmpty) return;
    final result = GstinValidator.validate(gstin);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.isValid ? '✅ Valid GSTIN' : '❌ ${result.error}'),
        backgroundColor: result.isValid ? AppColors.success : AppColors.danger,
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(addCustomerProvider.notifier).addCustomer({
      'name': _nameController.text.trim(),
      'gstin': _gstinController.text.trim().isEmpty ? null : _gstinController.text.trim(),
      'pan': _panController.text.trim().isEmpty ? null : _panController.text.trim(),
      'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      'address': _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      'city': _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
      'stateName': _selectedState,
      'pincode': _pincodeController.text.trim().isEmpty ? null : _pincodeController.text.trim(),
    });
  }

  Widget _buildStateDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('State',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondaryLight)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.borderLight),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedState,
              hint: const Text('Select state', style: TextStyle(fontSize: 14)),
              isExpanded: true,
              items: indianStates.map((s) => DropdownMenuItem(
                value: s['name'],
                child: Text('${s['name']} (${s['code']})', style: const TextStyle(fontSize: 14)),
              )).toList(),
              onChanged: (v) => setState(() => _selectedState = v),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Customer Voice Fill Sheet ────────────────────────────────────────────────

class _CustomerVoiceFillSheet extends ConsumerStatefulWidget {
  final void Function(ParsedCustomer parsed) onApply;
  const _CustomerVoiceFillSheet({required this.onApply});

  @override
  ConsumerState<_CustomerVoiceFillSheet> createState() =>
      _CustomerVoiceFillSheetState();
}

class _CustomerVoiceFillSheetState
    extends ConsumerState<_CustomerVoiceFillSheet> {
  ParsedCustomer? _parsed;
  bool _applied = false;

  void _toggleListening() {
    final voice = ref.read(voiceInputProvider);
    final notifier = ref.read(voiceInputProvider.notifier);
    final lang = ref.read(appLanguageProvider);
    if (voice.isListening) {
      notifier.stopListening();
    } else {
      _applied = false;
      notifier.startListening(
        localeId: lang.locale,
        prompt: ChatStrings(lang).voicePromptCustomer(),
        onFinal: (t) => setState(() {
          _parsed = t.isNotEmpty ? VoiceParser.parseCustomer(t) : null;
        }),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final voice = ref.watch(voiceInputProvider);
    final lang = ref.watch(appLanguageProvider);
    final s = ChatStrings(lang);
    final parsed = _parsed;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          // ── Language selector ──────────────────────────────────────────────
          const VoiceLanguageRow(),
          const SizedBox(height: 14),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.mic_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.voiceSheetCustomerTitle(),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    Text(s.voiceSheetCustomerSubtitle(),
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                  ],
                ),
              ),
              // Language toggle — changes voice language for all features
              const LanguageToggleButton(),
            ],
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.exampleLabel(),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: AppColors.textSecondaryLight)),
                const SizedBox(height: 6),
                Text(s.voiceSheetCustomerEx1(),
                    style: const TextStyle(fontSize: 12, color: AppColors.textTertiaryLight)),
                Text(s.voiceSheetCustomerEx2(),
                    style: const TextStyle(fontSize: 12, color: AppColors.textTertiaryLight)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Center(
            child: VoiceMicButton(
              isListening: voice.isListening,
              isInitializing: voice.isInitializing,
              size: 64,
              onTap: _toggleListening,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            voice.isListening
                ? s.voiceListeningTxt()
                : voice.isDone
                    ? s.voiceDoneTxt()
                    : s.voiceIdleTxt(),
            style: TextStyle(
              fontSize: 13,
              color: voice.isListening ? Colors.red.shade600 : AppColors.textSecondaryLight,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),

          if (voice.transcript.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Text(
                '"${voice.transcript}"',
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textPrimaryLight,
                    fontStyle: FontStyle.italic),
              ),
            ),

          if (parsed != null && parsed.hasAnyData && !voice.isListening) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.voiceDetectedLabel(),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: AppColors.success)),
                  const SizedBox(height: 8),
                  if (parsed.name != null)
                    _detectedRow(Icons.person_outline, s.fieldName(), parsed.name!),
                  if (parsed.phone != null)
                    _detectedRow(Icons.phone_outlined, s.fieldPhone(), parsed.phone!),
                  if (parsed.email != null)
                    _detectedRow(Icons.email_outlined, s.fieldEmail(), parsed.email!),
                  if (parsed.gstin != null)
                    _detectedRow(Icons.business_outlined, s.fieldGstin(), parsed.gstin!),
                  if (parsed.city != null)
                    _detectedRow(Icons.location_city_outlined, s.fieldCity(), parsed.city!),
                  if (parsed.pincode != null)
                    _detectedRow(Icons.pin_drop_outlined, s.fieldPincode(), parsed.pincode!),
                ],
              ),
            ),
          ],

          if (parsed == null && voice.isDone && voice.transcript.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(s.voiceNoFields(),
                style: const TextStyle(color: AppColors.warning, fontSize: 13)),
          ],

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(voiceInputProvider.notifier).reset();
                    Navigator.pop(context);
                  },
                  child: Text(s.cancelBtn()),
                ),
              ),
              if (parsed != null && parsed.hasAnyData && !voice.isListening) ...[
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _applied
                        ? null
                        : () {
                            _applied = true;
                            ref.read(voiceInputProvider.notifier).reset();
                            Navigator.pop(context);
                            widget.onApply(parsed);
                          },
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(s.fillFormBtn()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _detectedRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.success),
          const SizedBox(width: 6),
          Text('$label: ',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondaryLight)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryLight),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
