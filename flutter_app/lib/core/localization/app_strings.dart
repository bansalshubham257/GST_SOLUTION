// lib/core/localization/app_strings.dart

import '../providers/language_provider.dart';

class AppStrings {
  static String get(String key, AppLanguage lang) {
    final map = _all[key];
    if (map == null) return key;
    return map[lang] ?? map[AppLanguage.english] ?? key;
  }

  static String Function(AppLanguage) _t(String en, String hi) =>
      (lang) => lang == AppLanguage.hindi ? hi : en;

  static final Map<String, Map<AppLanguage, String>> _all = {};

  static String welcome(AppLanguage l) => _t(
    '👋 Welcome! I can help you manage everything.\n\nChoose an option below:',
    '👋 स्वागत है! मैं आपको सब कुछ प्रबंधित करने में मदद कर सकता हूँ।\n\nनीचे कोई विकल्प चुनें:',
  )(l);

  static String menuAddStaff(AppLanguage l) => _t('👤 Add Staff', '👤 स्टाफ़ जोड़ें')(l);
  static String menuAddCustomer(AppLanguage l) => _t('👥 Add Customer', '👥 ग्राहक जोड़ें')(l);
  static String menuCreateSale(AppLanguage l) => _t('🧾 Create Sale', '🧾 बिक्री करें')(l);
  static String menuCreatePurchase(AppLanguage l) => _t('📦 Create Purchase', '📦 खरीदारी करें')(l);
  static String menuHelp(AppLanguage l) => _t('❓ Help', '❓ सहायता')(l);

  static String helpText(AppLanguage l) => _t(
    'I can help you with:\n\n'
    '• **Add Staff** — Add a new staff member with commission\n'
    '• **Add Customer** — Add a new customer with GST details\n'
    '• **Create Sale** — Create a sale with items & quantities\n'
    '• **Create Purchase** — Record a purchase from suppliers\n\n'
    'Just tap any option above to get started!',
    'मैं आपकी इन चीज़ों में मदद कर सकता हूँ:\n\n'
    '• **स्टाफ़ जोड़ें** — कमीशन के साथ नया स्टाफ़ सदस्य जोड़ें\n'
    '• **ग्राहक जोड़ें** — GST विवरण के साथ नया ग्राहक जोड़ें\n'
    '• **बिक्री करें** — आइटम और मात्रा के साथ बिक्री बनाएँ\n'
    '• **खरीदारी करें** — आपूर्तिकर्ता से खरीदारी रिकॉर्ड करें\n\n'
    'आरंभ करने के लिए ऊपर कोई विकल्प टैप करें!',
  )(l);

  static String chooseOption(AppLanguage l) => _t('Please choose from the options above ☝️', 'कृपया ऊपर दिए गए विकल्पों में से चुनें ☝️')(l);

  // Staff flow
  static String staffWelcome(AppLanguage l) => _t("Let's add a new staff member! ✨\n\nWhat is the staff name?", "चलिए नया स्टाफ़ सदस्य जोड़ते हैं! ✨\n\nस्टाफ़ का नाम क्या है?")(l);
  static String staffPhone(String name, AppLanguage l) => _t('Great! What is $name\'s phone number?', 'बहुत अच्छा! $name का फ़ोन नंबर क्या है?')(l);
  static String staffRole(AppLanguage l) => _t("What is their role? (e.g., Salesperson, Technician, Accountant)", "उनकी भूमिका क्या है? (जैसे, विक्रेता, तकनीशियन, एकाउंटेंट)")(l);
  static String staffCommission(AppLanguage l) => _t("What commission percentage do they get? (e.g., 5)", "उन्हें कितना कमीशन प्रतिशत मिलता है? (जैसे, 5)")(l);
  static String staffConfirm(String name, String phone, String role, String commission, AppLanguage l) => _t(
    '📋 **Confirm Staff Details:**\n\nName: **$name**\nPhone: **$phone**\nRole: **$role**\nCommission: **$commission%**\n\nSave this staff member?',
    '📋 **स्टाफ़ विवरण की पुष्टि करें:**\n\nनाम: **$name**\nफ़ोन: **$phone**\nभूमिका: **$role**\nकमीशन: **$commission%**\n\nक्या इस स्टाफ़ सदस्य को सहेजना है?',
  )(l);
  static String staffSaved(String name, AppLanguage l) => _t('✅ Staff **$name** has been added successfully!', '✅ स्टाफ़ **$name** सफलतापूर्वक जोड़ा गया!')(l);
  static String cancelled(AppLanguage l) => _t('Cancelled. Returning to menu...', 'रद्द किया गया। मेनू पर वापस जा रहे हैं...')(l);

  // Customer flow
  static String customerWelcome(AppLanguage l) => _t("Let's add a new customer! ✨\n\nWhat is the customer name?", "चलिए नया ग्राहक जोड़ते हैं! ✨\n\nग्राहक का नाम क्या है?")(l);
  static String customerPhone(String name, AppLanguage l) => _t("What is $name's phone number?", "$name का फ़ोन नंबर क्या है?")(l);
  static String customerGstin(AppLanguage l) => _t("What is their GSTIN? (optional)", "उनका GSTIN क्या है? (वैकल्पिक)")(l);
  static String customerState(AppLanguage l) => _t("Which state are they in? (e.g., Maharashtra, Gujarat)", "वे किस राज्य में हैं? (जैसे, महाराष्ट्र, गुजरात)")(l);
  static String customerAddress(AppLanguage l) => _t("What is their address? (optional)", "उनका पता क्या है? (वैकल्पिक)")(l);
  static String customerConfirm(String name, String phone, String gstin, String state, String address, AppLanguage l) => _t(
    '📋 **Confirm Customer Details:**\n\nName: **$name**\nPhone: **$phone**\nGSTIN: **$gstin**\nState: **$state**\nAddress: **$address**\n\nSave this customer?',
    '📋 **ग्राहक विवरण की पुष्टि करें:**\n\nनाम: **$name**\nफ़ोन: **$phone**\nGSTIN: **$gstin**\nराज्य: **$state**\nपता: **$address**\n\nक्या इस ग्राहक को सहेजना है?',
  )(l);
  static String customerSaved(String name, AppLanguage l) => _t('✅ Customer **$name** has been added successfully!', '✅ ग्राहक **$name** सफलतापूर्वक जोड़ा गया!')(l);

  // Sale flow
  static String saleCustomerSelect(AppLanguage l) => _t("Let's create a sale! 🧾\n\nSelect a customer (optional):", "चलिए बिक्री करते हैं! 🧾\n\nग्राहक चुनें (वैकल्पिक):")(l);
  static String walkinCustomer(AppLanguage l) => _t('⏭️ Walk-in Customer', '⏭️ वॉक-इन ग्राहक')(l);
  static String customerSelected(String name, AppLanguage l) => _t('Customer **$name** selected!', 'ग्राहक **$name** चुना गया!')(l);
  static String notFoundUsingWalkin(AppLanguage l) => _t('Customer not found. Using Walk-in.', 'ग्राहक नहीं मिला। वॉक-इन का उपयोग कर रहे हैं।')(l);
  static String staffSelect(AppLanguage l) => _t('Select a staff member (optional):', 'स्टाफ़ सदस्य चुनें (वैकल्पिक):')(l);
  static String skipStaff(AppLanguage l) => _t('⏭️ Skip Staff', '⏭️ स्टाफ़ छोड़ें')(l);
  static String staffSkipped(AppLanguage l) => _t('Staff skipped.', 'स्टाफ़ छोड़ दिया गया।')(l);
  static String noStaff(AppLanguage l) => _t('No staff members found. Proceeding without staff.', 'कोई स्टाफ़ सदस्य नहीं मिला। बिना स्टाफ़ के आगे बढ़ रहे हैं।')(l);
  static String staffSelected(String name, AppLanguage l) => _t('Staff **$name** selected!', 'स्टाफ़ **$name** चुना गया!')(l);
  static String itemSelect(AppLanguage l) => _t('Select an item or add a new one:', 'कोई आइटम चुनें या नया जोड़ें:')(l);
  static String otherItem(AppLanguage l) => _t('➕ Other (type name)', '➕ अन्य (नाम टाइप करें)')(l);
  static String typeItemName(AppLanguage l) => _t('Type the item name:', 'आइटम का नाम टाइप करें:')(l);
  static String itemNotFound(AppLanguage l) => _t('Item not found. Type the name:', 'आइटम नहीं मिला। नाम टाइप करें:')(l);
  static String itemSelected(String name, String price, String gst, AppLanguage l) => _t('**$name** selected (₹$price, GST: $gst%).\nQuantity? (e.g., 1, 2.5)', '**$name** चुना गया (₹$price, GST: $gst%).\nमात्रा? (जैसे, 1, 2.5)')(l);
  static String qtyPrompt(AppLanguage l) => _t('Quantity? (e.g., 1, 2.5)', 'मात्रा? (जैसे, 1, 2.5)')(l);
  static String qtyPromptPurchase(AppLanguage l) => _t('Quantity? (e.g., 10, 25)', 'मात्रा? (जैसे, 10, 25)')(l);
  static String pricePrompt(AppLanguage l) => _t('Unit price? (e.g., 500)', 'यूनिट मूल्य? (जैसे, 500)')(l);
  static String pricePromptPurchase(AppLanguage l) => _t('Unit price? (e.g., 100)', 'यूनिट मूल्य? (जैसे, 100)')(l);
  static String gstPrompt(AppLanguage l) => _t('GST rate? (0, 5, 12, 18, 28)', 'GST दर? (0, 5, 12, 18, 28)')(l);
  static String itemAdded(String name, String qty, String price, String gst, AppLanguage l) => _t(
    '✅ **$name** added ($qty × ₹$price, GST: $gst%)\n\nAdd more items?',
    '✅ **$name** जोड़ा गया ($qty × ₹$price, GST: $gst%)\n\nऔर आइटम जोड़ें?',
  )(l);
  static String addMore(AppLanguage l) => _t('✅ Add More', '✅ और जोड़ें')(l);
  static String doneReview(AppLanguage l) => _t('📋 Done — Review', '📋 हो गया — समीक्षा करें')(l);
  static String saleSummary(String items, String subTotal, String gst, String grandTotal, AppLanguage l) => _t(
    '📋 **Sale Summary**\n\n$items\n\nSubtotal: **₹$subTotal**\nGST: **₹$gst**\n**Grand Total: ₹$grandTotal**\n\nSelect payment mode:',
    '📋 **बिक्री सारांश**\n\n$items\n\nउप-योग: **₹$subTotal**\nGST: **₹$gst**\n**कुल योग: ₹$grandTotal**\n\nभुगतान विधि चुनें:',
  )(l);
  static String paymentMode(AppLanguage l) => _t('Payment mode: **${0}**\n\nSave this sale?', 'भुगतान विधि: **${0}**\n\nक्या यह बिक्री सहेजनी है?')(l);
  static String cash(AppLanguage l) => _t('💵 Cash', '💵 नकद')(l);
  static String card(AppLanguage l) => _t('💳 Card', '💳 कार्ड')(l);
  static String upi(AppLanguage l) => _t('📱 UPI', '📱 UPI')(l);
  static String bank(AppLanguage l) => _t('🏦 Bank', '🏦 बैंक')(l);
  static String saveSale(AppLanguage l) => _t('✅ Save Sale', '✅ बिक्री सहेजें')(l);
  static String saveOrCancel(AppLanguage l) => _t('Save this sale?', 'क्या यह बिक्री सहेजनी है?')(l);
  static String saleSaved(String num, String total, String mode, AppLanguage l) => _t(
    '✅ **Sale created successfully!** 🎉\n\nInvoice: **$num**\nTotal: **₹$total**\nPayment: **$mode**',
    '✅ **बिक्री सफलतापूर्वक बनाई गई!** 🎉\n\nचालान: **$num**\nकुल: **₹$total**\nभुगतान: **$mode**',
  )(l);

  // Purchase flow
  static String purchaseSupplier(AppLanguage l) => _t("Let's record a purchase! 📦\n\nWhat is the supplier name?", "चलिए खरीदारी रिकॉर्ड करते हैं! 📦\n\nआपूर्तिकर्ता का नाम क्या है?")(l);
  static String purchaseSummary(String supplier, String items, String subTotal, String gst, String grandTotal, AppLanguage l) => _t(
    '📋 **Purchase Summary**\n\nSupplier: **$supplier**\n$items\n\nSubtotal: **₹$subTotal**\nGST: **₹$gst**\n**Grand Total: ₹$grandTotal**\n\nSave this purchase?',
    '📋 **खरीदारी सारांश**\n\nआपूर्तिकर्ता: **$supplier**\n$items\n\nउप-योग: **₹$subTotal**\nGST: **₹$gst**\n**कुल योग: ₹$grandTotal**\n\nक्या यह खरीदारी सहेजनी है?',
  )(l);
  static String savePurchase(AppLanguage l) => _t('✅ Save Purchase', '✅ खरीदारी सहेजें')(l);
  static String purchaseSaved(String supplier, AppLanguage l) => _t('✅ Purchase from **$supplier** has been recorded successfully!', '✅ **$supplier** से खरीदारी सफलतापूर्वक रिकॉर्ड की गई!')(l);

  // Item management
  static String removedItem(String name, AppLanguage l) => _t('Removed **$name** from the list.', '**$name** को सूची से हटा दिया गया।')(l);
  static String updatedItem(String name, String qty, String price, String gst, AppLanguage l) => _t('Updated **$name**: qty $qty, ₹$price, GST $gst%', '**$name** अपडेट किया गया: मात्रा $qty, ₹$price, GST $gst%')(l);

  // Skip / common
  static String skipGstin(AppLanguage l) => _t('⏭️ Skip GSTIN', '⏭️ GSTIN छोड़ें')(l);
  static String skipAddress(AppLanguage l) => _t('⏭️ Skip Address', '⏭️ पता छोड़ें')(l);
  static String dash(AppLanguage l) => _t('—', '—')(l);
  static String language(AppLanguage l) => _t('Language', 'भाषा')(l);
  static String english(AppLanguage l) => _t('English', 'अंग्रेज़ी')(l);
  static String hindi(AppLanguage l) => _t('हिंदी', 'हिंदी')(l);

  // App-wide UI
  static String navDashboard(AppLanguage l) => _t('Dashboard', 'डैशबोर्ड')(l);
  static String navStaff(AppLanguage l) => _t('Staff', 'स्टाफ़')(l);
  static String navPurchase(AppLanguage l) => _t('Purchase', 'खरीदारी')(l);
  static String navCustomers(AppLanguage l) => _t('Customers', 'ग्राहक')(l);
  static String navServices(AppLanguage l) => _t('Services', 'सेवाएँ')(l);
  static String navGst(AppLanguage l) => _t('GST', 'जीएसटी')(l);

  static String titleGstReports(AppLanguage l) => _t('GST Reports', 'जीएसटी रिपोर्ट')(l);
  static String titleDashboard(AppLanguage l) => _t('Dashboard', 'डैशबोर्ड')(l);
  static String titleStaff(AppLanguage l) => _t('Staff', 'स्टाफ़')(l);
  static String titlePurchase(AppLanguage l) => _t('Purchase', 'खरीदारी')(l);
  static String titleCustomers(AppLanguage l) => _t('Customers', 'ग्राहक')(l);
  static String titleServices(AppLanguage l) => _t('Services', 'सेवाएँ')(l);
  static String titleProfile(AppLanguage l) => _t('Profile', 'प्रोफ़ाइल')(l);
  static String titleInvoices(AppLanguage l) => _t('Invoices', 'चालान')(l);
  static String titleSettings(AppLanguage l) => _t('Settings', 'सेटिंग्स')(l);

  static String export(AppLanguage l) => _t('Export', 'निर्यात')(l);
  static String search(AppLanguage l) => _t('Search', 'खोजें')(l);
  static String noData(AppLanguage l) => _t('No data available', 'कोई डेटा उपलब्ध नहीं')(l);
  static String loading(AppLanguage l) => _t('Loading...', 'लोड हो रहा है...')(l);
  static String error(AppLanguage l) => _t('Something went wrong', 'कुछ गलत हो गया')(l);
  static String retry(AppLanguage l) => _t('Retry', 'पुनः प्रयास करें')(l);
  static String save(AppLanguage l) => _t('Save', 'सहेजें')(l);
  static String delete(AppLanguage l) => _t('Delete', 'हटाएँ')(l);
  static String edit(AppLanguage l) => _t('Edit', 'संपादित करें')(l);
  static String confirm(AppLanguage l) => _t('Confirm', 'पुष्टि करें')(l);
  static String cancel(AppLanguage l) => _t('Cancel', 'रद्द करें')(l);

  static String quickSale(AppLanguage l) => _t('Quick Sale', 'त्वरित बिक्री')(l);
  static String chatAssistant(AppLanguage l) => _t('Chat Assistant', 'चैट सहायक')(l);
}
