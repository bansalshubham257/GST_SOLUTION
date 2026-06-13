// lib/features/invoice/presentation/pages/quick_scan_bill_page.dart
//
// Supermarket-style QR / barcode scanner.
// User scans items → cart fills up → tap "Generate Bill" → invoice created.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/gst_calculator.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/barcode_scanner_sheet.dart';
import '../providers/invoice_provider.dart';
import '../providers/item_catalog_provider.dart';
import '../../data/models/item_catalog_entry.dart';
import '../../domain/entities/invoice_entity.dart';
import '../../../customer/presentation/providers/customer_provider.dart';

// ─── Cart Item Model ──────────────────────────────────────────────────────────

class _CartItem {
  final String cartId;
  final ItemCatalogEntry item;
  double quantity;

  _CartItem({required this.item, this.quantity = 1.0})
      : cartId = const Uuid().v4().substring(0, 8);

  double get subtotal => item.unitPrice * quantity;
  double get gstAmount => subtotal * item.gstRate / 100;
  double get total => subtotal + gstAmount;
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class QuickScanBillPage extends ConsumerStatefulWidget {
  const QuickScanBillPage({super.key});

  @override
  ConsumerState<QuickScanBillPage> createState() => _QuickScanBillPageState();
}

class _QuickScanBillPageState extends ConsumerState<QuickScanBillPage>
    with SingleTickerProviderStateMixin {
  final List<_CartItem> _cart = [];
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();

  late final AnimationController _addAnimController;
  String? _lastScannedName;
  bool _scannerActive = false;
  String? _notFoundBarcode;
  bool _dialogShowing = false;        // guard: prevent stacking dialogs
  DateTime? _lastInlineScanTime;      // debounce inline scanner

  // Inline scanner controller (for the embedded scanner card)
  MobileScannerController? _inlineScannerController;

  @override
  void initState() {
    super.initState();
    _addAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _addAnimController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _inlineScannerController?.dispose();
    super.dispose();
  }

  // ─── Cart helpers ────────────────────────────────────────────────────────

  void _addOrIncrement(ItemCatalogEntry item) {
    HapticFeedback.mediumImpact();
    setState(() {
      final existing = _cart.where((c) => c.item.id == item.id);
      if (existing.isNotEmpty) {
        existing.first.quantity += 1;
      } else {
        _cart.insert(0, _CartItem(item: item));
      }
      _lastScannedName = item.name;
      _notFoundBarcode = null;
    });
    _addAnimController
      ..reset()
      ..forward();
    // Clear the "last scanned" label after 2 s
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _lastScannedName = null);
    });
  }

  void _removeItem(int index) {
    HapticFeedback.lightImpact();
    setState(() => _cart.removeAt(index));
  }

  void _changeQty(int index, double newQty) {
    if (newQty <= 0) {
      _removeItem(index);
    } else {
      setState(() => _cart[index].quantity = newQty);
    }
  }

  double get _grandTotal => _cart.fold(0, (s, c) => s + c.total);
  double get _totalGst => _cart.fold(0, (s, c) => s + c.gstAmount);
  double get _subtotal => _cart.fold(0, (s, c) => s + c.subtotal);

  // ─── Scan helpers ────────────────────────────────────────────────────────

  void _onBarcodeDetected(String value, BarcodeFormat format) {
    final catalog = ref.read(itemCatalogProvider.notifier);
    final item = catalog.findByBarcode(value);
    if (item != null) {
      _addOrIncrement(item);
    } else {
      // Try to parse our own QR format even without a catalog entry
      final parsed = ItemCatalogNotifier.parseFromQr(value);
      if (parsed != null) {
        _addOrIncrement(parsed);
      } else {
        HapticFeedback.heavyImpact();
        setState(() => _notFoundBarcode = value);
        _showUnknownBarcodeDialog(value);
      }
    }
  }

  Future<void> _openScannerSheet() async {
    await BarcodeScannerSheet.show(
      context,
      onDetected: _onBarcodeDetected,
      hint: 'Scan item QR / barcode to add to cart',
    );
  }

  void _toggleInlineScanner() {
    setState(() {
      _scannerActive = !_scannerActive;
      if (_scannerActive) {
        _inlineScannerController = MobileScannerController(
          detectionSpeed: DetectionSpeed.noDuplicates,
        );
      } else {
        _inlineScannerController?.dispose();
        _inlineScannerController = null;
      }
    });
  }

  void _showUnknownBarcodeDialog(String barcode) {
    // Guard: only one sheet at a time
    if (_dialogShowing) return;
    setState(() => _dialogShowing = true);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (ctx) => _QuickAddItemSheet(
        barcode: barcode,
        onItemAdded: (item) {
          Navigator.of(ctx).pop();
          _addOrIncrement(item);
        },
        onDismiss: () => Navigator.of(ctx).pop(),
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _dialogShowing = false);
    });
  }

  // ─── Invoice generation ──────────────────────────────────────────────────

  void _generateBill() {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cart is empty — scan some items first'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final customerName = _customerNameController.text.trim();

    _showBillPreviewSheet(customerName);
  }

  void _showBillPreviewSheet(String customerName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BillPreviewSheet(
        cart: _cart,
        customerName: customerName,
        customerPhone: _customerPhoneController.text.trim(),
        onConfirm: (name, phone) => _submitInvoice(name, phone),
      ),
    );
  }

  Future<void> _submitInvoice(String customerName, String customerPhone) async {
    const sellerGstin = '27AABCU9603R1ZX';
    const isInter = false;

    final lineItemsPayload = _cart.map((c) {
      final breakdown = GstCalculator.calculate(
        taxableAmount: c.subtotal,
        gstRate: c.item.gstRate,
        isInterState: isInter,
      );
      return {
        'description': c.item.name,
        'hsnSacCode': c.item.hsnCode ?? '',
        'quantity': c.quantity,
        'unit': c.item.unit,
        'unitPrice': c.item.unitPrice,
        'discountPercent': 0.0,
        'gstRate': c.item.gstRate,
        'taxableAmount': breakdown.taxableAmount,
        'discountAmount': 0.0,
        'cgst': breakdown.cgst,
        'sgst': breakdown.sgst,
        'igst': breakdown.igst,
        'totalAmount': breakdown.totalAmount,
      };
    }).toList();

    final items = _cart.map((c) => InvoiceLineItem(
      description: c.item.name,
      quantity: c.quantity,
      unitPrice: c.item.unitPrice,
      gstRate: c.item.gstRate,
      discountPercent: 0,
    )).toList();

    final totals = GstCalculator.calculateInvoiceTotals(
      lineItems: items,
      isInterState: isInter,
    );

    final payload = {
      'customerName': customerName.isEmpty ? 'Walk-in Customer' : customerName,
      'customerPhone': customerPhone,
      'customerGstin': null,
      'customerEmail': '',
      'customerAddress': '',
      'invoiceDate': DateTime.now().toIso8601String(),
      'status': 'sent',
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
      'notes': 'Created via Quick Scan',
      'gstSlabs': totals.gstSlabs.map((s) => {
        'rate': s.gstRate,
        'taxableAmount': s.taxableAmount,
        'cgst': s.cgst,
        'sgst': s.sgst,
        'igst': s.igst,
      }).toList(),
    };

    ref.read(createInvoiceProvider.notifier).createInvoice(payload);

    ref.listenManual(createInvoiceProvider, (_, next) {
      if (!mounted) return;
      if (next.isSuccess && next.createdInvoice != null) {
        setState(() => _cart.clear());
        ref.read(createInvoiceProvider.notifier).reset();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Invoice created!'),
            backgroundColor: AppColors.success,
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () =>
                  context.push('${AppRoutes.serviceHistory}/${next.createdInvoice!.id}'),
            ),
          ),
        );
        context.pop(); // close preview sheet
      }
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: AppColors.danger),
        );
      }
    });
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Quick Scan & Bill'),
        actions: [
          // Scan shortcut in AppBar — always visible
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Scan item',
            onPressed: _openScannerSheet,
          ),
          if (_cart.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: TextButton.icon(
                icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                label: const Text('Clear'),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Clear Cart?'),
                    content: const Text('Remove all scanned items?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                      ElevatedButton(
                        onPressed: () { Navigator.pop(context); setState(() => _cart.clear()); },
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Inline scanner view (shown when active)
          if (_scannerActive && _inlineScannerController != null)
            _buildInlineScannerView()
          else
            // Compact scan bar — always visible at top
            _buildCompactScanBar(),

          // Last scanned banner
          if (_lastScannedName != null)
            _ScannedBanner(name: _lastScannedName!, controller: _addAnimController),

          // Cart
          Expanded(
            child: _cart.isEmpty
                ? _buildEmptyCart()
                : _buildCartList(),
          ),
        ],
      ),
      // FAB — scan more, always accessible even when reviewing cart
      floatingActionButton: _cart.isNotEmpty && !_scannerActive
          ? FloatingActionButton.extended(
              onPressed: _openScannerSheet,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Scan More', style: TextStyle(fontWeight: FontWeight.w700)),
            )
          : null,
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildInlineScannerView() {
    return Container(
      height: 220,
      color: Colors.black,
      child: Stack(
        children: [
            MobileScanner(
              controller: _inlineScannerController!,
              onDetect: (capture) {
                final raw = capture.barcodes.firstOrNull?.rawValue;
                if (raw == null || raw.isEmpty) return;
                // Debounce: ignore if same scan within 2 seconds
                final now = DateTime.now();
                if (_lastInlineScanTime != null &&
                    now.difference(_lastInlineScanTime!).inMilliseconds < 2000) return;
                _lastInlineScanTime = now;
                _onBarcodeDetected(raw, capture.barcodes.first.format);
              },
            ),
          Center(
            child: Container(
              width: 200,
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.greenAccent, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: _toggleInlineScanner,
            ),
          ),
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Point at item QR / barcode',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Compact always-visible scan bar at the top of the page
  Widget _buildCompactScanBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: _cart.isEmpty
          // Empty cart: show full 3-button row
          ? Row(
              children: [
                Expanded(
                  child: _ScanActionButton(
                    icon: Icons.center_focus_strong_rounded,
                    label: 'Inline Scan',
                    subtitle: 'Camera always on',
                    color: AppColors.primary,
                    onTap: _toggleInlineScanner,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ScanActionButton(
                    icon: Icons.qr_code_scanner_rounded,
                    label: 'Scan Now',
                    subtitle: 'Single scan',
                    color: AppColors.secondary,
                    onTap: _openScannerSheet,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ScanActionButton(
                    icon: Icons.list_alt_rounded,
                    label: 'Catalog',
                    subtitle: 'Pick from list',
                    color: const Color(0xFF7C3AED),
                    onTap: _showCatalogPicker,
                  ),
                ),
              ],
            )
          // Cart has items: show compact horizontal scan strip
          : Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _openScannerSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary, size: 20),
                          SizedBox(width: 8),
                          Text('Scan Next Item', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _toggleInlineScanner,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.secondarySurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.center_focus_strong_rounded, color: AppColors.secondary, size: 22),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _showCatalogPicker,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.list_alt_rounded, color: Color(0xFF7C3AED), size: 22),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary, size: 40),
          ),
          const SizedBox(height: 16),
          const Text(
            'Cart is Empty',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Scan item QR codes or barcodes\nto add them to the bill',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _openScannerSheet,
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text('Start Scanning'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartList() {
    return Column(
      children: [
        // Customer name row
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customerNameController,
                  decoration: InputDecoration(
                    hintText: 'Customer name (optional)',
                    prefixIcon: const Icon(Icons.person_outline, size: 18),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    isDense: true,
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 130,
                child: TextField(
                  controller: _customerPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: 'Phone',
                    prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Text(
                '${_cart.length} item${_cart.length == 1 ? '' : 's'}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const Spacer(),
              Text('GST: ₹${_totalGst.toStringAsFixed(2)}',
                  style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 12)),
            ],
          ),
        ),
        // Items
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _cart.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (_, i) => _CartItemTile(
              cartItem: _cart[i],
              index: i,
              onRemove: () => _removeItem(i),
              onQtyChanged: (q) => _changeQty(i, q),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    final createState = ref.watch(createInvoiceProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.borderLight)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_cart.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Subtotal', style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 13)),
                  Text('₹${_subtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('GST', style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 13)),
                  Text('₹${_totalGst.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, color: AppColors.primary)),
                ],
              ),
              const Divider(height: 12),
            ],
            Row(
              children: [
                // Total amount
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Total', style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                    Text(
                      '₹${_grandTotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: AppButton(
                    label: 'Generate Bill',
                    icon: Icons.receipt_long_rounded,
                    onPressed: _generateBill,
                    isLoading: createState.isLoading,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCatalogPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CatalogPickerSheet(
        onItemSelected: _addOrIncrement,
      ),
    );
  }
}

// ─── Scanned Banner ───────────────────────────────────────────────────────────

class _ScannedBanner extends StatelessWidget {
  final String name;
  final AnimationController controller;

  const _ScannedBanner({required this.name, required this.controller});

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -1),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOut)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: AppColors.success.withOpacity(0.1),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: AppColors.success, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '✅ Added: $name',
                style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Cart Item Tile ───────────────────────────────────────────────────────────

class _CartItemTile extends StatelessWidget {
  final _CartItem cartItem;
  final int index;
  final VoidCallback onRemove;
  final void Function(double) onQtyChanged;

  const _CartItemTile({
    required this.cartItem,
    required this.index,
    required this.onRemove,
    required this.onQtyChanged,
  });

  @override
  Widget build(BuildContext context) {
    final item = cartItem.item;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Number badge
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: AppColors.primarySurface,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text('${index + 1}',
                    style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 10),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text('₹${item.unitPrice.toStringAsFixed(2)} / ${item.unit}',
                          style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 12)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.accentSurface,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('${item.gstRate.toInt()}% GST',
                            style: const TextStyle(color: AppColors.accentDark, fontSize: 10, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Qty stepper
            _QtyStepper(
              qty: cartItem.quantity,
              onChanged: onQtyChanged,
            ),
            const SizedBox(width: 10),
            // Total
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('₹${cartItem.total.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primary)),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 18),
                  onPressed: onRemove,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Qty Stepper ─────────────────────────────────────────────────────────────

class _QtyStepper extends StatelessWidget {
  final double qty;
  final void Function(double) onChanged;

  const _QtyStepper({required this.qty, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderLight),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepBtn(Icons.remove, () => onChanged(qty - 1), color: qty <= 1 ? AppColors.danger : AppColors.primary),
          SizedBox(
            width: 36,
            child: Text(
              qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toStringAsFixed(1),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
          _stepBtn(Icons.add, () => onChanged(qty + 1), color: AppColors.primary),
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap, {required Color color}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

// ─── Scan Action Button ───────────────────────────────────────────────────────

class _ScanActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ScanActionButton({
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(color: color.withOpacity(0.7), fontSize: 10), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ─── Bill Preview Sheet ───────────────────────────────────────────────────────

class _BillPreviewSheet extends ConsumerStatefulWidget {
  final List<_CartItem> cart;
  final String customerName;
  final String customerPhone;
  final void Function(String name, String phone) onConfirm;

  const _BillPreviewSheet({
    required this.cart,
    required this.customerName,
    required this.customerPhone,
    required this.onConfirm,
  });

  @override
  ConsumerState<_BillPreviewSheet> createState() => _BillPreviewSheetState();
}

class _BillPreviewSheetState extends ConsumerState<_BillPreviewSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.customerName);
    _phoneCtrl = TextEditingController(text: widget.customerPhone);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = widget.cart.fold<double>(0, (s, c) => s + c.subtotal);
    final gst = widget.cart.fold<double>(0, (s, c) => s + c.gstAmount);
    final total = widget.cart.fold<double>(0, (s, c) => s + c.total);

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.receipt_long_rounded, color: AppColors.primary),
                SizedBox(width: 8),
                Text('Bill Preview', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const Divider(height: 20),

          // Customer fields
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      hintText: 'Customer name',
                      prefixIcon: const Icon(Icons.person_outline, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 130,
                  child: TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: 'Phone',
                      prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Items list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.cart.length,
              itemBuilder: (_, i) {
                final c = widget.cart[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.item.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                            Text(
                              '${c.quantity} × ₹${c.item.unitPrice.toStringAsFixed(2)} + ${c.item.gstRate.toInt()}% GST',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                            ),
                          ],
                        ),
                      ),
                      Text('₹${c.total.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                );
              },
            ),
          ),

          // Totals
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _totalRow('Subtotal', subtotal),
                _totalRow('GST', gst, color: AppColors.primary),
                const Divider(height: 12),
                _totalRow('Total', total, large: true),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Confirm button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AppButton(
              label: 'Confirm & Create Invoice',
              icon: Icons.check_circle_outline_rounded,
              onPressed: () => widget.onConfirm(_nameCtrl.text.trim(), _phoneCtrl.text.trim()),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double amount, {Color? color, bool large = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            fontSize: large ? 15 : 13,
            fontWeight: large ? FontWeight.w700 : FontWeight.normal,
            color: color ?? AppColors.textSecondaryLight,
          )),
          Text('₹${amount.toStringAsFixed(2)}', style: TextStyle(
            fontSize: large ? 17 : 13,
            fontWeight: large ? FontWeight.w800 : FontWeight.w500,
            color: color ?? (large ? AppColors.primary : null),
          )),
        ],
      ),
    );
  }
}

// ─── Catalog Picker Sheet ─────────────────────────────────────────────────────

class _CatalogPickerSheet extends ConsumerStatefulWidget {
  final void Function(ItemCatalogEntry) onItemSelected;

  const _CatalogPickerSheet({required this.onItemSelected});

  @override
  ConsumerState<_CatalogPickerSheet> createState() => _CatalogPickerSheetState();
}

class _CatalogPickerSheetState extends ConsumerState<_CatalogPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allItems = ref.watch(itemCatalogProvider);
    final filtered = _query.isEmpty
        ? allItems
        : allItems.where((i) => i.name.toLowerCase().contains(_query.toLowerCase())).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (q) => setState(() => _query = q),
              decoration: InputDecoration(
                hintText: 'Search items...',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: allItems.isEmpty
                ? const Center(child: Text('No items in catalog.\nAdd items first.', textAlign: TextAlign.center))
                : filtered.isEmpty
                    ? const Center(child: Text('No items match'))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final item = filtered[i];
                          return ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.primarySurface,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 20),
                            ),
                            title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('₹${item.unitPrice.toStringAsFixed(2)} / ${item.unit} · ${item.gstRate.toInt()}% GST'),
                            trailing: IconButton(
                              icon: const Icon(Icons.add_circle, color: AppColors.primary),
                              onPressed: () {
                                widget.onItemSelected(item);
                                Navigator.pop(context);
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ─── Quick Add Item Sheet ─────────────────────────────────────────────────────
// Inline "add new item" form shown when a barcode is not in catalog.
// User can create the item AND immediately add it to the cart — without
// leaving the QuickScanBill page.

class _QuickAddItemSheet extends ConsumerStatefulWidget {
  final String barcode;
  final void Function(ItemCatalogEntry item) onItemAdded;
  final VoidCallback onDismiss;

  const _QuickAddItemSheet({
    required this.barcode,
    required this.onItemAdded,
    required this.onDismiss,
  });

  @override
  ConsumerState<_QuickAddItemSheet> createState() => _QuickAddItemSheetState();
}

class _QuickAddItemSheetState extends ConsumerState<_QuickAddItemSheet> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  double _gstRate = 18;
  String _unit = 'Nos';
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),

            // Header
            Row(
              children: [
                const Icon(Icons.add_box_outlined, color: AppColors.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('New Item Not in Catalog',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onDismiss,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),

            // Scanned barcode chip
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.infoLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.qr_code_2, size: 14, color: AppColors.info),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      widget.barcode.length > 30
                          ? '${widget.barcode.substring(0, 27)}…'
                          : widget.barcode,
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.info),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Name field
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Item Name *',
                hintText: 'e.g., Laptop, Rice 5kg',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),

            // Price + Unit row
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Price (₹) *',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _unit,
                    decoration: InputDecoration(
                      labelText: 'Unit',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    ),
                    items: ['Nos', 'Kg', 'Ltr', 'Pcs', 'Box', 'Bag', 'Mtr']
                        .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (v) => setState(() => _unit = v ?? 'Nos'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // GST rate chips
            Row(
              children: [
                const Text('GST: ', style: TextStyle(color: AppColors.textSecondaryLight)),
                ...([0.0, 5.0, 12.0, 18.0, 28.0].map((r) {
                  final sel = _gstRate == r;
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: GestureDetector(
                      onTap: () => setState(() => _gstRate = r),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: sel ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: sel ? AppColors.primary : AppColors.borderLight),
                        ),
                        child: Text('${r.toInt()}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: sel ? Colors.white : AppColors.textSecondaryLight,
                            )),
                      ),
                    ),
                  );
                })),
              ],
            ),
            const SizedBox(height: 18),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onDismiss,
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    icon: _saving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.add_shopping_cart_rounded),
                    label: const Text('Add & Scan to Cart'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _saving ? null : _saveAndAdd,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAndAdd() async {
    final name = _nameCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter item name'), backgroundColor: AppColors.warning),
      );
      return;
    }
    if (price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid price'), backgroundColor: AppColors.warning),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final notifier = ref.read(itemCatalogProvider.notifier);
      await notifier.addItem(
        name: name,
        unitPrice: price,
        gstRate: _gstRate,
        unit: _unit,
        barcode: widget.barcode,
      );
      // Get the freshly created item (it's at index 0 after addItem prepends it)
      final newItem = ref.read(itemCatalogProvider).first;
      widget.onItemAdded(newItem);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
        );
        setState(() => _saving = false);
      }
    }
  }
}


