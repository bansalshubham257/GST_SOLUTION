// lib/features/invoice/presentation/pages/add_item_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/plan_limits.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/widgets/barcode_scanner_sheet.dart';
import '../../../../core/widgets/barcode_generator.dart';
import '../../../../core/services/voice_input_service.dart';
import '../../../../core/widgets/voice_mic_button.dart';
import '../../../../core/widgets/language_toggle_button.dart'; // LanguageToggleButton + VoiceLanguageRow
import '../../../../core/providers/language_provider.dart';
import '../../../../core/utils/chat_strings.dart';
import '../../data/models/item_catalog_entry.dart';
import '../providers/item_catalog_provider.dart';
import '../providers/item_settings_provider.dart';

class AddItemPage extends ConsumerStatefulWidget {
  final ItemCatalogEntry? editItem;
  const AddItemPage({super.key, this.editItem});

  @override
  ConsumerState<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends ConsumerState<AddItemPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _hsnController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _stockController = TextEditingController();
  final _lowStockController = TextEditingController();
  DateTime? _manufacturingDate;
  DateTime? _expiryDate;
  DateTime? _bestBeforeDate;

  double _gstRate = 18;
  String _unit = 'Nos';
  bool _isService = false;
  bool _isSaving = false;
  bool _showQr = false;

  bool get _isEditMode => widget.editItem != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final item = widget.editItem!;
      _nameController.text = item.name;
      _priceController.text = item.unitPrice.toStringAsFixed(2);
      _purchasePriceController.text = item.purchasePrice != null
          ? item.purchasePrice!.toStringAsFixed(2)
          : '';
      _hsnController.text = item.hsnCode ?? '';
      _barcodeController.text = item.barcode ?? '';
      _stockController.text = item.stock > 0 ? item.stock.toStringAsFixed(0) : '';
      _lowStockController.text = item.lowStockThreshold != null
          ? item.lowStockThreshold!.toStringAsFixed(0)
          : '';
      _gstRate = item.gstRate;
      _unit = item.unit;
      _isService = item.isService;
      _manufacturingDate = item.manufacturingDate;
      _expiryDate = item.expiryDate;
      _bestBeforeDate = item.bestBeforeDate;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _purchasePriceController.dispose();
    _hsnController.dispose();
    _barcodeController.dispose();
    _stockController.dispose();
    _lowStockController.dispose();
    super.dispose();
  }

  // ─── Voice Fill ──────────────────────────────────────────────────────────────

  void _showVoiceFillSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ItemVoiceFillSheet(
        onApply: (parsed) {
          setState(() {
            if (parsed.name != null && parsed.name!.isNotEmpty) {
              _nameController.text = parsed.name!;
            }
            if (parsed.price != null) {
              _priceController.text = parsed.price!.toStringAsFixed(2);
            }
            if (parsed.gstRate != null) _gstRate = parsed.gstRate!;
            if (parsed.unit != null) _unit = parsed.unit!;
            if (parsed.hsnCode != null) _hsnController.text = parsed.hsnCode!;
            _isService = parsed.isService;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Form filled from voice!'),
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
    final itemSettings = ref.watch(itemSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Service' : 'Add Service'),
        actions: [
          if (!_isEditMode)
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
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type toggle
              _buildTypeToggle(),
              const SizedBox(height: 20),

              // Item Name
              AppTextField(
                label: 'Item / Service Name *',
                hint: _isService ? 'e.g., Web Design, Consulting' : 'e.g., Laptop, Rice, Steel Rod',
                controller: _nameController,
                prefix: Icon(
                  _isService ? Icons.miscellaneous_services_outlined : Icons.inventory_2_outlined,
                  size: 20,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Item name is required';
                  if (v.trim().length < 2) return 'Name must be at least 2 characters';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Price + Unit in a row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: AppTextField(
                      label: 'Price (₹) *',
                      hint: '0.00',
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      prefix: const Text('₹',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: AppColors.textSecondaryLight)),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        final d = double.tryParse(v);
                        if (d == null || d < 0) return 'Invalid price';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: _buildUnitDropdown(),
                  ),
                ],
              ),
              if (itemSettings.showPurchasePrice) ...[
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Purchase Price (optional)',
                  hint: '0.00',
                  controller: _purchasePriceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  prefix: const Icon(Icons.shopping_cart_outlined, size: 20),
                ),
              ],
              const SizedBox(height: 16),

              // GST Rate
              _buildGstRateSelector(),
              const SizedBox(height: 16),

              // HSN/SAC Code
              AppTextField(
                label: _isService ? 'SAC Code (optional)' : 'HSN Code (optional)',
                hint: _isService ? 'e.g., 998361' : 'e.g., 8471',
                controller: _hsnController,
                keyboardType: TextInputType.number,
                prefix: const Icon(Icons.tag_outlined, size: 20),
              ),
              const SizedBox(height: 16),

              // Barcode / External QR
              AppTextField(
                label: 'Barcode / External QR (optional)',
                hint: 'Scan or enter EAN/UPC barcode',
                controller: _barcodeController,
                prefix: const Icon(Icons.qr_code_outlined, size: 20),
                suffix: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.auto_fix_high, color: AppColors.primary, size: 20),
                      tooltip: 'Generate barcode',
                      onPressed: () {
                        final numericId = DateTime.now().millisecondsSinceEpoch % 100000;
                        setState(() {
                          _barcodeController.text = BarcodeGeneratorUtil.generateEan13(numericId);
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary),
                      tooltip: 'Scan barcode',
                      onPressed: () => BarcodeScannerSheet.show(
                        context,
                        onDetected: (value, _) => setState(() => _barcodeController.text = value),
                        hint: 'Scan the item barcode / QR code',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Stock Management
              _buildStockSection(itemSettings),
              const SizedBox(height: 16),

              // Preview Card
              _buildPreviewCard(),
              const SizedBox(height: 16),

              // QR code section (show for edit mode or after name is entered)
              if (_isEditMode || _nameController.text.isNotEmpty)
                _buildQrSection(),
              const SizedBox(height: 28),

              // Save Button
              AppButton(
                label: _isEditMode ? 'Update Service' : 'Save to Catalog',
                icon: Icons.save_outlined,
                isLoading: _isSaving,
                onPressed: _save,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariantLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _typeTab('📦 Product', false),
          _typeTab('🔧 Service', true),
        ],
      ),
    );
  }

  Widget _typeTab(String label, bool isServiceTab) {
    final isActive = _isService == isServiceTab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _isService = isServiceTab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isActive
                ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive
                  ? AppColors.textPrimaryLight
                  : AppColors.textSecondaryLight,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnitDropdown() {
    const units = ['Nos', 'Kg', 'Ltr', 'Pcs', 'Box', 'Bag', 'Mtr', 'Hr', 'Day', 'Month'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Unit',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondaryLight)),
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
              value: _unit,
              isExpanded: true,
              style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimaryLight,
                  fontFamily: 'Inter'),
              items: units
                  .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                  .toList(),
              onChanged: (v) => setState(() => _unit = v ?? 'Nos'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGstRateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('GST Rate *',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondaryLight)),
        const SizedBox(height: 8),
        Row(
          children: AppConstants.gstRates.map((rate) {
            final isSelected = _gstRate == rate;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => setState(() => _gstRate = rate),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.borderLight,
                      ),
                    ),
                    child: Text(
                      '${rate.toStringAsFixed(0)}%',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStockSection(ItemSettings itemSettings) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text('Stock & Alerts',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          if (itemSettings.showStock)
            AppTextField(
              label: 'Current Stock',
              hint: '0 = untracked',
              controller: _stockController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              prefix: const Icon(Icons.warehouse_outlined, size: 20),
            ),
          if (itemSettings.showStock && itemSettings.showLowStockAlert)
            const SizedBox(height: 12),
          if (itemSettings.showLowStockAlert)
            AppTextField(
              label: 'Low Stock Alert at',
              hint: 'Leave empty for no alert',
              controller: _lowStockController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              prefix: const Icon(Icons.notifications_outlined, size: 20),
            ),
          if (itemSettings.showManufacturingDate ||
              itemSettings.showExpiryDate ||
              itemSettings.showBestBeforeDate) ...[
            const Divider(height: 20),
            const Text('Dates',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
          ],
          if (itemSettings.showManufacturingDate) ...[
            _buildDateField('Manufacturing Date', Icons.calendar_today, _manufacturingDate, (d) {
              setState(() => _manufacturingDate = d);
            }),
            const SizedBox(height: 8),
          ],
          if (itemSettings.showExpiryDate) ...[
            _buildDateField('Expiry Date', Icons.event, _expiryDate, (d) {
              setState(() => _expiryDate = d);
            }),
            const SizedBox(height: 8),
          ],
          if (itemSettings.showBestBeforeDate) ...[
            _buildDateField('Best Before Date', Icons.date_range, _bestBeforeDate, (d) {
              setState(() => _bestBeforeDate = d);
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildDateField(String label, IconData icon, DateTime? value, ValueChanged<DateTime?> onChanged) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          suffixIcon: value != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: () => onChanged(null),
                )
              : null,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(
          value != null
              ? '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}'
              : 'Tap to select',
          style: TextStyle(
            fontSize: 14,
            color: value != null ? AppColors.textPrimaryLight : AppColors.textTertiaryLight,
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    final price = double.tryParse(_priceController.text) ?? 0;
    final gstAmt = price * _gstRate / 100;
    final total = price + gstAmt;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.05),
            AppColors.primary.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.preview_outlined, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            const Text('Preview',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
          ]),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _nameController.text.isEmpty ? 'Item Name' : _nameController.text,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryLight),
              ),
              Text(
                _isService ? 'Service' : 'Product',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondaryLight),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('₹${price.toStringAsFixed(2)} / $_unit',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondaryLight)),
              const Spacer(),
              Text('+${_gstRate.toStringAsFixed(0)}% GST = ₹${gstAmt.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textTertiaryLight)),
            ],
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total per unit:',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textSecondaryLight)),
              Text('₹${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Plan limit check for new items/services
    if (!_isEditMode) {
      final authState = ref.read(authStateProvider).valueOrNull;
      final items = ref.read(itemCatalogProvider);
      final maxServices = authState?.user?.maxServices ?? 999;
      if (PlanLimits.isLimitReached(items.length, maxServices)) {
        PlanLimits.showLimitDialog(context, 'services/items', items.length, maxServices);
        return;
      }
    }

    setState(() => _isSaving = true);

    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text) ?? 0;
    final purchasePrice = double.tryParse(_purchasePriceController.text);
    final usePurchasePrice = purchasePrice != null && purchasePrice > 0;
    final hsnCode = _hsnController.text.trim().isEmpty ? null : _hsnController.text.trim();
    final barcode = _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim();
    final stock = double.tryParse(_stockController.text) ?? 0;
    final lowStockThreshold = double.tryParse(_lowStockController.text);
    final useLowStockAlert = lowStockThreshold != null && lowStockThreshold > 0;

    try {
      if (_isEditMode) {
        final updated = widget.editItem!.copyWith(
          name: name,
          unitPrice: price,
          purchasePrice: usePurchasePrice ? purchasePrice : null,
          gstRate: _gstRate,
          unit: _unit,
          hsnCode: hsnCode,
          isService: _isService,
          barcode: barcode,
          stock: stock,
          lowStockThreshold: useLowStockAlert ? lowStockThreshold : null,
          manufacturingDate: _manufacturingDate,
          expiryDate: _expiryDate,
          bestBeforeDate: _bestBeforeDate,
        );
        await ref.read(itemCatalogProvider.notifier).updateItem(updated);
      } else {
        await ref.read(itemCatalogProvider.notifier).addItem(
          name: name,
          unitPrice: price,
          purchasePrice: usePurchasePrice ? purchasePrice : null,
          gstRate: _gstRate,
          unit: _unit,
          hsnCode: hsnCode,
          isService: _isService,
          barcode: barcode,
          stock: stock,
          lowStockThreshold: useLowStockAlert ? lowStockThreshold : null,
          manufacturingDate: _manufacturingDate,
          expiryDate: _expiryDate,
          bestBeforeDate: _bestBeforeDate,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode ? '"$name" updated!' : '"$name" added to catalog!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildQrSection() {
    // For edit mode we use the stored QR, otherwise build a preview QR
    final item = widget.editItem;
    final qrData = item != null
        ? item.qrData
        : 'gst_item|preview|${_nameController.text}|${_priceController.text}|$_gstRate|$_unit';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.qr_code_2, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              const Text('Item QR Code', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const Spacer(),
              TextButton.icon(
                icon: Icon(_showQr ? Icons.expand_less : Icons.expand_more, size: 16),
                label: Text(_showQr ? 'Hide' : 'Show'),
                onPressed: () => setState(() => _showQr = !_showQr),
                style: TextButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
          if (_showQr) ...[
            const SizedBox(height: 12),
            Center(
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 180,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Print & stick on product for quick scanning',
                style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Item Voice Fill Sheet ────────────────────────────────────────────────────

class _ItemVoiceFillSheet extends ConsumerStatefulWidget {
  final void Function(ParsedItem parsed) onApply;
  const _ItemVoiceFillSheet({required this.onApply});

  @override
  ConsumerState<_ItemVoiceFillSheet> createState() => _ItemVoiceFillSheetState();
}

class _ItemVoiceFillSheetState extends ConsumerState<_ItemVoiceFillSheet> {
  ParsedItem? _parsed;
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
        prompt: ChatStrings(lang).voicePromptItem(),
        onFinal: (t) => setState(() {
          _parsed = t.isNotEmpty ? VoiceParser.parseItem(t) : null;
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
          // Handle
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

          // Title row with language toggle
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
                    Text(s.voiceSheetItemTitle(),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    Text(s.voiceSheetItemSubtitle(),
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                  ],
                ),
              ),
              // Language toggle — changes voice language for all features
              const LanguageToggleButton(),
            ],
          ),
          const SizedBox(height: 8),

          // Hint examples
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
                Text(s.voiceSheetItemEx1(),
                    style: const TextStyle(fontSize: 12, color: AppColors.textTertiaryLight)),
                Text(s.voiceSheetItemEx2(),
                    style: const TextStyle(fontSize: 12, color: AppColors.textTertiaryLight)),
                Text(s.voiceSheetItemEx3(),
                    style: const TextStyle(fontSize: 12, color: AppColors.textTertiaryLight)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Mic button
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
                    _detectedRow(Icons.label_outline, s.fieldName(), parsed.name!),
                  if (parsed.price != null)
                    _detectedRow(Icons.currency_rupee, s.fieldPrice(), '₹${parsed.price!.toStringAsFixed(2)}'),
                  if (parsed.gstRate != null)
                    _detectedRow(Icons.percent, s.fieldGst(), '${parsed.gstRate!.toStringAsFixed(0)}%'),
                  if (parsed.unit != null)
                    _detectedRow(Icons.straighten_outlined, s.fieldUnit(), parsed.unit!),
                  _detectedRow(
                      parsed.isService ? Icons.miscellaneous_services_outlined : Icons.inventory_2_outlined,
                      s.fieldType(),
                      parsed.isService ? s.typeService() : s.typeProduct()),
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
          Text(value,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryLight)),
        ],
      ),
    );
  }
}
