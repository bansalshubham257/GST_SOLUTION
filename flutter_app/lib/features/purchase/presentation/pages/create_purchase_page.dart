import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/gst_calculator.dart';
import '../../../../core/utils/gstin_validator.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../providers/purchase_provider.dart';

class CreatePurchasePage extends ConsumerStatefulWidget {
  final String? purchaseId;

  const CreatePurchasePage({super.key, this.purchaseId});

  @override
  ConsumerState<CreatePurchasePage> createState() => _CreatePurchasePageState();
}

class _CreatePurchasePageState extends ConsumerState<CreatePurchasePage> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  final _supplierNameController = TextEditingController();
  final _supplierGstinController = TextEditingController();
  final _supplierPhoneController = TextEditingController();
  final _supplierEmailController = TextEditingController();
  final _supplierAddressController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _invoiceDate = DateTime.now();
  DateTime? _dueDate;
  bool _paymentStatus = false;
  bool _isPaid = false;

  final List<_PurchaseLineItemForm> _lineItems = [];

  bool get _isEditing => widget.purchaseId != null;

  @override
  void initState() {
    super.initState();
    _lineItems.add(_PurchaseLineItemForm(id: _uuid.v4()));
    if (_isEditing) _loadExistingPurchase();
  }

  @override
  void dispose() {
    _supplierNameController.dispose();
    _supplierGstinController.dispose();
    _supplierPhoneController.dispose();
    _supplierEmailController.dispose();
    _supplierAddressController.dispose();
    _notesController.dispose();
    for (final item in _lineItems) {
      item.dispose();
    }
    super.dispose();
  }

  void _addLineItem() {
    setState(() {
      _lineItems.add(_PurchaseLineItemForm(id: _uuid.v4()));
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
    const businessGstin = '27AABCU9603R1ZX';
    final supplierGstin = _supplierGstinController.text.trim();
    final isInter = supplierGstin.length == 15
        ? !GstinValidator.isSameState(businessGstin, supplierGstin)
        : false;

    final items = _lineItems
        .map((item) => InvoiceLineItem(
              description: item.descriptionController.text,
              quantity: double.tryParse(item.qtyController.text) ?? 1,
              unitPrice: double.tryParse(item.priceController.text) ?? 0,
              gstRate: item.selectedGstRate,
              discountPercent: double.tryParse(item.discountController.text) ?? 0,
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
    final createState = ref.watch(createPurchaseProvider);

    ref.listen(createPurchaseProvider, (_, next) {
      if (next.isSuccess && next.createdPurchase != null) {
        final purchase = next.createdPurchase!;
        final messenger = ScaffoldMessenger.of(context);
        final router = GoRouter.of(context);
        ref.read(createPurchaseProvider.notifier).reset();
        context.pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Purchase updated!' : 'Purchase created!'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () => router.push('/purchases/${purchase.id}'),
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
        title: Text(_isEditing ? 'Edit Purchase' : 'New Purchase'),
        actions: [
          TextButton(
            onPressed: () => _saveDraft(),
            child: const Text('Save Draft'),
          ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: createState.isLoading,
        message: _isEditing ? 'Updating purchase...' : 'Creating purchase...',
        child: Column(
          children: [
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSupplierSection(),
                    const SizedBox(height: 16),
                    _buildDateSection(),
                    const SizedBox(height: 16),
                    _buildLineItemsSection(),
                    const SizedBox(height: 16),
                    _buildPaymentStatusSection(),
                    const SizedBox(height: 16),
                    _buildTotalsSection(totals),
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

  Widget _buildSupplierSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Supplier Details', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          AppTextField(
            hint: 'Supplier Name *',
            controller: _supplierNameController,
            textCapitalization: TextCapitalization.words,
            validator: (v) => v?.isEmpty == true ? 'Required' : null,
          ),
          const SizedBox(height: 10),
          AppTextField(
            hint: 'Supplier GSTIN (Optional)',
            controller: _supplierGstinController,
            textCapitalization: TextCapitalization.characters,
            maxLength: 15,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          AppTextField(
            hint: 'Phone',
            controller: _supplierPhoneController,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 10),
          AppTextField(
            hint: 'Email',
            controller: _supplierEmailController,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 10),
          AppTextField(
            hint: 'Address',
            controller: _supplierAddressController,
            maxLines: 2,
            textCapitalization: TextCapitalization.words,
          ),
          if (_supplierGstinController.text.length == 15) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.infoLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.info, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    GstinValidator.isSameState('27AABCU9603R1ZX', _supplierGstinController.text)
                        ? 'Intra-state CGST + SGST'
                        : 'Inter-state IGST',
                    style: const TextStyle(color: AppColors.info, fontSize: 12, fontWeight: FontWeight.w500),
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

  Widget _buildDatePicker(String label, DateTime? date, Function(DateTime) onPick) {
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
              const Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                date != null ? DateFormat('dd MMM yyyy').format(date) : 'Not set',
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
            Text('Items / Services', style: Theme.of(context).textTheme.titleMedium),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Item'),
              onPressed: _addLineItem,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(
            _lineItems.length,
            (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildLineItemCard(i),
                )),
      ],
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
                decoration: const BoxDecoration(color: AppColors.primarySurface, shape: BoxShape.circle),
                child: Center(
                  child: Text('${index + 1}',
                      style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
              const Spacer(),
              if (_lineItems.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                  onPressed: () => _removeLineItem(index),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
          AppTextField(
            hint: 'HSN/SAC',
            controller: item.hsnController,
            keyboardType: TextInputType.number,
            maxLength: 8,
          ),
          const SizedBox(height: 8),
          _buildGstRateDropdown(item),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  hint: 'Qty',
                  controller: item.qtyController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Invalid' : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppTextField(
                  hint: 'Unit Price',
                  controller: item.priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Invalid' : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppTextField(
                  hint: 'Disc %',
                  controller: item.discountController,
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
              children: [
                Expanded(
                  child: Text('Taxable: ₹${taxable.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text('GST: ₹${gstAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 11, color: AppColors.primary),
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text('Total: ₹${total.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGstRateDropdown(_PurchaseLineItemForm item) {
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

  Widget _buildPaymentStatusSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payment Status', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _paymentStatus = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: !_paymentStatus ? AppColors.primarySurface : Colors.white,
                      border: Border.all(
                          color: !_paymentStatus ? AppColors.primary : AppColors.borderLight),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.pending_outlined,
                            color: !_paymentStatus ? AppColors.primary : AppColors.textSecondaryLight),
                        const SizedBox(height: 4),
                        Text('Unpaid',
                            style: TextStyle(
                              color: !_paymentStatus ? AppColors.primary : AppColors.textSecondaryLight,
                              fontWeight: !_paymentStatus ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 12,
                            )),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _paymentStatus = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _paymentStatus ? AppColors.successLight : Colors.white,
                      border: Border.all(
                          color: _paymentStatus ? AppColors.success : AppColors.borderLight),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.check_circle_outline,
                            color: _paymentStatus ? AppColors.success : AppColors.textSecondaryLight),
                        const SizedBox(height: 4),
                        Text('Paid',
                            style: TextStyle(
                              color: _paymentStatus ? AppColors.success : AppColors.textSecondaryLight,
                              fontWeight: _paymentStatus ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 12,
                            )),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsSection(InvoiceTotals totals) {
    return AppCard(
      color: AppColors.primarySurface,
      child: Column(
        children: [
          _buildTotalRow('Sub Total', totals.subTotal),
          if (_totalDiscountAmount > 0)
            _buildTotalRow('Discount', -_totalDiscountAmount, color: AppColors.success),
          if (!totals.isInterState) ...[
            _buildTotalRow('CGST', totals.totalCgst, color: AppColors.cgstColor),
            _buildTotalRow('SGST', totals.totalSgst, color: AppColors.sgstColor),
          ],
          if (totals.isInterState)
            _buildTotalRow('IGST', totals.totalIgst, color: AppColors.igstColor),
          if (totals.totalCess > 0)
            _buildTotalRow('Cess', totals.totalCess, color: AppColors.cessColor),
          const Divider(),
          _buildTotalRow('Round Off', totals.roundOff),
          const Divider(thickness: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              Text(
                '₹${totals.roundedTotal.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            GstCalculator.numberToWords(totals.roundedTotal),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
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
              style: TextStyle(fontSize: 14, color: color ?? AppColors.textSecondaryLight)),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return AppCard(
      child: AppTextField(
        label: 'Notes / Remarks (Optional)',
        hint: 'Add any notes...',
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
                Text('Total Amount', style: Theme.of(context).textTheme.bodySmall),
                Text(
                  '₹${totals.roundedTotal.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: AppButton(
                label: _isEditing ? 'Update Purchase' : 'Save Purchase',
                onPressed: _submitPurchase,
                isLoading: isLoading,
                icon: Icons.shopping_cart,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveDraft() {
    LocalStorage.saveDraft('purchase_draft_${DateTime.now().millisecondsSinceEpoch}',
        _buildPurchasePayload(isDraft: true));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Draft saved'), backgroundColor: AppColors.success),
    );
  }

  void _submitPurchase() {
    if (!_formKey.currentState!.validate()) return;

    if (_supplierNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Supplier name is required'), backgroundColor: AppColors.warning),
      );
      return;
    }

    final payload = _buildPurchasePayload();
    ref.read(createPurchaseProvider.notifier).createPurchase(payload);
  }

  Map<String, dynamic> _buildPurchasePayload({bool isDraft = false}) {
    final totals = _currentTotals;
    const businessGstin = '27AABCU9603R1ZX';
    final supplierGstin = _supplierGstinController.text.trim();
    final isInter = supplierGstin.length == 15 &&
        !GstinValidator.isSameState(businessGstin, supplierGstin);

    return {
      'supplierName': _supplierNameController.text.trim(),
      'supplierGstin': supplierGstin.isEmpty ? null : supplierGstin,
      'supplierPhone': _supplierPhoneController.text.trim(),
      'supplierEmail': _supplierEmailController.text.trim(),
      'supplierAddress': _supplierAddressController.text.trim(),
      'invoiceDate': _invoiceDate.toIso8601String(),
      'dueDate': _dueDate?.toIso8601String(),
      'status': isDraft ? 'draft' : (_paymentStatus ? 'paid' : 'pending'),
      'paymentStatus': _paymentStatus ? 'paid' : 'unpaid',
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

  void _loadExistingPurchase() {
    // TODO: Load data from purchaseDetailProvider and populate fields
  }
}

class _PurchaseLineItemForm {
  final String id;
  final TextEditingController descriptionController;
  final TextEditingController hsnController;
  final TextEditingController qtyController;
  final TextEditingController priceController;
  final TextEditingController discountController;
  double selectedGstRate;

  _PurchaseLineItemForm({required this.id})
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
