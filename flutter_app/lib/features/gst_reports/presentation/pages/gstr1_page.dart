// lib/features/gst_reports/presentation/pages/gstr1_page.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../providers/gst_reports_provider.dart';

class Gstr1Page extends ConsumerStatefulWidget {
  const Gstr1Page({super.key});

  @override
  ConsumerState<Gstr1Page> createState() => _Gstr1PageState();
}

class _Gstr1PageState extends ConsumerState<Gstr1Page> with SingleTickerProviderStateMixin {
  DateTime _selectedMonth = DateTime.now();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gstr1 = ref.watch(gstr1Provider(_selectedMonth));

    return Scaffold(
      appBar: AppBar(
        title: const Text('GSTR-1 Draft'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('Export JSON'),
            onPressed: () => _exportJson(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'B2B Invoices'), Tab(text: 'B2C Invoices')],
        ),
      ),
      body: Column(
        children: [
          _buildMonthPicker(context),
          Expanded(
            child: gstr1.when(
              data: (data) => TabBarView(
                controller: _tabController,
                children: [
                  _buildB2bList(context, data),
                  _buildB2cList(context, data),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const EmptyState(
                icon: Icons.bar_chart_outlined,
                title: 'No GSTR-1 data',
                subtitle: 'Create invoices to generate GSTR-1',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthPicker(BuildContext context) {
    return Container(
      color: AppColors.primarySurface,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppColors.primary),
            onPressed: () => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1)),
          ),
          Text(
            DateFormat('MMMM yyyy').format(_selectedMonth),
            style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: AppColors.primary),
            onPressed: _selectedMonth.month == DateTime.now().month ? null
                : () => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1)),
          ),
        ],
      ),
    );
  }

  Widget _buildB2bList(BuildContext context, Gstr1Data data) {
    if (data.b2bInvoices.isEmpty) {
      return const EmptyState(
        icon: Icons.business_outlined,
        title: 'No B2B invoices',
        subtitle: 'B2B invoices are those with customer GSTIN',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: data.b2bInvoices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final inv = data.b2bInvoices[i];
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(inv.customerName, style: Theme.of(context).textTheme.titleSmall),
                        Text('GSTIN: ${inv.customerGstin}', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Text('₹${inv.invoiceValue.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _pill(context, inv.invoiceNumber),
                  const SizedBox(width: 8),
                  _pill(context, DateFormat('dd/MM/yy').format(inv.invoiceDate)),
                  const Spacer(),
                  if (inv.igst > 0) _taxPill('IGST ₹${inv.igst.toStringAsFixed(0)}', AppColors.igstColor),
                  if (inv.cgst > 0) ...[
                    _taxPill('CGST ₹${inv.cgst.toStringAsFixed(0)}', AppColors.cgstColor),
                    const SizedBox(width: 4),
                    _taxPill('SGST ₹${inv.sgst.toStringAsFixed(0)}', AppColors.sgstColor),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildB2cList(BuildContext context, Gstr1Data data) {
    if (data.b2cInvoices.isEmpty) {
      return const EmptyState(
        icon: Icons.person_outline,
        title: 'No B2C invoices',
        subtitle: 'B2C invoices are those without customer GSTIN',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: data.b2cInvoices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final inv = data.b2cInvoices[i];
        return AppCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(inv.state, style: Theme.of(context).textTheme.titleSmall),
                    Text('Taxable: ₹${inv.taxableValue.toStringAsFixed(2)}', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (inv.igst > 0) _taxPill('IGST ₹${inv.igst.toStringAsFixed(0)}', AppColors.igstColor),
                  if (inv.cgst > 0) _taxPill('CGST+SGST ₹${(inv.cgst + inv.sgst).toStringAsFixed(0)}', AppColors.cgstColor),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pill(BuildContext context, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: AppColors.surfaceVariantLight, borderRadius: BorderRadius.circular(4)),
    child: Text(text, style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
  );

  Widget _taxPill(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
    child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
  );

  void _exportJson(BuildContext context) async {
    final gstr1 = ref.read(gstr1Provider(_selectedMonth)).valueOrNull;
    if (gstr1 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No GSTR-1 data available'), backgroundColor: AppColors.warning),
      );
      return;
    }

    try {
      final jsonData = {
        'period': DateFormat('yyyy-MM').format(_selectedMonth),
        'gstin': '',  // filled from business profile
        'b2b': gstr1.b2bInvoices.map((inv) => {
          'customerGstin': inv.customerGstin,
          'customerName': inv.customerName,
          'invoiceNumber': inv.invoiceNumber,
          'invoiceDate': DateFormat('dd-MM-yyyy').format(inv.invoiceDate),
          'invoiceValue': inv.invoiceValue,
          'taxableValue': inv.taxableValue,
          'cgst': inv.cgst,
          'sgst': inv.sgst,
          'igst': inv.igst,
        }).toList(),
        'b2c': gstr1.b2cInvoices.map((inv) => {
          'state': inv.state,
          'taxableValue': inv.taxableValue,
          'cgst': inv.cgst,
          'sgst': inv.sgst,
          'igst': inv.igst,
        }).toList(),
        'summary': {
          'totalTaxableValue': gstr1.totalTaxableValue,
          'totalTax': gstr1.totalTax,
        },
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonData);
      final dir = await getApplicationDocumentsDirectory();
      final filename = 'GSTR1_${_selectedMonth.year}${_selectedMonth.month.toString().padLeft(2, '0')}.json';
      final file = File('${dir.path}/$filename');
      await file.writeAsString(jsonString);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('GSTR-1 saved: $filename'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }
}

