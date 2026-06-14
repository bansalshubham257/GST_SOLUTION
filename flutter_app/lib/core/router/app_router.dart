import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/signup_page.dart';
import '../../features/auth/presentation/pages/otp_verification_page.dart';
import '../../features/auth/presentation/pages/profile_page.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/business_setup/presentation/pages/business_setup_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/invoice/presentation/pages/invoice_list_page.dart';
import '../../features/invoice/presentation/pages/create_invoice_page.dart';
import '../../features/invoice/presentation/pages/invoice_detail_page.dart';
import '../../features/invoice/presentation/pages/invoice_preview_page.dart';
import '../../features/customer/presentation/pages/customer_list_page.dart';
import '../../features/customer/presentation/pages/add_customer_page.dart';
import '../../features/customer/presentation/pages/customer_detail_page.dart';
import '../../features/gst_reports/presentation/pages/gstr1_page.dart';
import '../../features/gst_reports/presentation/pages/gstr3b_page.dart';
import '../../features/gst_filing/presentation/pages/gst_filing_page.dart';
import '../../features/chat_support/presentation/pages/chat_support_page.dart';
import '../../features/invoice/presentation/pages/item_catalog_page.dart';
import '../../features/invoice/presentation/pages/add_item_page.dart';
import '../../features/invoice/data/models/item_catalog_entry.dart';
import '../../features/invoice/domain/entities/invoice_entity.dart';
import '../../features/purchase/domain/entities/purchase_entity.dart';
import '../../features/staff/presentation/pages/staff_list_page.dart';
import '../../features/staff/presentation/pages/add_edit_staff_page.dart';
import '../../features/staff/domain/entities/staff_entity.dart';
import '../../features/expense/presentation/pages/expense_list_page.dart';
import '../../features/expense/presentation/pages/add_edit_expense_page.dart';
import '../../features/service_entry/presentation/pages/quick_service_entry_page.dart';
import '../../features/purchase/presentation/pages/purchase_list_page.dart';
import '../../features/purchase/presentation/pages/create_purchase_page.dart';
import '../../features/purchase/presentation/pages/purchase_detail_page.dart';
import '../../features/purchase/presentation/pages/purchase_preview_page.dart';
import '../widgets/main_shell.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String otpVerification = '/otp-verification';
  static const String businessSetup = '/business-setup';
  static const String dashboard = '/dashboard';
  static const String serviceHistory = '/services';
  static const String createService = '/services/create';
  static const String editService = '/services/:id/edit';
  static const String serviceDetail = '/services/:id';
  static const String servicePreview = '/services/:id/preview';
  static const String quickServiceEntry = '/quick-service';
  static const String customers = '/customers';
  static const String addCustomer = '/customers/add';
  static const String customerDetail = '/customers/:id';
  static const String reports = '/reports';
  static const String gstr1 = '/reports/gstr1';
  static const String gstr3b = '/reports/gstr3b';
  static const String gstFiling = '/gst-filing';
  static const String chatSupport = '/chat-support';
  static const String serviceCatalog = '/reports';
  static const String addService = '/reports/catalog/add';
  static const String editServiceItem = '/reports/catalog/edit';
  static const String staff = '/staff';
  static const String addStaff = '/staff/add';
  static const String editStaff = '/staff/edit';
  static const String expenses = '/expenses';
  static const String addExpense = '/expenses/add';
  static const String signup = '/signup';
  static const String profile = '/profile';
  static const String purchases = '/purchases';
  static const String createPurchase = '/purchases/create';
  static const String editPurchase = '/purchases/:id/edit';
  static const String purchaseDetail = '/purchases/:id';
  static const String purchasePreview = '/purchases/:id/preview';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull?.isLoggedIn ?? false;
      final isBusinessSetupDone =
          authState.valueOrNull?.isBusinessSetupDone ?? false;
      final isPublicRoute = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.signup ||
          state.matchedLocation == AppRoutes.otpVerification;

      if (!isLoggedIn && !isPublicRoute) return AppRoutes.login;
      if (isLoggedIn &&
          !isBusinessSetupDone &&
          state.matchedLocation != AppRoutes.businessSetup) {
        return AppRoutes.businessSetup;
      }
      if (isLoggedIn && state.matchedLocation == AppRoutes.login) return AppRoutes.dashboard;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        redirect: (_, __) => AppRoutes.dashboard,
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        name: 'signup',
        builder: (context, state) => const SignupPage(),
      ),
      GoRoute(
        path: AppRoutes.otpVerification,
        name: 'otp-verification',
        builder: (context, state) {
          final phone = state.extra as String? ?? '';
          return OtpVerificationPage(phoneNumber: phone);
        },
      ),
      GoRoute(
        path: AppRoutes.businessSetup,
        name: 'business-setup',
        builder: (context, state) {
          final box = Hive.box(AppConstants.businessBox);
          final keys = box.keys.toList();
          final existing = <String, dynamic>{};
          for (final key in keys) {
            existing[key.toString()] = box.get(key);
          }
          return BusinessSetupPage(existingData: existing.isNotEmpty ? existing : null);
        },
      ),
      GoRoute(
        path: AppRoutes.quickServiceEntry,
        name: 'quick-service',
        builder: (context, state) => const QuickServiceEntryPage(),
        routes: [
          GoRoute(
            path: 'add-item',
            name: 'quick-add-item',
            builder: (context, state) => const AddItemPage(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.expenses,
        name: 'expense-list',
        builder: (context, state) => const ExpenseListPage(),
        routes: [
          GoRoute(
            path: 'add',
            name: 'add-expense',
            builder: (context, state) => const AddEditExpensePage(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.gstFiling,
        name: 'gst-filing',
        builder: (context, state) => const GstFilingPage(),
      ),
      GoRoute(
        path: AppRoutes.chatSupport,
        name: 'chat-support',
        builder: (context, state) => const ChatSupportPage(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        name: 'profile',
        builder: (context, state) => const ProfilePage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          // Branch 0: Dashboard
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.dashboard,
              name: 'dashboard',
              builder: (context, state) => const DashboardPage(),
            ),
          ]),
          // Branch 1: Staff
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.staff,
              name: 'staff-tab',
              builder: (context, state) => const StaffListPage(),
              routes: [
                GoRoute(
                  path: 'add',
                  name: 'add-staff',
                  builder: (context, state) => const AddEditStaffPage(),
                ),
                GoRoute(
                  path: 'edit',
                  name: 'edit-staff',
                  builder: (context, state) =>
                      AddEditStaffPage(staff: state.extra as StaffEntity?),
                ),
              ],
            ),
          ]),
          // Branch 2: Purchases
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.purchases,
              name: 'purchases-tab',
              builder: (context, state) => const PurchaseListPage(),
              routes: [
                GoRoute(
                  path: 'create',
                  name: 'create-purchase',
                  builder: (context, state) => const CreatePurchasePage(),
                ),
                GoRoute(
                  path: ':id',
                  name: 'purchase-detail',
                  builder: (context, state) {
                    final extra = state.extra;
                    return PurchaseDetailPage(
                      purchaseId: state.pathParameters['id']!,
                      initialPurchase: extra is PurchaseEntity ? extra : null,
                    );
                  },
                  routes: [
                    GoRoute(
                      path: 'preview',
                      name: 'purchase-preview',
                      builder: (context, state) =>
                          PurchasePreviewPage(purchaseId: state.pathParameters['id']!),
                    ),
                    GoRoute(
                      path: 'edit',
                      name: 'edit-purchase',
                      builder: (context, state) =>
                          CreatePurchasePage(purchaseId: state.pathParameters['id']!),
                    ),
                  ],
                ),
              ],
            ),
          ]),
          // Branch 3: Customers
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.customers,
              name: 'customers-tab',
              builder: (context, state) => const CustomerListPage(),
              routes: [
                GoRoute(
                  path: 'add',
                  name: 'add-customer',
                  builder: (context, state) => const AddCustomerPage(),
                ),
                GoRoute(
                  path: ':id',
                  name: 'customer-detail',
                  builder: (context, state) => CustomerDetailPage(
                      customerId: state.pathParameters['id']!),
                ),
              ],
            ),
          ]),
          // Branch 4: Reports (Services, Expenses, GST)
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.reports,
              name: 'reports-tab',
              builder: (context, state) => const ItemCatalogPage(),
              routes: [
                GoRoute(
                  path: 'catalog/add',
                  name: 'add-service',
                  builder: (context, state) => const AddItemPage(),
                ),
                GoRoute(
                  path: 'catalog/edit',
                  name: 'edit-service',
                  builder: (context, state) =>
                      AddItemPage(editItem: state.extra as ItemCatalogEntry?),
                ),
                GoRoute(
                  path: 'gstr1',
                  name: 'gstr1',
                  builder: (context, state) => const Gstr1Page(),
                ),
                GoRoute(
                  path: 'gstr3b',
                  name: 'gstr3b',
                  builder: (context, state) => const Gstr3bPage(),
                ),
              ],
            ),
          ]),
        ],
      ),
      // Service History (full page routes outside shell)
      GoRoute(
        path: AppRoutes.serviceHistory,
        name: 'service-history',
        builder: (context, state) => const InvoiceListPage(),
        routes: [
          GoRoute(
            path: 'create',
            name: 'create-service',
            builder: (context, state) => const CreateInvoicePage(),
          ),
          GoRoute(
            path: ':id',
            name: 'service-detail',
            builder: (context, state) {
              final extra = state.extra;
              debugPrint('[Router] service-detail id=${state.pathParameters['id']} extra type=${extra?.runtimeType} isInvoiceEntity=${extra is InvoiceEntity}');
              return InvoiceDetailPage(
                invoiceId: state.pathParameters['id']!,
              initialInvoice: extra is InvoiceEntity ? extra : null,
              );
            },
            routes: [
              GoRoute(
                path: 'preview',
                name: 'service-preview',
                builder: (context, state) => InvoicePreviewPage(
                    invoiceId: state.pathParameters['id']!),
              ),
              GoRoute(
                path: 'edit',
                name: 'edit-service-entry',
                builder: (context, state) => CreateInvoicePage(
                    invoiceId: state.pathParameters['id']!),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Page not found: ${state.error}'),
            TextButton(
              onPressed: () => context.go(AppRoutes.dashboard),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});
