// lib/core/constants/app_constants.dart

class AppConstants {
  AppConstants._();

  static const String appName = 'Register';
  static const String appVersion = '1.0.0';
  static const String appTagline = 'Your Daily Register, Automated';

  // Hive Box Names
  static const String invoiceBox = 'invoices_box';
  static const String customerBox = 'customers_box';
  static const String businessBox = 'business_box';
  static const String userBox = 'user_box';
  static const String settingsBox = 'settings_box';
  static const String draftBox = 'drafts_box';
  static const String itemCatalogBox = 'item_catalog_box';
  static const String staffBox = 'staff_box';
  static const String expenseBox = 'expense_box';
  static const String expenseCategoryBox = 'expense_category_box';

  // Secure Storage Keys
  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userIdKey = 'user_id';
  static const String businessIdKey = 'business_id';

  // GST Rate Slabs (hidden from daily use)
  static const List<double> gstRates = [0, 5, 12, 18, 28];

  // GST States
  static const Map<String, String> indianStates = {
    '01': 'Jammu & Kashmir',
    '02': 'Himachal Pradesh',
    '03': 'Punjab',
    '04': 'Chandigarh',
    '05': 'Uttarakhand',
    '06': 'Haryana',
    '07': 'Delhi',
    '08': 'Rajasthan',
    '09': 'Uttar Pradesh',
    '10': 'Bihar',
    '11': 'Sikkim',
    '12': 'Arunachal Pradesh',
    '13': 'Nagaland',
    '14': 'Manipur',
    '15': 'Mizoram',
    '16': 'Tripura',
    '17': 'Meghalaya',
    '18': 'Assam',
    '19': 'West Bengal',
    '20': 'Jharkhand',
    '21': 'Odisha',
    '22': 'Chhattisgarh',
    '23': 'Madhya Pradesh',
    '24': 'Gujarat',
    '26': 'Dadra and Nagar Haveli and Daman & Diu',
    '27': 'Maharashtra',
    '28': 'Andhra Pradesh (Old)',
    '29': 'Karnataka',
    '30': 'Goa',
    '31': 'Lakshadweep',
    '32': 'Kerala',
    '33': 'Tamil Nadu',
    '34': 'Puducherry',
    '35': 'Andaman & Nicobar Islands',
    '36': 'Telangana',
    '37': 'Andhra Pradesh',
    '38': 'Ladakh',
    '97': 'Other Territory',
    '99': 'Centre Jurisdiction',
  };

  // Invoice
  static const int invoiceNumberPadding = 5;
  static const String defaultInvoicePrefix = 'INV';

  // Pagination
  static const int defaultPageSize = 20;

  // Date formats
  static const String displayDateFormat = 'dd MMM yyyy';
  static const String apiDateFormat = 'yyyy-MM-dd';
  static const String invoiceDateFormat = 'dd/MM/yyyy';

  // Timeouts — keep short so offline fallback is instant
  static const int connectTimeout = 3000;   // 3 seconds
  static const int receiveTimeout = 5000;   // 5 seconds
}

