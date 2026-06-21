import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart' show launchUrl, LaunchMode;

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../backup/data/services/backup_service.dart';
import '../../../backup/data/services/backup_settings_provider.dart';
import '../../../business_setup/data/models/business_template.dart';
import '../../../business_setup/presentation/providers/business_template_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../invoice/presentation/providers/item_catalog_provider.dart';
import '../providers/auth_provider.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.valueOrNull?.user;
    final themeMode = ref.watch(themeModeProvider);

    final businessBox = LocalStorage.businessBox;
    final businessName = businessBox.get('name', defaultValue: '') as String;
    final businessGstin = businessBox.get('gstin', defaultValue: '') as String;
    final businessAddress = businessBox.get('address', defaultValue: '') as String;
    final businessCity = businessBox.get('city', defaultValue: '') as String;
    final businessState = businessBox.get('state', defaultValue: '') as String;
    final businessPhone = businessBox.get('phone', defaultValue: '') as String;
    final businessEmail = businessBox.get('email', defaultValue: '') as String;
    final hasBusiness = businessName.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile & Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User info header
          AppCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.primarySurface,
                  backgroundImage: user?.photoUrl != null
                      ? NetworkImage(user!.photoUrl!)
                      : null,
                  child: user?.photoUrl == null
                      ? Text(
                          (user?.name?.isNotEmpty == true ? user!.name![0] : '?').toUpperCase(),
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.primary),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.name ?? 'User', style: Theme.of(context).textTheme.titleLarge),
                      if (user?.email != null)
                        Text(user!.email!, style: Theme.of(context).textTheme.bodySmall),
                      if (user?.phone != null)
                        Text(user!.phone!, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Plan', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.textSecondaryLight)),
          const SizedBox(height: 8),
          _buildPlanCard(context, user),
          const SizedBox(height: 16),
          Text('Business Details', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.textSecondaryLight)),
          const SizedBox(height: 8),
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: hasBusiness
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.business, color: AppColors.primary, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(businessName, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                                  if (businessGstin.isNotEmpty)
                                    Text('GSTIN: $businessGstin', style: Theme.of(context).textTheme.bodySmall),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (businessAddress.isNotEmpty || businessCity.isNotEmpty || businessState.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            [
                              if (businessAddress.isNotEmpty) businessAddress,
                              if (businessCity.isNotEmpty) businessCity,
                              if (businessState.isNotEmpty) businessState,
                            ].join(', '),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        if (businessPhone.isNotEmpty || businessEmail.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            [if (businessPhone.isNotEmpty) businessPhone, if (businessEmail.isNotEmpty) businessEmail].join(' | '),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    )
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          children: [
                            const Icon(Icons.business_outlined, size: 32, color: AppColors.textTertiaryLight),
                            const SizedBox(height: 8),
                            const Text('No business details yet', style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 13)),
                            const SizedBox(height: 4),
                            TextButton(
                              onPressed: () => context.push(AppRoutes.businessSetup),
                              child: const Text('Set up your business'),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Business', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.textSecondaryLight)),
          const SizedBox(height: 8),
          AppCard(
            child: Column(
              children: [
                _buildTemplateTile(context, ref),
                const Divider(height: 1),
                _SettingsItem(
                  icon: Icons.business_outlined,
                  title: 'Business Profile',
                  subtitle: 'Edit name, GSTIN, address',
                  onTap: () => context.push(AppRoutes.businessSetup),
                ),
                const Divider(height: 1),
                _SettingsItem(
                  icon: Icons.receipt_outlined,
                  title: 'Invoice Settings',
                  subtitle: 'Prefix, terms, signature, templates',
                  onTap: () => context.push(AppRoutes.invoiceSettings),
                ),
                const Divider(height: 1),
                _SettingsItem(
                  icon: Icons.sell_outlined,
                  title: 'Sale Settings',
                  subtitle: 'Barcode, fields, defaults',
                  onTap: () => context.push(AppRoutes.saleSettings),
                ),
                const Divider(height: 1),
                _SettingsItem(
                  icon: Icons.inventory_outlined,
                  title: 'Item Settings',
                  subtitle: 'Dates, stock, purchase price fields',
                  onTap: () => context.push(AppRoutes.itemSettings),
                ),
                const Divider(height: 1),
                _SettingsItem(
                  icon: Icons.visibility_outlined,
                  title: 'Feature Visibility',
                  subtitle: 'Show/hide Staff, Customers, Purchases & more',
                  onTap: () => context.push(AppRoutes.featureSettings),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Data', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.textSecondaryLight)),
          const SizedBox(height: 8),
          AppCard(
            child: Column(
              children: [
                _SettingsItem(
                  icon: Icons.backup_outlined,
                  title: 'Export Backup',
                  subtitle: 'Save data to file & share (WhatsApp, Drive...)',
                  onTap: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Creating backup...')),
                    );
                    await BackupService.exportAndShare();
                  },
                ),
                const Divider(height: 1),
                _SettingsItem(
                  icon: Icons.download_outlined,
                  title: 'Save Backup',
                  subtitle: 'Save backup file to device storage',
                  onTap: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Saving backup...')),
                    );
                    final path = await BackupService.saveLocalBackup();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    if (path != null) {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Backup Saved'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Your data has been backed up successfully.'),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: SelectableText(path,
                                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                              ),
                              const SizedBox(height: 8),
                              Text('Use a file manager to browse to this location.',
                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('OK'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                BackupService.exportAndShare();
                              },
                              child: const Text('Share'),
                            ),
                          ],
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Backup failed'),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                    }
                  },
                ),
                const Divider(height: 1),
                _SettingsItem(
                  icon: Icons.schedule_outlined,
                  title: 'Auto Backup',
                  subtitle: ref.watch(backupSettingsProvider).frequency.label,
                  onTap: () => _showBackupSettings(context, ref),
                ),
                const Divider(height: 1),
                _SettingsItem(
                  icon: Icons.restore_outlined,
                  title: 'Restore Backup',
                  subtitle: 'Load data from a backup file',
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Restore Backup'),
                        content: const Text(
                          'This will overwrite all current local data with the backup. Continue?',
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restore')),
                        ],
                      ),
                    );
                    if (confirm != true) return;
                    final ok = await BackupService.importFromPicker();
                    if (!context.mounted) return;
                    if (ok) {
                      // Force in-memory providers to reload from Hive
                      ref.invalidate(itemCatalogProvider);
                      ref.invalidate(dashboardStatsProvider);
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ok ? 'Backup restored successfully' : 'Restore failed'),
                        backgroundColor: ok ? AppColors.success : AppColors.danger,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Preferences', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.textSecondaryLight)),
          const SizedBox(height: 8),
          AppCard(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Dark Mode'),
                  value: themeMode == ThemeMode.dark,
                  onChanged: (val) {
                    ref.read(themeModeProvider.notifier).state =
                        val ? ThemeMode.dark : ThemeMode.light;
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.language),
                  title: const Text('Language'),
                  subtitle: Text(ref.watch(appLanguageProvider).label),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showLanguagePicker(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Support', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.textSecondaryLight)),
          const SizedBox(height: 8),
          AppCard(
            child: Column(
              children: [
                _SettingsItem(
                  icon: Icons.smart_toy_outlined,
                  title: 'GST Assistant',
                  subtitle: 'Create invoices via chat',
                  onTap: () => context.push(AppRoutes.chatFlow),
                ),
                const Divider(height: 1),
                _SettingsItem(
                  icon: Icons.support_agent_outlined,
                  title: 'Chat Support',
                  onTap: () => context.push(AppRoutes.chatSupport),
                ),
                const Divider(height: 1),
                _SettingsItem(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  onTap: () => context.push(AppRoutes.privacyPolicy),
                ),
                const Divider(height: 1),
                _SettingsItem(
                  icon: Icons.description_outlined,
                  title: 'Terms of Service',
                  onTap: () => context.push(AppRoutes.termsOfService),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Sign Out',
            isOutlined: true,
            foregroundColor: AppColors.danger,
            icon: Icons.logout,
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Sign Out'),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Sign Out', style: TextStyle(color: AppColors.danger)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                ref.read(authStateProvider.notifier).signOut();
              }
            },
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              'GST Solution v1.0.0',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPlanCard(BuildContext context, dynamic user) {
    if (user == null) return const SizedBox.shrink();
    final plan = user.plan ?? 'free';
    final isPaid = plan == 'local_paid' || plan == 'db_paid';

    String planLabel;
    IconData planIcon;
    Color planColor;
    String planDesc;

    switch (plan) {
      case 'db_paid':
        planLabel = 'DB Paid';
        planIcon = Icons.cloud_done;
        planColor = Colors.green;
        planDesc = 'Unlimited • Auto-sync to cloud';
        break;
      case 'local_paid':
        planLabel = 'Local Paid';
        planIcon = Icons.storage;
        planColor = Colors.blue;
        planDesc = 'Unlimited • Local storage only';
        break;
      default:
        planLabel = 'Free';
        planIcon = Icons.free_breakfast;
        planColor = AppColors.textSecondaryLight;
        planDesc = 'Unlimited • Includes ads';
    }

    final adsRemoved = LocalStorage.settingsBox.get('ads_removed', defaultValue: false) as bool;

    return AppCard(
      child: Column(
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: planColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: Icon(planIcon, color: planColor, size: 22),
            ),
            title: Text(planLabel, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            subtitle: Text(planDesc, style: Theme.of(context).textTheme.bodySmall),
            trailing: isPaid || adsRemoved
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: planColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                    child: Text(adsRemoved ? 'Ad-Free' : 'Active', style: TextStyle(fontSize: 11, color: planColor, fontWeight: FontWeight.w600)),
                  )
                : null,
          ),
          if (!isPaid && !adsRemoved && user.plan == 'free')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.chat, size: 16),
                label: const Text('Remove Ads — Contact on WhatsApp'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  minimumSize: const Size(double.infinity, 36),
                ),
                onPressed: () async {
                  final uri = Uri.parse('https://wa.me/+919538923091');
                  try {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } catch (_) {}
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTemplateTile(BuildContext context, WidgetRef ref) {
    final template = ref.watch(businessTemplateProvider);
    return _SettingsItem(
      icon: template.icon,
      title: 'Business Template',
      subtitle: template.displayName,
      onTap: () => _showTemplatePicker(context, ref, template),
    );
  }

  void _showTemplatePicker(BuildContext context, WidgetRef ref, BusinessTemplate current) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Choose Business Template',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('Pre-fills all settings for your business type',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight)),
              const SizedBox(height: 16),
              ...BusinessTemplate.values.map((t) {
                final selected = t == current;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: selected ? AppColors.primarySurface : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        if (t != current) {
                          ref.read(businessTemplateProvider.notifier).select(t, ref);
                          Navigator.pop(ctx);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: selected ? AppColors.primary : AppColors.surfaceVariantLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(t.icon, color: selected ? Colors.white : AppColors.textSecondaryLight, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(t.displayName,
                                      style: TextStyle(fontWeight: FontWeight.w600, color: selected ? AppColors.primary : null)),
                                  Text(t.description,
                                      style: TextStyle(fontSize: 12, color: AppColors.textTertiaryLight)),
                                ],
                              ),
                            ),
                            if (selected)
                              const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const _SettingsItem({required this.icon, required this.title, this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
      subtitle: subtitle != null ? Text(subtitle!, style: Theme.of(context).textTheme.bodySmall) : null,
      trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiaryLight, size: 18),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    );
  }
}

void _showLanguagePicker(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Select Language', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
        ...AppLanguage.values.map((lang) => ListTile(
          leading: Icon(
            ref.watch(appLanguageProvider) == lang ? Icons.radio_button_checked : Icons.radio_button_off,
            color: AppColors.primary,
          ),
          title: Text(lang.label),
          onTap: () {
            ref.read(appLanguageProvider.notifier).setLanguage(lang);
            Navigator.pop(ctx);
          },
        )),
        const SizedBox(height: 16),
      ],
    ),
  );
}

void _showBackupSettings(BuildContext context, WidgetRef ref) {
  final settings = ref.read(backupSettingsProvider);
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Auto Backup Frequency', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
        ...BackupFrequency.values.map((freq) => ListTile(
          leading: Icon(
            settings.frequency == freq ? Icons.radio_button_checked : Icons.radio_button_off,
            color: AppColors.primary,
          ),
          title: Text(freq.label),
          onTap: () {
            ref.read(backupSettingsProvider.notifier).updateFrequency(freq);
            Navigator.pop(ctx);
          },
        )),
        if (settings.lastBackupAt != null) ...[
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Last backup: ${settings.lastBackupAt!.day}/${settings.lastBackupAt!.month}/${settings.lastBackupAt!.year}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    ),
  );
}

