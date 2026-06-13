// lib/core/utils/chat_strings.dart
//
// All bilingual strings for the Invoice Chat feature.
// Extend this file to add more languages.

import '../providers/language_provider.dart';

class ChatStrings {
  final AppLanguage lang;
  const ChatStrings(this.lang);

  bool get isHindi => lang == AppLanguage.hindi;

  // ─── Welcome ─────────────────────────────────────────────────────────────────

  String welcome({bool hasCustomers = false, bool hasCatalog = false}) {
    final tips = <String>[];
    if (hasCustomers) tips.add(isHindi ? '💡 सेव किए ग्राहक चुनें' : '💡 Select from saved customers');
    if (hasCatalog) tips.add(isHindi ? '💡 आइटम कैटलॉग से चुनें' : '💡 Select from item catalog');
    final tipText = tips.isNotEmpty ? '\n\n${tips.join('\n')}' : '';

    return isHindi
        ? '👋 नमस्ते! मैं आपका **इनवॉइस सहायक** हूँ।\n\n'
            'इस चैट के ज़रिए मैं GST इनवॉइस बनाऊँगा।$tipText\n\n'
            '**यह इनवॉइस किसके लिए है?**'
        : '👋 Hi! I\'m your **Invoice Assistant**.\n\n'
            'I\'ll create a GST invoice through this chat.$tipText\n\n'
            '**Who is this invoice for?**';
  }

  // ─── Customer ────────────────────────────────────────────────────────────────

  String invalidName() => isHindi
      ? 'कृपया एक वैध नाम दर्ज करें।'
      : 'Please enter a valid name.';

  String customerFoundAskItem(String name, String? phone, String? gstin,
      {bool hasCatalog = false}) {
    final phoneStr = phone != null ? (isHindi ? '\n📱 $phone' : '\n📱 $phone') : '';
    final gstinStr = gstin != null ? '\n🏢 $gstin' : '';
    final catalogHint = hasCatalog
        ? (isHindi ? '\nकैटलॉग से चुनें 👇' : '\nPick from catalog 👇')
        : '';
    return isHindi
        ? '✅ ग्राहक: **$name**$phoneStr$gstinStr\n\n🛍 **पहला आइटम/सेवा क्या है?**$catalogHint'
        : '✅ Customer: **$name**$phoneStr$gstinStr\n\n🛍 **What is the first item/service?**$catalogHint';
  }

  String askCustomerPhone(String name) => isHindi
      ? '✅ ग्राहक: **$name**\n\n**मोबाइल नंबर?** (10 अंक)'
      : '✅ Customer: **$name**\n\n**Mobile number?** (10 digits)';

  String invalidPhone() => isHindi
      ? 'वैध 10-अंकों का नंबर दर्ज करें या **${skip()}** टाइप करें।'
      : 'Enter valid 10-digit number or **skip**.';

  String phoneSavedAskGstin(String phone, bool skipped) => isHindi
      ? '${skipped ? '⏭ फोन छोड़ दिया।' : '✅ फोन: **$phone**'}\n\n**GSTIN?** (15 अक्षर, या ${skip()})'
      : '${skipped ? '⏭ Phone skipped.' : '✅ Phone: **$phone**'}\n\n**GSTIN?** (15 chars, or skip)';

  String invalidGstin() => isHindi
      ? 'अमान्य GSTIN। फॉर्मेट: **27AABCU9603R1ZX** या **${skip()}**'
      : 'Invalid GSTIN. Format: **27AABCU9603R1ZX** or **skip**';

  String gstinSavedAskItem(String gstin, bool skipped,
      {bool hasCatalog = false}) {
    final catalogHint = hasCatalog
        ? (isHindi ? '\nकैटलॉग से चुनें 👇' : '\nPick from catalog 👇')
        : '';
    return isHindi
        ? '${skipped ? '⏭ GSTIN छोड़ दिया।' : '✅ GSTIN: **$gstin**'}\n\n🛍 **पहला आइटम/सेवा क्या है?**$catalogHint'
        : '${skipped ? '⏭ GSTIN skipped.' : '✅ GSTIN: **$gstin**'}\n\n🛍 **What is the first item/service?**$catalogHint';
  }

  // ─── Items ───────────────────────────────────────────────────────────────────

  String invalidItemName() => isHindi
      ? 'एक वैध आइटम नाम दर्ज करें।'
      : 'Enter a valid item name.';

  String catalogItemFound(String name, double price, double gstRate,
      String unit) =>
      isHindi
          ? '✅ **$name** (कैटलॉग से)\n💰 ₹${price.toStringAsFixed(0)}/नग · ${gstRate.toStringAsFixed(0)}% GST\n\n**कितने $unit?**'
          : '✅ **$name** (from catalog)\n💰 ₹${price.toStringAsFixed(0)}/unit · ${gstRate.toStringAsFixed(0)}% GST\n\n**How many $unit?**';

  String itemNameSavedAskQty(String name) => isHindi
      ? '✅ आइटम: **$name**\n\n**मात्रा?**'
      : '✅ Item: **$name**\n\n**Quantity?**';

  String invalidQty() => isHindi
      ? 'वैध मात्रा दर्ज करें।'
      : 'Enter valid quantity.';

  String qtySavedAskPrice(double qty, String unit) => isHindi
      ? '✅ मात्रा: **$qty $unit**\n\n**प्रति नग कीमत ₹ में?**'
      : '✅ Qty: **$qty $unit**\n\n**Unit price in ₹?**';

  String qtyCatalogAskGst(double qty, String unit, double price) => isHindi
      ? '✅ मात्रा: **$qty $unit**\n💰 कीमत: ₹${price.toStringAsFixed(0)} (कैटलॉग)\n\n**GST दर?**'
      : '✅ Qty: **$qty $unit**\n💰 Price: ₹${price.toStringAsFixed(0)} (catalog)\n\n**GST rate?**';

  String invalidPrice() => isHindi
      ? 'वैध ₹ कीमत दर्ज करें।'
      : 'Enter valid ₹ price.';

  String priceSavedAskGst(double price) => isHindi
      ? '✅ कीमत: **₹${price.toStringAsFixed(0)}**\n\n**GST दर?**'
      : '✅ Price: **₹${price.toStringAsFixed(0)}**\n\n**GST rate?**';

  String invalidGstRate() => isHindi
      ? 'चुनें: **0%, 5%, 12%, 18%, या 28%**'
      : 'Choose: **0%, 5%, 12%, 18%, or 28%**';

  String itemAddedAskSave(String name, double qty, double price, double gst) =>
      isHindi
          ? '✅ जोड़ा: **$name** × ${qty.toStringAsFixed(0)} @ ₹${price.toStringAsFixed(0)} + ${gst.toStringAsFixed(0)}% GST\n\n'
              '💾 **"$name"** को आइटम कैटलॉग में सेव करें?\n_(अगली बार जल्दी चुनने के लिए)_'
          : '✅ Added: **$name** × ${qty.toStringAsFixed(0)} @ ₹${price.toStringAsFixed(0)} + ${gst.toStringAsFixed(0)}% GST\n\n'
              '💾 Save **"$name"** to your item catalog?\n_(So you can select it faster next time)_';

  String askMoreItems(String itemName, int count, {bool saved = false}) {
    final savedNote = saved ? (isHindi ? '\n✅ कैटलॉग में सेव हो गया!' : '\n✅ Saved to catalog!') : '';
    return isHindi
        ? '📦 **$itemName** जोड़ा।$savedNote\n\n**$count आइटम इनवॉइस में।**\n\nऔर आइटम जोड़ें या इनवॉइस देखें?'
        : '📦 **$itemName** added.$savedNote\n\n**$count item${count > 1 ? 's' : ''} in invoice.**\n\nAdd another item or review invoice?';
  }

  String needAtLeastOneItem() => isHindi
      ? 'कम से कम एक आइटम ज़रूरी है! **आइटम का नाम?**'
      : 'Need at least one item! **Item name?**';

  String nextItemAsk({bool hasCatalog = false}) {
    final hint = hasCatalog
        ? (isHindi ? '\nकैटलॉग से चुनें 👇' : '\nPick from catalog 👇')
        : '';
    return isHindi
        ? 'अगला **आइटम या सेवा** क्या है?$hint'
        : 'What\'s the next **item or service?**$hint';
  }

  // ─── Summary ─────────────────────────────────────────────────────────────────

  String summary({
    required String customerName,
    String? phone,
    String? gstin,
    required String itemsStr,
    required int itemCount,
    required double subTotal,
    required double totalGst,
    required double grandTotal,
  }) {
    final phoneStr = phone != null ? ' · 📱 $phone' : '';
    final gstinStr = gstin != null ? '\n🏢 $gstin' : '';
    return isHindi
        ? '📋 **इनवॉइस सारांश**\n\n'
            '👤 **$customerName**$phoneStr$gstinStr\n\n'
            '📦 **आइटम ($itemCount):**\n$itemsStr\n\n'
            '💰 उप-कुल: ₹${subTotal.toStringAsFixed(2)}\n'
            '🧾 GST: ₹${totalGst.toStringAsFixed(2)}\n'
            '━━━━━━━━━━━━━━━━\n'
            '💵 **कुल: ₹${grandTotal.toStringAsFixed(2)}**\n\n'
            '**इनवॉइस बनाना है? पुष्टि करें।**'
        : '📋 **Invoice Summary**\n\n'
            '👤 **$customerName**$phoneStr$gstinStr\n\n'
            '📦 **Items ($itemCount):**\n$itemsStr\n\n'
            '💰 Sub Total: ₹${subTotal.toStringAsFixed(2)}\n'
            '🧾 GST: ₹${totalGst.toStringAsFixed(2)}\n'
            '━━━━━━━━━━━━━━━━\n'
            '💵 **Grand Total: ₹${grandTotal.toStringAsFixed(2)}**\n\n'
            '**Confirm to create invoice?**';
  }

  String invoiceCreated({
    required String invoiceNumber,
    required String customerName,
    required int itemCount,
    required double grandTotal,
  }) =>
      isHindi
          ? '🎉 **इनवॉइस बन गया!**\n\n'
              '📋 **$invoiceNumber**\n'
              '👤 $customerName\n'
              '📦 $itemCount आइटम\n'
              '💵 **₹${grandTotal.toStringAsFixed(2)}**\n\n'
              '💾 **$customerName** को संपर्क सूची में सेव करें?'
          : '🎉 **Invoice Created!**\n\n'
              '📋 **$invoiceNumber**\n'
              '👤 $customerName\n'
              '📦 $itemCount item${itemCount > 1 ? 's' : ''}\n'
              '💵 **₹${grandTotal.toStringAsFixed(2)}**\n\n'
              '💾 Save **$customerName** to your contacts?';

  String customerSaved(String name) => isHindi
      ? '✅ **$name** संपर्क सूची में सेव! 🎊\n\n_नीचे **इनवॉइस देखें** टैप करें।_'
      : '✅ **$name** saved to contacts! 🎊\n\n_Tap **View Invoice** below._';

  String skippedViewInvoice() => isHindi
      ? '⏭ छोड़ दिया।\n\n_नीचे **इनवॉइस देखें** टैप करें।_'
      : '⏭ Skipped.\n\n_Tap **View Invoice** below._';

  String editItems() => isHindi
      ? 'ठीक है, आइटम फिर से डालें। **पहला आइटम?**'
      : 'Let\'s redo items. First **item/service?**';

  String confirmHint() => isHindi
      ? 'टाइप करें **पुष्टि** ✅ · **बदलें** ✏️ · **पुनः शुरू** 🔄'
      : 'Type **confirm** ✅ · **edit** ✏️ · **restart** 🔄';

  String typeRestart() => isHindi
      ? 'फिर से शुरू करने के लिए **restart** टाइप करें।'
      : 'Type **restart** to begin again.';

  // ─── Language Switch ──────────────────────────────────────────────────────────

  String languageSwitched() => isHindi
      ? '🇮🇳 **हिंदी** में बदल दिया। अब हिंदी में बात करें।'
      : '🇬🇧 Switched to **English**. You can now type in English.';

  // ─── Quick Replies ────────────────────────────────────────────────────────────

  String skip() => isHindi ? 'छोड़ें' : 'Skip';
  String confirm() => isHindi ? 'पुष्टि करें ✅' : 'Confirm ✅';
  String editItemsBtn() => isHindi ? 'आइटम बदलें ✏️' : 'Edit Items ✏️';
  String restart() => isHindi ? 'फिर से शुरू 🔄' : 'Restart 🔄';
  String saveItem() => isHindi ? '✅ सेव करें' : '✅ Save Item';
  String addMoreItems() => isHindi ? '➕ और जोड़ें' : '➕ Add Another Item';
  String reviewConfirm() => isHindi ? '✅ देखें और पुष्टि करें' : '✅ Review & Confirm';
  String saveCustomer() => isHindi ? '✅ सेव करें' : '✅ Save Customer';

  // ─── Input Hints ─────────────────────────────────────────────────────────────

  String hintCustomerName() => isHindi
      ? 'ग्राहक या कंपनी का नाम...'
      : 'Customer or company name...';

  String hintPhone() => isHindi
      ? '10 अंकों का नंबर या "छोड़ें"...'
      : '10-digit mobile or "skip"...';

  String hintGstin() => isHindi
      ? 'GSTIN या "छोड़ें"...'
      : 'GSTIN or "skip"...';

  String hintItemName() => isHindi
      ? 'आइटम का नाम, या "5 लैपटॉप 50000 में 18% GST"...'
      : 'Item name, or "5 laptops at ₹50000 18% GST"...';

  String hintQty() => isHindi
      ? 'मात्रा (जैसे 5, 2.5)...'
      : 'Quantity (e.g. 5, 2.5)...';

  String hintPrice() => isHindi
      ? '₹ में कीमत...'
      : 'Unit price in ₹...';

  String hintGst() => isHindi
      ? 'GST दर: 0, 5, 12, 18, या 28%...'
      : 'GST rate: 0, 5, 12, 18, or 28%...';

  String hintMoreItems() => isHindi
      ? '"जोड़ें" या "देखें"...'
      : '"add" for more or "review" to confirm...';

  String hintSummary() => isHindi
      ? '"पुष्टि" या "बदलें"...'
      : '"confirm" to create or "edit" to change...';

  String hintDefault() => isHindi ? 'संदेश लिखें...' : 'Type a message...';

  // ─── Voice Prompts ────────────────────────────────────────────────────────────

  String voicePromptItem() => isHindi
      ? 'आइटम का नाम, कीमत और GST बोलें'
      : 'Say item name, price and GST rate';

  String voicePromptCustomer() => isHindi
      ? 'नाम, फोन नंबर बोलें'
      : 'Say customer name and phone number';

  String voicePromptChat() => isHindi ? 'बोलें...' : 'Speak now...';

  // ─── Step Labels ─────────────────────────────────────────────────────────────

  String stepCustomer() => isHindi ? '👤 ग्राहक' : '👤 Customer';
  String stepCustomerDetails() => isHindi ? '📋 ग्राहक विवरण' : '📋 Customer Details';
  String stepItemName() => isHindi ? '📦 आइटम नाम' : '📦 Item Name';
  String stepQty() => isHindi ? '🔢 मात्रा' : '🔢 Quantity';
  String stepPrice() => isHindi ? '💰 कीमत' : '💰 Price';
  String stepGst() => isHindi ? '🧾 GST दर' : '🧾 GST Rate';
  String stepSaveItem() => isHindi ? '💾 आइटम सेव करें?' : '💾 Save Item?';
  String stepMoreItems() => isHindi ? '➕ और आइटम?' : '➕ More Items?';
  String stepReview() => isHindi ? '📋 समीक्षा' : '📋 Review';
  String stepSaveCustomer() => isHindi ? '💾 ग्राहक सेव करें?' : '💾 Save Customer?';
  String stepDone() => isHindi ? '✅ हो गया!' : '✅ Done!';

  // ─── Voice Sheet UI ───────────────────────────────────────────────────────────

  String voiceSheetItemTitle() =>
      isHindi ? 'आवाज़ से आइटम जोड़ें' : 'Add Item by Voice';

  String voiceSheetItemSubtitle() =>
      isHindi ? 'आइटम का नाम, कीमत, GST और यूनिट बोलें' : 'Say item name, price, GST rate & unit';

  String voiceSheetItemEx1() =>
      isHindi ? '"लैपटॉप 50000 रुपये 18 प्रतिशत GST"' : '"Laptop 50000 rupees 18 percent GST"';

  String voiceSheetItemEx2() =>
      isHindi ? '"स्टील रॉड 500 प्रति किलो 5 प्रतिशत"' : '"Steel rod at 500 per kilogram 5 percent"';

  String voiceSheetItemEx3() =>
      isHindi ? '"वेब डिज़ाइन सेवा 15000 18 GST"' : '"Web design service 15000 18 GST"';

  String voiceSheetCustomerTitle() =>
      isHindi ? 'आवाज़ से ग्राहक जोड़ें' : 'Add Customer by Voice';

  String voiceSheetCustomerSubtitle() =>
      isHindi ? 'नाम, फोन, GSTIN, शहर बोलें' : 'Say name, phone, email, GSTIN, city';

  String voiceSheetCustomerEx1() =>
      isHindi ? '"राहुल शर्मा फोन 9876543210"' : '"Rahul Sharma phone 9876543210"';

  String voiceSheetCustomerEx2() =>
      isHindi ? '"इन्फोसिस लिमिटेड GSTIN 29AABCI1681G1ZX शहर बंगलोर"' : '"Infosys Limited GSTIN 29AABCI1681G1ZX city Bangalore"';

  String voiceListeningTxt() =>
      isHindi ? '🎙 सुन रहा हूँ — रोकने के लिए टैप करें' : '🎙 Listening — tap to stop';

  String voiceDoneTxt() =>
      isHindi ? '✅ हो गया — नीचे देखें' : '✅ Done — check below';

  String voiceIdleTxt() =>
      isHindi ? 'माइक दबाएं' : 'Tap mic to start';

  String voiceTranscriptLabel() => isHindi ? 'पहचाना गया:' : 'Recognised:';

  String voiceDetectedLabel() => isHindi ? '✅ पहचाना गया:' : '✅ Detected:';

  String voiceNoFields() =>
      isHindi ? '⚠ कोई जानकारी नहीं मिली। फिर से बोलें।' : '⚠ Could not detect fields. Try again.';

  String fillFormBtn() => isHindi ? 'फ़ॉर्म भरें' : 'Fill Form';
  String cancelBtn() => isHindi ? 'रद्द करें' : 'Cancel';
  String formFilledMsg() =>
      isHindi ? '✅ फ़ॉर्म आवाज़ से भर दिया!' : '✅ Form filled from voice!';

  // ─── Detected field labels ────────────────────────────────────────────────────

  String fieldName() => isHindi ? 'नाम' : 'Name';
  String fieldPrice() => isHindi ? 'कीमत' : 'Price';
  String fieldGst() => isHindi ? 'GST दर' : 'GST Rate';
  String fieldUnit() => isHindi ? 'यूनिट' : 'Unit';
  String fieldType() => isHindi ? 'प्रकार' : 'Type';
  String fieldPhone() => isHindi ? 'फोन' : 'Phone';
  String fieldEmail() => isHindi ? 'ईमेल' : 'Email';
  String fieldGstin() => 'GSTIN';
  String fieldCity() => isHindi ? 'शहर' : 'City';
  String fieldPincode() => isHindi ? 'पिनकोड' : 'Pincode';
  String typeProduct() => isHindi ? 'उत्पाद' : 'Product';
  String typeService() => isHindi ? 'सेवा' : 'Service';

  // ─── Examples hint label ─────────────────────────────────────────────────────

  String exampleLabel() => isHindi ? '💡 उदाहरण:' : '💡 Example phrases:';
}

// ─── Hindi NLP Utils ──────────────────────────────────────────────────────────

class HindiNLP {
  HindiNLP._();

  /// Convert Devanagari digit characters to ASCII digits.
  static String convertDevanagariDigits(String text) {
    const devanagariDigits = '०१२३४५६७८९';
    var result = text;
    for (int i = 0; i < devanagariDigits.length; i++) {
      result = result.replaceAll(devanagariDigits[i], '$i');
    }
    return result;
  }

  /// True if the input indicates "yes" / confirm in Hindi.
  static bool isYes(String lower) {
    return lower == 'हाँ' ||
        lower == 'हां' ||
        lower == 'हा' ||
        lower.contains('ठीक है') ||
        lower.contains('ठीक') ||
        lower.contains('पक्का') ||
        lower.contains('पुष्टि') ||
        lower.contains('जी') ||
        lower.contains('जी हाँ') ||
        lower.contains('बनाओ') ||
        lower.contains('बनाएं') ||
        lower.contains('बना दो') ||
        lower.contains('सेव') ||
        lower.contains('save');
  }

  /// True if the input indicates "skip" in Hindi.
  static bool isSkip(String lower) {
    return lower.contains('छोड़') ||
        lower.contains('नहीं') ||
        lower.contains('ना') ||
        lower.startsWith('skip') ||
        lower.startsWith('स्किप');
  }

  /// True if "add more" in Hindi.
  static bool isAddMore(String lower) {
    return lower.contains('और') ||
        lower.contains('जोड़') ||
        lower.contains('ज़्यादा') ||
        lower.contains('एक और') ||
        lower.contains('add') ||
        lower.contains('more') ||
        lower.contains('another') ||
        lower.contains('➕');
  }

  /// True if "review / confirm" in Hindi.
  static bool isReview(String lower) {
    return lower.contains('देख') ||
        lower.contains('समीक्षा') ||
        lower.contains('review') ||
        lower.contains('confirm') ||
        lower.contains('✅');
  }

  /// True if "restart" in Hindi.
  static bool isRestart(String lower) {
    return lower.contains('restart') ||
        lower.contains('फिर से') ||
        lower.contains('शुरू से') ||
        lower.contains('🔄');
  }

  /// True if "edit items" in Hindi.
  static bool isEdit(String lower) {
    return lower.contains('edit') ||
        lower.contains('बदल') ||
        lower.contains('✏️');
  }

  /// Extract a number from Hindi text.
  /// Handles Devanagari digits, Hindi number words, and regular digits.
  static double? extractNumber(String text) {
    // First convert Devanagari digits
    text = convertDevanagariDigits(text);

    // Try direct number extraction
    final directMatch = RegExp(r'[\d,]+\.?\d*').firstMatch(text.replaceAll(',', ''));
    if (directMatch != null) {
      return double.tryParse(directMatch.group(0)!.replaceAll(',', ''));
    }

    // Hindi number words
    final hindiNumbers = {
      'शून्य': 0, 'एक': 1, 'दो': 2, 'तीन': 3, 'चार': 4,
      'पाँच': 5, 'पांच': 5, 'छह': 6, 'छः': 6, 'सात': 7,
      'आठ': 8, 'नौ': 9, 'दस': 10, 'ग्यारह': 11, 'बारह': 12,
      'तेरह': 13, 'चौदह': 14, 'पंद्रह': 15, 'सोलह': 16,
      'सत्रह': 17, 'अठारह': 18, 'उन्नीस': 19, 'बीस': 20,
      'पचास': 50, 'सौ': 100, 'हज़ार': 1000, 'हजार': 1000,
      'लाख': 100000, 'करोड': 10000000,
    };

    for (final entry in hindiNumbers.entries) {
      if (text.contains(entry.key)) {
        return entry.value.toDouble();
      }
    }
    return null;
  }

  /// Extract GST rate from Hindi text (handles प्रतिशत, फीसदी, %).
  static double? extractGstRate(String text) {
    text = convertDevanagariDigits(text);
    final gstM = RegExp(r'(\d+)\s*(?:%|प्रतिशत|फीसदी|percent|gst|जीएसटी)').firstMatch(text.toLowerCase());
    if (gstM != null) {
      final r = double.tryParse(gstM.group(1)!);
      const valid = [0.0, 5.0, 12.0, 18.0, 28.0];
      if (r != null && valid.contains(r)) return r;
    }
    return null;
  }

  /// Normalize Hindi unit names to English short forms.
  static String? extractUnit(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('किलो') || lower.contains('kg') || lower.contains('kgs')) return 'Kg';
    if (lower.contains('लीटर') || lower.contains('ltr') || lower.contains('litre')) return 'Ltr';
    if (lower.contains('नग') || lower.contains('nos') || lower.contains('pcs') ||
        lower.contains('पीस') || lower.contains('piece')) return 'Pcs';
    if (lower.contains('बॉक्स') || lower.contains('box')) return 'Box';
    if (lower.contains('बैग') || lower.contains('bag') || lower.contains('थैला')) return 'Bag';
    if (lower.contains('घंटा') || lower.contains('hour') || lower.contains('hr')) return 'Hr';
    if (lower.contains('मीटर') || lower.contains('meter') || lower.contains('mtr')) return 'Mtr';
    if (lower.contains('दिन') || lower.contains('day')) return 'Day';
    if (lower.contains('महीना') || lower.contains('month')) return 'Month';
    return null;
  }
}

