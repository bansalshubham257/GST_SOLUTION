import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../router/app_router.dart';
import '../localization/app_strings.dart';
import '../providers/language_provider.dart';
import '../../features/dashboard/presentation/providers/dashboard_provider.dart';
import '../../features/staff/presentation/providers/staff_provider.dart';
import '../../features/invoice/presentation/providers/invoice_provider.dart';
import '../../features/purchase/presentation/providers/purchase_provider.dart';
import '../../features/customer/presentation/providers/customer_provider.dart';
import '../../features/settings/presentation/providers/feature_settings_provider.dart';

class MainShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  const MainShell({super.key, required this.navigationShell});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          widget.navigationShell,
          Positioned(
            top: MediaQuery.of(context).padding.top + kToolbarHeight + 4,
            right: 12,
            child: Material(
              elevation: 3,
              shape: const CircleBorder(),
              color: AppColors.primary,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => context.push(AppRoutes.profile),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.settings, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.quickServiceEntry),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Consumer(
        builder: (context, ref, child) {
          final features = ref.watch(featureSettingsProvider);
          return _BottomNavBar(
            currentIndex: widget.navigationShell.currentIndex,
            lang: ref.read(appLanguageProvider),
            features: features,
            onTap: (index) {
              if (index == 0) {
                ref.invalidate(dashboardStatsProvider);
                ref.invalidate(recentInvoicesProvider);
              }
              if (index == 1) {
                ref.invalidate(staffListProvider);
              }
              if (index == 2) {
                ref.invalidate(purchaseListProvider);
              }
              if (index == 3) {
                ref.invalidate(customerListProvider);
              }
              if (index == 4) {
                ref.invalidate(invoiceListProvider);
              }
              widget.navigationShell.goBranch(
                index,
                initialLocation: index == widget.navigationShell.currentIndex,
              );
            },
          );
        },
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final AppLanguage lang;
  final FeatureSettings features;
  final ValueChanged<int> onTap;
  const _BottomNavBar({
    required this.currentIndex,
    required this.lang,
    required this.features,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Build all visible nav items in order with their fixed branch indices
    final allItems = <_NavItem>[
      _NavItem(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard,
        label: AppStrings.navDashboard(lang),
        isActive: currentIndex == 0,
        onTap: () => onTap(0),
      ),
      if (features.showStaff)
        _NavItem(
          icon: Icons.people_outline,
          activeIcon: Icons.people,
          label: AppStrings.navStaff(lang),
          isActive: currentIndex == 1,
          onTap: () => onTap(1),
        ),
      if (features.showPurchases)
        _NavItem(
          icon: Icons.shopping_cart_outlined,
          activeIcon: Icons.shopping_cart,
          label: AppStrings.navPurchase(lang),
          isActive: currentIndex == 2,
          onTap: () => onTap(2),
        ),
      if (features.showCustomers)
        _NavItem(
          icon: Icons.people_outline,
          activeIcon: Icons.people,
          label: AppStrings.navCustomers(lang),
          isActive: currentIndex == 3,
          onTap: () => onTap(3),
        ),
      if (features.showItems)
        _NavItem(
          icon: Icons.inventory_2_outlined,
          activeIcon: Icons.inventory_2,
          label: AppStrings.navServices(lang),
          isActive: currentIndex == 4,
          onTap: () => onTap(4),
        ),
      if (features.showGstReports)
        _NavItem(
          icon: Icons.receipt_long_outlined,
          activeIcon: Icons.receipt_long,
          label: AppStrings.navGst(lang),
          isActive: currentIndex == 5,
          onTap: () => onTap(5),
        ),
    ];

    if (allItems.isEmpty) return const SizedBox.shrink();

    // Insert spacer between left and right halves
    final mid = (allItems.length + 1) ~/ 2;
    final children = <Widget>[
      ...allItems.sublist(0, mid).map((e) => Expanded(child: e)),
      const SizedBox(width: 56),
      ...allItems.sublist(mid).map((e) => Expanded(child: e)),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(children: children),
        ),
      ),
    );
  }
}

class _NavItem extends ConsumerWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = isActive ? AppColors.primary : AppColors.textTertiaryLight;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primarySurface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isActive ? activeIcon : icon, color: color, size: 20),
            const SizedBox(height: 1),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
