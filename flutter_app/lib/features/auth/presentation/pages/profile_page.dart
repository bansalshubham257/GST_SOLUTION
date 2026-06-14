import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/storage/local_storage.dart';
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
                  icon: Icons.support_agent_outlined,
                  title: 'Chat Support',
                  onTap: () => context.push(AppRoutes.chatSupport),
                ),
                const Divider(height: 1),
                _SettingsItem(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  onTap: () {},
                ),
                const Divider(height: 1),
                _SettingsItem(
                  icon: Icons.description_outlined,
                  title: 'Terms of Service',
                  onTap: () {},
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
        planDesc = 'Limited to 2 staff, 2 services, 2 sales';
    }

    return AppCard(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: planColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
          child: Icon(planIcon, color: planColor, size: 22),
        ),
        title: Text(planLabel, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(planDesc, style: Theme.of(context).textTheme.bodySmall),
        trailing: isPaid
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: planColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: Text('Active', style: TextStyle(fontSize: 11, color: planColor, fontWeight: FontWeight.w600)),
              )
            : null,
      ),
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

