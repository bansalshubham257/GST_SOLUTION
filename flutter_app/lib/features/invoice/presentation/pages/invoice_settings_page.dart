import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../providers/invoice_settings_provider.dart';

class InvoiceSettingsPage extends ConsumerStatefulWidget {
  const InvoiceSettingsPage({super.key});

  @override
  ConsumerState<InvoiceSettingsPage> createState() => _InvoiceSettingsPageState();
}

class _InvoiceSettingsPageState extends ConsumerState<InvoiceSettingsPage> {
  late TextEditingController _prefixController;
  late TextEditingController _termsController;
  late TextEditingController _signatureController;
  late String _selectedTemplate;

  static const _templates = [
    {
      'id': 'classic',
      'name': 'Classic',
      'desc': 'Blue header, traditional layout',
      'color': AppColors.primary,
      'icon': Icons.description_outlined,
    },
    {
      'id': 'modern',
      'name': 'Modern',
      'desc': 'Green accent, clean design',
      'color': AppColors.secondary,
      'icon': Icons.article_outlined,
    },
    {
      'id': 'minimal',
      'name': 'Minimal',
      'desc': 'No colors, simple black & white',
      'color': AppColors.textSecondaryLight,
      'icon': Icons.text_snippet_outlined,
    },
  ];

  @override
  void initState() {
    super.initState();
    final settings = ref.read(invoiceSettingsProvider);
    _prefixController = TextEditingController(text: settings.prefix);
    _termsController = TextEditingController(text: settings.defaultTerms);
    _signatureController = TextEditingController(text: settings.signatureText);
    _selectedTemplate = settings.templateStyle;
  }

  @override
  void dispose() {
    _prefixController.dispose();
    _termsController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invoice Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Template Style',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: AppColors.textSecondaryLight)),
          const SizedBox(height: 12),
          ..._templates.map((t) => _TemplateCard(
                id: t['id'] as String,
                name: t['name'] as String,
                desc: t['desc'] as String,
                color: t['color'] as Color,
                icon: t['icon'] as IconData,
                isSelected: _selectedTemplate == t['id'],
                onTap: () => setState(() => _selectedTemplate = t['id'] as String),
              )),
          const SizedBox(height: 24),
          Text('Invoice Prefix',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: AppColors.textSecondaryLight)),
          const SizedBox(height: 8),
          AppTextField(
            label: 'Prefix',
            hint: 'INV',
            controller: _prefixController,
            maxLength: 10,
          ),
          const SizedBox(height: 20),
          Text('Default Terms & Conditions',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: AppColors.textSecondaryLight)),
          const SizedBox(height: 8),
          TextField(
            controller: _termsController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Enter default terms for invoices...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.borderLight),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 20),
          Text('Signature Text',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: AppColors.textSecondaryLight)),
          const SizedBox(height: 8),
          TextField(
            controller: _signatureController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Signature line for PDF...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.borderLight),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 32),
          AppButton(
            label: 'Save Settings',
            icon: Icons.save_outlined,
            onPressed: _save,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final settings = InvoiceSettings(
      prefix: _prefixController.text.trim().isEmpty
          ? 'INV'
          : _prefixController.text.trim(),
      defaultTerms: _termsController.text.trim(),
      signatureText: _signatureController.text.trim().isEmpty
          ? 'This is a computer-generated invoice and does not require a signature.'
          : _signatureController.text.trim(),
      templateStyle: _selectedTemplate,
    );
    await ref.read(invoiceSettingsProvider.notifier).save(settings);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invoice settings saved'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }
}

class _TemplateCard extends StatelessWidget {
  final String id;
  final String name;
  final String desc;
  final Color color;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TemplateCard({
    required this.id,
    required this.name,
    required this.desc,
    required this.color,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.08) : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : AppColors.borderLight,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected ? color : AppColors.surfaceVariantLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: isSelected ? Colors.white : color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isSelected ? color : null)),
                    const SizedBox(height: 2),
                    Text(desc,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textSecondaryLight)),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: color, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
