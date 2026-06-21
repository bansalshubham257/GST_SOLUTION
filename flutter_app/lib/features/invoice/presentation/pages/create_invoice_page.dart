// lib/features/invoice/presentation/pages/create_invoice_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/gst_calculator.dart';
import '../../../../core/utils/gstin_validator.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/barcode_scanner_sheet.dart';
import '../providers/invoice_provider.dart';
import '../providers/item_catalog_provider.dart';
import '../../../customer/presentation/providers/customer_provider.dart';
import '../../../staff/presentation/providers/staff_provider.dart';

class CreateInvoicePage extends ConsumerStatefulWidget {
  final String? invoiceId; // For editing existing invoice

  const CreateInvoicePage({super.key, this.invoiceId});

  @override
  ConsumerState<CreateInvoicePage> createState() => _CreateInvoicePageState();
}

class _CreateInvoicePageState extends ConsumerState<CreateInvoicePage> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  // Customer fields
  final _customerNameController = TextEditingController();
  final _customerGstinController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _customerEmailController = TextEditingController();
  final _customerAddressController = TextEditingController();
  final _notesController = TextEditingController();

  // Invoice meta
  DateTime _invoiceDate = DateTime.now();
  DateTime? _dueDate;
  String? _selectedCustomerId;
  String _paymentMode = 'cash';
  bool _skipCustomerName = false;
  bool _createInvoiceAtEnd = false;
  bool _isFullyPaid = true;
  bool _discountGiven = false;

  // Line items
  final List<_LineItemForm> _lineItems = [];

  bool get _isEditing => widget.invoiceId != null;

  @override
  void initState() {
    super.initState();
    _lineItems.add(_LineItemForm(id: _uuid.v4()));
    if (_isEditing) _loadExistingInvoice();
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerGstinController.dispose();
    _customerPhoneController.dispose();
    _customerEmailController.dispose();
    _customerAddressController.dispose();
    _notesController.dispose();
    for (final item in _lineItems) {
      item.dispose();
    }
    super.dispose();
  }

  void _addLineItem() {
    setState(() {
      _lineItems.add(_LineItemForm(id: _uuid.v4()));
    });
  }

  void _removeLineItem(int index) {
    if (_lineItems.length <= 1) return;
    setState(() {
      _lineItems[index].dispose();
      _lineItems.removeAt(index);
    });
  }

  InvoiceTotals get _currentTotals {
    const sellerGstin = '27AABCU9603R1ZX'; // TODO: Load from business profile
    final isInter = GstinValidator.isValidPan(_customerGstinController.text)
        ? !GstinValidator.isSameState(
            sellerGstin, _customerGstinController.text.trim())
        : false;

    final items = _lineItems
        .map((item) => InvoiceLineItem(
              description: item.descriptionController.text,
              quantity: double.tryParse(item.qtyController.text) ?? 1,
              unitPrice: double.tryParse(item.priceController.text) ?? 0,
              gstRate: item.selectedGstRate,
              discountPercent:
                  double.tryParse(item.discountController.text) ?? 0,
            ))
        .toList();

    return GstCalculator.calculateInvoiceTotals(
      lineItems: items,
      isInterState: isInter,
    );
  }

  double get _totalDiscountAmount => _lineItems.fold(0, (sum, item) {
        final qty = double.tryParse(item.qtyController.text) ?? 1;
        final price = double.tryParse(item.priceController.text) ?? 0;
        final discount = double.tryParse(item.discountController.text) ?? 0;
        return sum + (qty * price * discount / 100);
      });

  @override
  Widget build(BuildContext context) {
    final createState = ref.watch(createInvoiceProvider);

    ref.listen(createInvoiceProvider, (_, next) {
      if (next.isSuccess && next.createdInvoice != null) {
        final invoice = next.createdInvoice!;
        final messenger = ScaffoldMessenger.of(context);
        final router = GoRouter.of(context);
        ref.read(createInvoiceProvider.notifier).reset();
        context.pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Invoice updated!' : 'Invoice created!'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () => router
                  .push('${AppRoutes.serviceHistory}/${invoice.id}'),
            ),
          ),
        );
      }
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.danger,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    final totals = _currentTotals;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Invoice' : 'New Sale'),
        actions: [
          TextButton(
            onPressed: () => _saveDraft(),
            child: const Text('Save Draft'),
          ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: createState.isLoading,
        message: _isEditing ? 'Updating invoice...' : 'Creating invoice...',
        child: Column(
          children: [
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildCustomerSection(),
                    const SizedBox(height: 16),
                    _buildDateSection(),
                    const SizedBox(height: 16),
                    _buildLineItemsSection(),
                    const SizedBox(height: 16),
                    _buildPaymentModeSection(),
                    const SizedBox(height: 16),
                    _buildTotalsSection(totals),
                    const SizedBox(height: 16),
                    _buildFinalSaleOptionsSection(),
                    const SizedBox(height: 16),
                    _buildNotesSection(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
            _buildBottomBar(totals, createState.isLoading),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Customer Details',
                  style: Theme.of(context).textTheme.titleMedium),
              TextButton.icon(
                icon: const Icon(Icons.person_search, size: 16),
                label: const Text('Select'),
                onPressed: _showCustomerPicker,
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppTextField(
            hint: _skipCustomerName
                ? 'Walk-in Customer'
                : 'Customer Name (Optional)',
            controller: _customerNameController,
            readOnly: _skipCustomerName,
            textCapitalization: TextCapitalization.words,
            suffix: TextButton.icon(
              onPressed: () {
                setState(() {
                  _skipCustomerName = !_skipCustomerName;
                  if (_skipCustomerName) {
                    _selectedCustomerId = null;
                    _customerNameController.clear();
                    _customerGstinController.clear();
                    _customerPhoneController.clear();
                    _customerEmailController.clear();
                    _customerAddressController.clear();
                  }
                });
              },
              icon: Icon(
                _skipCustomerName
                    ? Icons.edit_outlined
                    : Icons.person_off_outlined,
                size: 16,
              ),
              label: Text(_skipCustomerName ? 'Add' : 'Skip'),
            ),
          ),
          const SizedBox(height: 10),
          AppTextField(
            hint: 'GSTIN (Optional)',
            controller: _customerGstinController,
            textCapitalization: TextCapitalization.characters,
            maxLength: 15,
            suffix: IconButton(
              icon: const Icon(Icons.verified_outlined, size: 18),
              tooltip: 'Validate GSTIN',
              onPressed: _validateCustomerGstin,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          AppTextField(
            hint: 'Phone',
            controller: _customerPhoneController,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 10),
          AppTextField(
            hint: 'Email',
            controller: _customerEmailController,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 10),
          AppTextField(
            hint: 'Address',
            controller: _customerAddressController,
            maxLines: 2,
            textCapitalization: TextCapitalization.words,
          ),
          if (_customerGstinController.text.length == 15) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.infoLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: AppColors.info, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    GstinValidator.isSameState(
                            '27AABCU9603R1ZX', _customerGstinController.text)
                        ? 'Intra-state → CGST + SGST'
                        : 'Inter-state → IGST',
                    style: const TextStyle(
                        color: AppColors.info,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDateSection() {
    return AppCard(
      child: Row(
        children: [
          Expanded(
              child: _buildDatePicker('Invoice Date', _invoiceDate,
                  (d) => setState(() => _invoiceDate = d))),
          const SizedBox(width: 12),
          Expanded(
              child: _buildDatePicker('Due Date (Optional)', _dueDate,
                  (d) => setState(() => _dueDate = d))),
        ],
      ),
    );
  }

  Widget _buildDatePicker(
      String label, DateTime? date, Function(DateTime) onPick) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null) onPick(picked);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.calendar_today,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                date != null
                    ? DateFormat('dd MMM yyyy').format(date)
                    : 'Not set',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: date == null ? AppColors.textTertiaryLight : null,
                    ),
              ),
            ],
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
            Text('Items / Services',
                style: Theme.of(context).textTheme.titleMedium),
            Row(
              children: [
                // Scan QR / barcode to add item
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner_rounded,
                      color: AppColors.primary, size: 22),
                  tooltip: 'Scan QR / Barcode',
                  onPressed: _scanItemBarcode,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primarySurface,
                    padding: const EdgeInsets.all(8),
                    minimumSize: const Size(36, 36),
                  ),
                ),
                const SizedBox(width: 6),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Item'),
                  onPressed: _addLineItem,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: _lineItems.length,
            itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildLineItemCard(i),
                ),
          ),
      ],
    );
  }

  void _scanItemBarcode() {
    BarcodeScannerSheet.show(
      context,
      onDetected: (value, _) {
        final catalog = ref.read(itemCatalogProvider.notifier);
        final found = catalog.findByBarcode(value);
        if (found != null) {
          // Fill the last empty line item or add a new one
          setState(() {
            final emptyIdx = _lineItems
                .indexWhere((li) => li.descriptionController.text.isEmpty);
            final idx = emptyIdx >= 0 ? emptyIdx : _lineItems.length;
            if (emptyIdx < 0) {
              _lineItems.add(_LineItemForm(
                  id: 'item-${DateTime.now().millisecondsSinceEpoch}'));
            }
            _lineItems[idx].descriptionController.text = found.name;
            _lineItems[idx].priceController.text =
                found.unitPrice.toStringAsFixed(2);
            _lineItems[idx].selectedGstRate = found.gstRate;
            if (found.hsnCode != null) {
              _lineItems[idx].hsnController.text = found.hsnCode!;
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${found.name} added'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Item not in catalog. Add it first.'),
              backgroundColor: AppColors.warning,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      hint: 'Scan item QR code or barcode',
    );
  }

  Widget _buildLineItemCard(int index) {
    final item = _lineItems[index];
    final qty = double.tryParse(item.qtyController.text) ?? 1;
    final price = double.tryParse(item.priceController.text) ?? 0;
    final discount = double.tryParse(item.discountController.text) ?? 0;
    final taxable = qty * price * (1 - discount / 100);
    final gstAmount = taxable * item.selectedGstRate / 100;
    final total = taxable + gstAmount;

    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                    color: AppColors.primarySurface, shape: BoxShape.circle),
                child: Center(
                  child: Text('${index + 1}',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ),
              const Spacer(),
              if (_lineItems.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppColors.danger, size: 20),
                  onPressed: () => _removeLineItem(index),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
            ],
          ),
          const SizedBox(height: 8),
          AppTextField(
            hint: 'Description of goods/service *',
            controller: item.descriptionController,
            textCapitalization: TextCapitalization.sentences,
            validator: (v) => v?.isEmpty == true ? 'Required' : null,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          _buildStaffSelector(index),
          const SizedBox(height: 8),
          AppTextField(
            hint: 'HSN/SAC',
            controller: item.hsnController,
            keyboardType: TextInputType.number,
            maxLength: 8,
          ),
          const SizedBox(height: 8),
          _buildGstRateDropdown(item),
          const SizedBox(height: 8),
          AppTextField(
            hint: 'Qty',
            controller: item.qtyController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            validator: (v) =>
                (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Invalid' : null,
          ),
          const SizedBox(height: 8),
          AppTextField(
            hint: 'Unit Price',
            controller: item.priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            validator: (v) =>
                (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Invalid' : null,
          ),
          const SizedBox(height: 8),
          AppTextField(
            hint: 'Disc %',
            controller: item.discountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
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
                Text('Taxable: ₹${taxable.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondaryLight)),
                Text('GST: ₹${gstAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.primary)),
                Text('Total: ₹${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGstRateDropdown(_LineItemForm item) {
    return DropdownButtonFormField<double>(
      initialValue: item.selectedGstRate,
      onChanged: (v) => setState(() => item.selectedGstRate = v!),
      decoration: const InputDecoration(hintText: 'GST %'),
      items: AppConstants.gstRates
          .map((rate) => DropdownMenuItem(
                value: rate,
                child: Text('${rate.toInt()}%'),
              ))
          .toList(),
    );
  }

  Widget _buildStaffSelector(int index) {
    final item = _lineItems[index];
    final staffAsync = ref.watch(staffListProvider);

    return staffAsync.when(
      data: (staff) => staff.isEmpty
          ? const SizedBox.shrink()
          : DropdownButtonFormField<String>(
              initialValue: item.staffId,
              decoration: const InputDecoration(
                hintText: 'Assign Staff (for commission)',
                prefixIcon: Icon(Icons.person_outline, size: 20),
              ),
              items: staff
                  .map((s) => DropdownMenuItem(
                        value: s.id,
                        child: Text(s.name),
                      ))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  item.staffId = v;
                  item.staffName = staff.firstWhere((s) => s.id == v).name;
                });
              },
            ),
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildTotalsSection(InvoiceTotals totals) {
    return AppCard(
      color: AppColors.primarySurface,
      child: Column(
        children: [
          _buildTotalRow('Sub Total', totals.subTotal),
          if (_totalDiscountAmount > 0)
            _buildTotalRow('Discount', -_totalDiscountAmount,
                color: AppColors.success),
          if (!totals.isInterState) ...[
            _buildTotalRow('CGST', totals.totalCgst,
                color: AppColors.cgstColor),
            _buildTotalRow('SGST', totals.totalSgst,
                color: AppColors.sgstColor),
          ],
          if (totals.isInterState)
            _buildTotalRow('IGST', totals.totalIgst,
                color: AppColors.igstColor),
          if (totals.totalCess > 0)
            _buildTotalRow('Cess', totals.totalCess,
                color: AppColors.cessColor),
          const Divider(),
          _buildTotalRow('Round Off', totals.roundOff),
          const Divider(thickness: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              Text(
                '₹${totals.roundedTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            GstCalculator.numberToWords(totals.roundedTotal),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 14, color: color ?? AppColors.textSecondaryLight)),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentModeSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payment Mode', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildPaymentOption('cash', 'Cash', Icons.money),
              const SizedBox(width: 8),
              _buildPaymentOption('upi', 'UPI', Icons.qr_code_scanner),
              const SizedBox(width: 8),
              _buildPaymentOption('card', 'Card', Icons.credit_card),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinalSaleOptionsSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Final Sale Options',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _isFullyPaid,
            onChanged: (value) => setState(() => _isFullyPaid = value ?? true),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Full paid'),
            subtitle: Text(_isFullyPaid
                ? 'Mark this sale as paid'
                : 'Keep payment pending'),
          ),
          CheckboxListTile(
            value: _discountGiven,
            onChanged: (value) =>
                setState(() => _discountGiven = value ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Discount given'),
            subtitle: Text(
              _totalDiscountAmount > 0
                  ? 'Discount applied: ₹${_totalDiscountAmount.toStringAsFixed(2)}'
                  : 'Use Disc % on item rows when discount is given',
            ),
          ),
          CheckboxListTile(
            value: _createInvoiceAtEnd,
            onChanged: (value) =>
                setState(() => _createInvoiceAtEnd = value ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Create invoice'),
                subtitle: const Text(
                  'Unchecked services are completed without invoice'),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption(String value, String label, IconData icon) {
    final isSelected = _paymentMode == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _paymentMode = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primarySurface : Colors.white,
            border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.borderLight),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondaryLight),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondaryLight,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return AppCard(
      child: AppTextField(
        label: 'Notes / Remarks (Optional)',
        hint: 'Add any notes for the customer...',
        controller: _notesController,
        maxLines: 3,
        textCapitalization: TextCapitalization.sentences,
      ),
    );
  }

  Widget _buildBottomBar(InvoiceTotals totals, bool isLoading) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.borderLight)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Amount',
                    style: Theme.of(context).textTheme.bodySmall),
                Text(
                  '₹${totals.roundedTotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: AppButton(
                label: _isEditing
                    ? 'Update Invoice'
                    : (_createInvoiceAtEnd
                        ? 'Create Invoice'
                        : 'Complete Sale'),
                onPressed: _submitInvoice,
                isLoading: isLoading,
                icon: _createInvoiceAtEnd
                    ? Icons.receipt_long
                    : Icons.point_of_sale,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomerPicker() async {
    // Show bottom sheet to search and select customer
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CustomerPickerSheet(
        onSelected: (customer) {
          setState(() {
            _selectedCustomerId = customer['id'];
            _customerNameController.text = customer['name'] ?? '';
            _customerGstinController.text = customer['gstin'] ?? '';
            _customerPhoneController.text = customer['phone'] ?? '';
            _customerEmailController.text = customer['email'] ?? '';
            _customerAddressController.text = customer['address'] ?? '';
          });
        },
      ),
    );
  }

  void _validateCustomerGstin() {
    final gstin = _customerGstinController.text.trim();
    if (gstin.isEmpty) return;
    final result = GstinValidator.validate(gstin);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.isValid
            ? '✅ Valid GSTIN (State: ${result.stateCode})'
            : '❌ ${result.error}'),
        backgroundColor: result.isValid ? AppColors.success : AppColors.danger,
      ),
    );
  }

  void _saveDraft() {
    // Save to local storage as draft
    LocalStorage.saveDraft('draft_${DateTime.now().millisecondsSinceEpoch}',
        _buildInvoicePayload(isDraft: true));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Draft saved'), backgroundColor: AppColors.success),
    );
  }

  void _submitInvoice() {
    if (!_formKey.currentState!.validate()) return;

    if (_discountGiven && _totalDiscountAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Add discount % on item rows or uncheck Discount given'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (!_createInvoiceAtEnd && !_isEditing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sale completed without invoice'),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
      return;
    }

    final payload = _buildInvoicePayload();
    if (_isEditing) {
      ref
          .read(createInvoiceProvider.notifier)
          .updateInvoice(widget.invoiceId!, payload);
    } else {
      ref.read(createInvoiceProvider.notifier).createInvoice(payload);
    }
  }

  Map<String, dynamic> _buildInvoicePayload({bool isDraft = false}) {
    final totals = _currentTotals;
    const sellerGstin = '27AABCU9603R1ZX'; // TODO: Load from business
    final customerGstin = _customerGstinController.text.trim();
    final isInter = customerGstin.length == 15 &&
        !GstinValidator.isSameState(sellerGstin, customerGstin);

    return {
      'customerId': _selectedCustomerId,
      'customerName': _customerNameController.text.trim().isEmpty
          ? 'Walk-in Customer'
          : _customerNameController.text.trim(),
      'customerGstin': customerGstin.isEmpty ? null : customerGstin,
      'customerPhone': _customerPhoneController.text.trim(),
      'customerEmail': _customerEmailController.text.trim(),
      'customerAddress': _customerAddressController.text.trim(),
      'invoiceDate': _invoiceDate.toIso8601String(),
      'dueDate': _dueDate?.toIso8601String(),
      'status': isDraft ? 'draft' : (_isFullyPaid ? 'paid' : 'sent'),
      'paymentStatus': isDraft ? 'unpaid' : (_isFullyPaid ? 'paid' : 'unpaid'),
      'paymentMode': _paymentMode,
      'isInterState': isInter,
      'lineItems': _lineItems.map((item) {
        final qty = double.tryParse(item.qtyController.text) ?? 1;
        final price = double.tryParse(item.priceController.text) ?? 0;
        final discount = double.tryParse(item.discountController.text) ?? 0;
        final breakdown = GstCalculator.calculate(
          taxableAmount: qty * price * (1 - discount / 100),
          gstRate: item.selectedGstRate,
          isInterState: isInter,
        );
        return {
          'description': item.descriptionController.text.trim(),
          'staffId': item.staffId,
          'staffName': item.staffName,
          'hsnSacCode': item.hsnController.text.trim(),
          'quantity': qty,
          'unit': 'Nos',
          'unitPrice': price,
          'discountPercent': discount,
          'gstRate': item.selectedGstRate,
          'taxableAmount': breakdown.taxableAmount,
          'discountAmount': qty * price * discount / 100,
          'cgst': breakdown.cgst,
          'sgst': breakdown.sgst,
          'igst': breakdown.igst,
          'totalAmount': breakdown.totalAmount,
        };
      }).toList(),
      'subTotal': totals.subTotal,
      'totalCgst': totals.totalCgst,
      'totalSgst': totals.totalSgst,
      'totalIgst': totals.totalIgst,
      'totalTax': totals.totalTax,
      'discountAmount': _totalDiscountAmount,
      'grandTotal': totals.grandTotal,
      'roundOff': totals.roundOff,
      'notes': _notesController.text.trim(),
      'gstSlabs': totals.gstSlabs
          .map((s) => {
                'rate': s.gstRate,
                'taxableAmount': s.taxableAmount,
                'cgst': s.cgst,
                'sgst': s.sgst,
                'igst': s.igst,
              })
          .toList(),
    };
  }

  void _loadExistingInvoice() {
    // TODO: Load data from invoiceDetailProvider(widget.invoiceId!) and populate fields
  }
}

// ─── Line Item Form Model ─────────────────────────────────────────────────────

class _LineItemForm {
  final String id;
  String? staffId;
  String? staffName;
  final TextEditingController descriptionController;
  final TextEditingController hsnController;
  final TextEditingController qtyController;
  final TextEditingController priceController;
  final TextEditingController discountController;
  double selectedGstRate;

  _LineItemForm({required this.id})
      : descriptionController = TextEditingController(),
        hsnController = TextEditingController(),
        qtyController = TextEditingController(text: '1'),
        priceController = TextEditingController(),
        discountController = TextEditingController(text: '0'),
        selectedGstRate = 18;

  void dispose() {
    descriptionController.dispose();
    hsnController.dispose();
    qtyController.dispose();
    priceController.dispose();
    discountController.dispose();
  }
}

// ─── Customer Picker Sheet ────────────────────────────────────────────────────

class _CustomerPickerSheet extends ConsumerStatefulWidget {
  final Function(Map<String, dynamic>) onSelected;

  const _CustomerPickerSheet({required this.onSelected});

  @override
  ConsumerState<_CustomerPickerSheet> createState() =>
      _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends ConsumerState<_CustomerPickerSheet> {
  final _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customerListProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AppTextField(
              hint: 'Search customers...',
              controller: _searchController,
              prefix: const Icon(Icons.search, size: 20),
              onChanged: (q) =>
                  ref.read(customerListProvider.notifier).search(q),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: customers.when(
              data: (list) => ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primarySurface,
                    child: Text(list[i].name[0].toUpperCase(),
                        style: const TextStyle(color: AppColors.primary)),
                  ),
                  title: Text(list[i].name),
                  subtitle: Text(list[i].gstin ?? list[i].phone ?? ''),
                  onTap: () {
                    widget.onSelected({
                      'id': list[i].id,
                      'name': list[i].name,
                      'gstin': list[i].gstin,
                      'phone': list[i].phone,
                      'email': list[i].email,
                      'address': list[i].address,
                    });
                    Navigator.pop(context);
                  },
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const EmptyState(
                icon: Icons.people_outline,
                title: 'No customers',
                subtitle: 'Add customers first',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
