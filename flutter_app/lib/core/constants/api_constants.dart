// lib/core/constants/api_constants.dart

class ApiConstants {
  ApiConstants._();

  // Base URLs
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000/api/v1', // Android emulator localhost
  );

  static const String productionBaseUrl = 'https://api.salonregister.in/api/v1';

  // Auth
  static const String login = '/auth/login';
  static const String verifyOtp = '/auth/verify-otp';
  static const String googleLogin = '/auth/google';
  static const String logout = '/auth/logout';
  static const String refreshToken = '/auth/refresh';
  static const String me = '/auth/me';
  static const String signup = '/auth/signup';
  static const String dbLogin = '/auth/db-login';
  static const String dbDemoLogin = '/auth/db-demo-login';

  // Business
  static const String business = '/business';
  static const String businessSetup = '/business/setup';
  static const String uploadLogo = '/business/logo';

  // Dashboard
  static const String dashboardStats = '/dashboard/stats';
  static const String dashboardSummary = '/dashboard/monthly-summary';

  // Invoices
  static const String invoices = '/invoices';
  static const String invoiceById = '/invoices/:id';
  static const String createInvoice = '/invoices';
  static const String scanBill = '/invoices/scan-bill';
  static const String invoicePdf = '/invoices/:id/pdf';
  static const String invoicePreview = '/invoices/:id/preview';
  static const String duplicateInvoice = '/invoices/:id/duplicate';
  static const String cancelInvoice = '/invoices/:id/cancel';

  // Customers
  static const String customers = '/customers';
  static const String customerById = '/customers/:id';
  static const String customerInvoices = '/customers/:id/invoices';
  static const String customerLedger = '/customers/:id/ledger';

  // Products / Services
  static const String products = '/products';
  static const String productById = '/products/:id';

  // GST Reports
  static const String gstSummary = '/gst/summary';
  static const String salesRegister = '/gst/sales-register';
  static const String taxLiability = '/gst/tax-liability';
  static const String gstr1Draft = '/gst/gstr1-draft';
  static const String gstr3bDraft = '/gst/gstr3b-draft';
  static const String exportReport = '/gst/export';

  // GST Filing
  static const String validateGst = '/gst/validate';
  static const String filingChecklist = '/gst/filing-checklist';
  static const String generateJson = '/gst/generate-json';
  static const String filingHistory = '/gst/filing-history';

  // Chat Support
  static const String chatRooms = '/chat/rooms';
  static const String chatMessages = '/chat/rooms/:id/messages';
  static const String sendMessage = '/chat/rooms/:id/messages';
  static const String aiAssist = '/chat/ai-assist';

  // Admin
  static const String adminUsers = '/admin/users';
  static const String adminStats = '/admin/stats';
  static const String adminLogs = '/admin/logs';

  // Sync
  static const String syncAll = '/sync';
}

