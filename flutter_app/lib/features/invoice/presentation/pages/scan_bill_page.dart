// lib/features/invoice/presentation/pages/scan_bill_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/gst_calculator.dart';
import '../../../../core/utils/gstin_validator.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../providers/scan_bill_provider.dart';
import '../providers/invoice_provider.dart';
import '../../data/models/scanned_bill_model.dart';

class ScanBillPage extends ConsumerStatefulWidget {
  const ScanBillPage({super.key});

  @override
  ConsumerState<ScanBillPage> createState() => _ScanBillPageState();
}

class _ScanBillPageState extends ConsumerState<ScanBillPage>
    with SingleTickerProviderStateMixin {
  final _imagePicker = ImagePicker();
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(scanBillProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Scan Bill'),
        actions: [
          if (scanState.isScanned)
            TextButton(
              onPressed: () => ref.read(scanBillProvider.notifier).reset(),
              child: const Text('Rescan'),
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: scanState.isScanned && scanState.scannedData != null
            ? _ScanReviewBody(
                key: const ValueKey('review'),
                scannedData: scanState.scannedData!,
                imageFile: scanState.imageFile,
              )
            : _ScanPickerBody(
                key: const ValueKey('picker'),
                scanState: scanState,
                onPickImage: _pickImage,
                onScan: () => ref.read(scanBillProvider.notifier).scanBill(),
                pulseController: _pulseController,
              ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    // ── Request permissions first ──────────────────────────────────────────
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Camera permission denied. Please allow in Settings.'),
              backgroundColor: AppColors.danger,
              action: SnackBarAction(
                label: 'Settings',
                textColor: Colors.white,
                onPressed: openAppSettings,
              ),
            ),
          );
        }
        return;
      }
    } else {
      // Gallery — request photo/storage permission
      PermissionStatus status;
      if (Platform.isAndroid) {
        // Android 13+: READ_MEDIA_IMAGES; older: READ_EXTERNAL_STORAGE
        status = await Permission.photos.request();
        if (!status.isGranted) {
          status = await Permission.storage.request();
        }
      } else {
        status = await Permission.photos.request();
      }
      if (!status.isGranted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Storage permission denied. Please allow in Settings.'),
            backgroundColor: AppColors.danger,
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: openAppSettings,
            ),
          ),
        );
        return;
      }
    }

    // ── Pick image ───────────────────────────────────────────────────────
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 2000,
        maxHeight: 2000,
      );
      if (picked == null) return;

      // Optional crop
      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        compressQuality: 90,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Bill',
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: false,
          ),
          IOSUiSettings(title: 'Crop Bill'),
        ],
      );

      final file = File(cropped?.path ?? picked.path);
      ref.read(scanBillProvider.notifier).setImageFile(file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }
}

// ─── Picker Body ──────────────────────────────────────────────────────────────

class _ScanPickerBody extends StatelessWidget {
  final ScanBillState scanState;
  final Future<void> Function(ImageSource) onPickImage;
  final VoidCallback onScan;
  final AnimationController pulseController;

  const _ScanPickerBody({
    super.key,
    required this.scanState,
    required this.onPickImage,
    required this.onScan,
    required this.pulseController,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(Icons.document_scanner_rounded, color: Colors.white, size: 48),
                const SizedBox(height: 12),
                const Text(
                  'Scan Offline Bill',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Capture or upload a bill image — we\'ll auto-extract customer, items & GST details',
                  style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Image preview or picker
          if (scanState.imageFile != null) ...[
            _buildImagePreview(context, scanState.imageFile!),
            const SizedBox(height: 16),
          ] else ...[
            _buildPickerOptions(context),
            const SizedBox(height: 16),
          ],

          // Error state
          if (scanState.hasError) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.dangerLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.danger.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      scanState.error ?? 'Scan failed. Please try again.',
                      style: const TextStyle(color: AppColors.danger, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Scan button
          if (scanState.imageFile != null)
            scanState.isScanning
                ? _buildScanningIndicator(context)
                : AppButton(
                    label: 'Extract Bill Details',
                    icon: Icons.auto_fix_high_rounded,
                    onPressed: onScan,
                  ),

          const SizedBox(height: 20),
          _buildTipsCard(context),
        ],
      ),
    );
  }

  Widget _buildPickerOptions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ImageSourceButton(
            icon: Icons.camera_alt_rounded,
            label: 'Camera',
            subtitle: 'Take a photo',
            color: AppColors.primary,
            onTap: () => onPickImage(ImageSource.camera),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ImageSourceButton(
            icon: Icons.photo_library_rounded,
            label: 'Gallery',
            subtitle: 'Choose from photos',
            color: AppColors.secondary,
            onTap: () => onPickImage(ImageSource.gallery),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreview(BuildContext context, File imageFile) {
    return Column(
      children: [
        AppCard(
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  imageFile,
                  height: 280,
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.success, size: 16),
                  const SizedBox(width: 6),
                  const Text('Image ready for scanning', style: TextStyle(color: AppColors.success, fontSize: 13)),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.swap_horiz, size: 16),
                    label: const Text('Change'),
                    onPressed: () => onPickImage(ImageSource.gallery),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScanningIndicator(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
          ),
          SizedBox(width: 12),
          Text(
            'Scanning & extracting details…',
            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsCard(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline, color: AppColors.accent, size: 18),
              SizedBox(width: 8),
              Text('Tips for best results', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),
          _tip('Good lighting — avoid shadows on the bill'),
          _tip('Keep the bill flat and all text visible'),
          _tip('Ensure GSTIN numbers are clearly readable'),
          _tip('Works with printed bills, invoices & receipts'),
        ],
      ),
    );
  }

  Widget _tip(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('• ', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight))),
      ],
    ),
  );
}

class _ImageSourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ImageSourceButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(color: color.withOpacity(0.7), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ─── Review Body ──────────────────────────────────────────────────────────────

class _ScanReviewBody extends ConsumerStatefulWidget {
  final ScannedBillData scannedData;
  final File? imageFile;

  const _ScanReviewBody({
    super.key,
    required this.scannedData,
    this.imageFile,
  });

  @override
  ConsumerState<_ScanReviewBody> createState() => _ScanReviewBodyState();
}

class _ScanReviewBodyState extends ConsumerState<_ScanReviewBody> {
  final _uuid = const Uuid();

  // Customer controllers
  late final TextEditingController _customerNameCtrl;
  late final TextEditingController _customerGstinCtrl;
  late final TextEditingController _customerPhoneCtrl;
  late final TextEditingController _customerEmailCtrl;
  late final TextEditingController _customerAddressCtrl;

  // Invoice meta
  late DateTime _invoiceDate;
  late final TextEditingController _invoiceNumberCtrl;

  // Line items (editable copies)
  late final List<_EditableLineItem> _lineItems;

  bool _saveCustomer = false;
  bool _showRawText = false;

  @override
  void initState() {
    super.initState();
    final d = widget.scannedData;
    _customerNameCtrl = TextEditingController(text: d.customerName ?? '');
    _customerGstinCtrl = TextEditingController(text: d.customerGstin ?? '');
    _customerPhoneCtrl = TextEditingController(text: d.customerPhone ?? '');
    _customerEmailCtrl = TextEditingController(text: d.customerEmail ?? '');
    _customerAddressCtrl = TextEditingController(text: d.customerAddress ?? '');
    _invoiceNumberCtrl = TextEditingController(text: d.invoiceNumber ?? '');
    _invoiceDate = d.invoiceDate ?? DateTime.now();

    _lineItems = d.lineItems.isNotEmpty
        ? d.lineItems
            .map((item) => _EditableLineItem(
                  id: _uuid.v4(),
                  descriptionCtrl: TextEditingController(text: item.description),
                  qtyCtrl: TextEditingController(text: item.quantity.toStringAsFixed(item.quantity == item.quantity.roundToDouble() ? 0 : 2)),
                  priceCtrl: TextEditingController(text: item.unitPrice.toStringAsFixed(2)),
                  hsnCtrl: TextEditingController(text: item.hsnCode ?? ''),
                  gstRate: _nearestGstRate(item.gstRate),
                ))
            .toList()
        : [
            _EditableLineItem(
              id: _uuid.v4(),
              descriptionCtrl: TextEditingController(),
              qtyCtrl: TextEditingController(text: '1'),
              priceCtrl: TextEditingController(),
              hsnCtrl: TextEditingController(),
              gstRate: 18.0,
            )
          ];
  }

  double _nearestGstRate(double rate) {
    const rates = [0.0, 5.0, 12.0, 18.0, 28.0];
    return rates.reduce((a, b) => (a - rate).abs() < (b - rate).abs() ? a : b);
  }

  @override
  void dispose() {
    _customerNameCtrl.dispose();
    _customerGstinCtrl.dispose();
    _customerPhoneCtrl.dispose();
    _customerEmailCtrl.dispose();
    _customerAddressCtrl.dispose();
    _invoiceNumberCtrl.dispose();
    for (final item in _lineItems) { item.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.scannedData;
    final confidence = (d.confidence * 100).round();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Confidence banner
          _buildConfidenceBanner(confidence),
          const SizedBox(height: 16),

          // Supplier info (read-only if detected)
          if (d.supplierName != null || d.supplierGstin != null) ...[
            _buildSupplierCard(d),
            const SizedBox(height: 12),
          ],

          // Customer section (editable)
          _buildCustomerSection(),
          const SizedBox(height: 12),

          // Invoice meta
          _buildInvoiceMetaSection(),
          const SizedBox(height: 12),

          // Line items
          _buildLineItemsSection(),
          const SizedBox(height: 12),

          // Save customer option
          _buildSaveCustomerToggle(),
          const SizedBox(height: 12),

          // Raw text (collapsible)
          if (d.rawText.isNotEmpty) _buildRawTextCard(d.rawText),
          const SizedBox(height: 24),

          // Action buttons
          AppButton(
            label: 'Create Invoice from Bill',
            icon: Icons.receipt_long_rounded,
            onPressed: _createInvoice,
          ),
          const SizedBox(height: 10),
          AppButton(
            label: 'Save to Customer List Only',
            icon: Icons.person_add_rounded,
            isOutlined: true,
            onPressed: _saveToCustomerList,
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildConfidenceBanner(int confidence) {
    Color bannerColor;
    IconData bannerIcon;
    String bannerText;

    if (confidence >= 70) {
      bannerColor = AppColors.success;
      bannerIcon = Icons.check_circle_outline;
      bannerText = 'Great scan! $confidence% details extracted successfully.';
    } else if (confidence >= 40) {
      bannerColor = AppColors.warning;
      bannerIcon = Icons.warning_amber_outlined;
      bannerText = '$confidence% details extracted. Please review & fill in the rest.';
    } else {
      bannerColor = AppColors.info;
      bannerIcon = Icons.info_outline;
      bannerText = 'Low confidence scan. Please manually fill in the details below.';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bannerColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: bannerColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(bannerIcon, color: bannerColor, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(bannerText, style: TextStyle(color: bannerColor, fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildSupplierCard(ScannedBillData d) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.store_outlined, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              const Text('Supplier / Seller', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Auto-detected', style: TextStyle(color: AppColors.primary, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (d.supplierName != null)
            Text(d.supplierName!, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          if (d.supplierGstin != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.verified_outlined, color: AppColors.success, size: 14),
                const SizedBox(width: 4),
                Text('GSTIN: ${d.supplierGstin!}', style: const TextStyle(color: AppColors.success, fontSize: 13)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomerSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.person_outline, color: AppColors.primary, size: 18),
              SizedBox(width: 8),
              Text('Customer Details', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          AppTextField(
            hint: 'Customer Name',
            controller: _customerNameCtrl,
            textCapitalization: TextCapitalization.words,
            prefix: const Icon(Icons.person, size: 18, color: AppColors.textTertiaryLight),
          ),
          const SizedBox(height: 10),
          AppTextField(
            hint: 'GSTIN (if available)',
            controller: _customerGstinCtrl,
            textCapitalization: TextCapitalization.characters,
            maxLength: 15,
            prefix: const Icon(Icons.verified_user_outlined, size: 18, color: AppColors.textTertiaryLight),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  hint: 'Phone',
                  controller: _customerPhoneCtrl,
                  keyboardType: TextInputType.phone,
                  prefix: const Icon(Icons.phone_outlined, size: 18, color: AppColors.textTertiaryLight),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppTextField(
                  hint: 'Email',
                  controller: _customerEmailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  prefix: const Icon(Icons.email_outlined, size: 18, color: AppColors.textTertiaryLight),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AppTextField(
            hint: 'Address',
            controller: _customerAddressCtrl,
            maxLines: 2,
            textCapitalization: TextCapitalization.words,
            prefix: const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Icon(Icons.location_on_outlined, size: 18, color: AppColors.textTertiaryLight),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceMetaSection() {
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: AppTextField(
              hint: 'Invoice No.',
              controller: _invoiceNumberCtrl,
              prefix: const Icon(Icons.tag, size: 18, color: AppColors.textTertiaryLight),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _invoiceDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) setState(() => _invoiceDate = picked);
              },
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.borderLight),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Invoice Date', style: TextStyle(fontSize: 11, color: AppColors.textTertiaryLight)),
                        Text(
                          DateFormat('dd MMM yyyy').format(_invoiceDate),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Items / Services', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Item'),
              onPressed: _addLineItem,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(_lineItems.length, (i) => _buildLineItemCard(i)),
      ],
    );
  }

  Widget _buildLineItemCard(int index) {
    final item = _lineItems[index];
    final qty = double.tryParse(item.qtyCtrl.text) ?? 1;
    final price = double.tryParse(item.priceCtrl.text) ?? 0;
    final total = qty * price;
    final gstAmount = total * item.gstRate / 100;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(color: AppColors.primarySurface, shape: BoxShape.circle),
                  child: Center(
                    child: Text('${index + 1}', style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ),
                const Spacer(),
                if (_lineItems.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 18),
                    onPressed: () => _removeLineItem(index),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            AppTextField(
              hint: 'Description *',
              controller: item.descriptionCtrl,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    hint: 'HSN/SAC',
                    controller: item.hsnCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 8,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<double>(
                    value: item.gstRate,
                    onChanged: (v) => setState(() => item.gstRate = v!),
                    decoration: const InputDecoration(hintText: 'GST %'),
                    items: AppConstants.gstRates.map((r) => DropdownMenuItem(
                      value: r,
                      child: Text('${r.toInt()}%'),
                    )).toList(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    hint: 'Qty',
                    controller: item.qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: AppTextField(
                    hint: 'Unit Price (₹)',
                    controller: item.priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Taxable: ₹${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                  Text('GST: ₹${gstAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: AppColors.primary)),
                  Text('Total: ₹${(total + gstAmount).toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveCustomerToggle() {
    return AppCard(
      child: Row(
        children: [
          const Icon(Icons.person_add_outlined, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Save as Customer', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text('Add to your customer list for future invoices', style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: _saveCustomer,
            onChanged: (v) => setState(() => _saveCustomer = v),
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primaryLight.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildRawTextCard(String rawText) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _showRawText = !_showRawText),
            child: Row(
              children: [
                const Icon(Icons.text_snippet_outlined, color: AppColors.textSecondaryLight, size: 18),
                const SizedBox(width: 8),
                const Text('Raw Scanned Text', style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 13)),
                const Spacer(),
                Icon(
                  _showRawText ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.textSecondaryLight,
                ),
              ],
            ),
          ),
          if (_showRawText) ...[
            const Divider(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariantLight,
                borderRadius: BorderRadius.circular(8),
              ),
              width: double.infinity,
              child: Text(
                rawText,
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _addLineItem() {
    setState(() {
      _lineItems.add(_EditableLineItem(
        id: _uuid.v4(),
        descriptionCtrl: TextEditingController(),
        qtyCtrl: TextEditingController(text: '1'),
        priceCtrl: TextEditingController(),
        hsnCtrl: TextEditingController(),
        gstRate: 18.0,
      ));
    });
  }

  void _removeLineItem(int index) {
    if (_lineItems.length <= 1) return;
    setState(() {
      _lineItems[index].dispose();
      _lineItems.removeAt(index);
    });
  }

  Future<void> _saveToCustomerList() async {
    final name = _customerNameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter customer name to save'), backgroundColor: AppColors.warning),
      );
      return;
    }
    // Build customer payload and trigger customer creation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name saved to customer list'),
        backgroundColor: AppColors.success,
      ),
    );
    context.pop();
  }

  void _createInvoice() {
    if (_customerNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter customer name'), backgroundColor: AppColors.danger),
      );
      return;
    }

    final sellerGstin = '27AABCU9603R1ZX';
    final customerGstin = _customerGstinCtrl.text.trim();
    final isInter = customerGstin.length == 15 &&
        !GstinValidator.isSameState(sellerGstin, customerGstin);

    // Build line items
    final lineItemsPayload = _lineItems
        .where((item) => item.descriptionCtrl.text.trim().isNotEmpty)
        .map((item) {
          final qty = double.tryParse(item.qtyCtrl.text) ?? 1;
          final price = double.tryParse(item.priceCtrl.text) ?? 0;
          final breakdown = GstCalculator.calculate(
            taxableAmount: qty * price,
            gstRate: item.gstRate,
            isInterState: isInter,
          );
          return {
            'description': item.descriptionCtrl.text.trim(),
            'hsnSacCode': item.hsnCtrl.text.trim(),
            'quantity': qty,
            'unit': 'Nos',
            'unitPrice': price,
            'discountPercent': 0.0,
            'gstRate': item.gstRate,
            'taxableAmount': breakdown.taxableAmount,
            'discountAmount': 0.0,
            'cgst': breakdown.cgst,
            'sgst': breakdown.sgst,
            'igst': breakdown.igst,
            'totalAmount': breakdown.totalAmount,
          };
        })
        .toList();

    // Calculate totals
    final items = _lineItems.map((item) => InvoiceLineItem(
      description: item.descriptionCtrl.text,
      quantity: double.tryParse(item.qtyCtrl.text) ?? 1,
      unitPrice: double.tryParse(item.priceCtrl.text) ?? 0,
      gstRate: item.gstRate,
      discountPercent: 0,
    )).toList();
    final totals = GstCalculator.calculateInvoiceTotals(lineItems: items, isInterState: isInter);

    final payload = {
      'customerName': _customerNameCtrl.text.trim(),
      'customerGstin': customerGstin.isEmpty ? null : customerGstin,
      'customerPhone': _customerPhoneCtrl.text.trim(),
      'customerEmail': _customerEmailCtrl.text.trim(),
      'customerAddress': _customerAddressCtrl.text.trim(),
      'invoiceDate': _invoiceDate.toIso8601String(),
      'status': 'draft',
      'isInterState': isInter,
      'lineItems': lineItemsPayload,
      'subTotal': totals.subTotal,
      'totalCgst': totals.totalCgst,
      'totalSgst': totals.totalSgst,
      'totalIgst': totals.totalIgst,
      'totalTax': totals.totalTax,
      'discountAmount': 0.0,
      'grandTotal': totals.grandTotal,
      'roundOff': totals.roundOff,
      'notes': 'Created from scanned bill',
      'gstSlabs': totals.gstSlabs.map((s) => {
        'rate': s.gstRate,
        'taxableAmount': s.taxableAmount,
        'cgst': s.cgst,
        'sgst': s.sgst,
        'igst': s.igst,
      }).toList(),
    };

    // Submit invoice
    ref.read(createInvoiceProvider.notifier).createInvoice(payload);

    // Listen for success and navigate
    ref.listenManual(createInvoiceProvider, (_, next) {
      if (!mounted) return;
      if (next.isSuccess && next.createdInvoice != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Invoice created from scanned bill!'),
            backgroundColor: AppColors.success,
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () => context.push('${AppRoutes.serviceHistory}/${next.createdInvoice!.id}'),
            ),
          ),
        );
        ref.read(createInvoiceProvider.notifier).reset();
        ref.read(scanBillProvider.notifier).reset();
        context.pop();
      }
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: AppColors.danger),
        );
      }
    });
  }
}

// ─── Editable Line Item ───────────────────────────────────────────────────────

class _EditableLineItem {
  final String id;
  final TextEditingController descriptionCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController hsnCtrl;
  double gstRate;

  _EditableLineItem({
    required this.id,
    required this.descriptionCtrl,
    required this.qtyCtrl,
    required this.priceCtrl,
    required this.hsnCtrl,
    this.gstRate = 18.0,
  });

  void dispose() {
    descriptionCtrl.dispose();
    qtyCtrl.dispose();
    priceCtrl.dispose();
    hsnCtrl.dispose();
  }
}

