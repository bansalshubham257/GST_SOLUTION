// lib/features/invoice/data/services/bill_scanner_service.dart
// On-device OCR with fallback to pattern matching

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/scanned_bill_model.dart';

class BillScannerService {
  BillScannerService._();

  static Future<ScannedBillData> scanBillFromFile(File imageFile) async {
    String rawText = '';
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final recognizedText = await textRecognizer.processImage(inputImage);
      rawText = recognizedText.text;
      await textRecognizer.close();
    } catch (e) {
      debugPrint('ML Kit OCR error: $e');
      rawText = '';
    }
    return _parseText(rawText);
  }

  /// Parse raw bill text using regex patterns for Indian GST bills
  static ScannedBillData _parseText(String text) {
    if (text.isEmpty) {
      return const ScannedBillData(rawText: '');
    }

    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    // ── GSTINs ──────────────────────────────────────────────────────────────────
    final gstinRegex = RegExp(
      r'\b([0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1})\b',
    );
    final gstins = gstinRegex.allMatches(text).map((m) => m.group(1)!).toList();
    final supplierGstin = gstins.isNotEmpty ? gstins[0] : null;
    final customerGstin = gstins.length > 1 ? gstins[1] : null;

    // ── Phone ──────────────────────────────────────────────────────────────────
    final phoneRegex = RegExp(r'(?:phone\s*(?:number)?|mobile|mob|tel|contact)[:\s\-]*([6-9][0-9]{9})\b', caseSensitive: false);
    final phoneRegex2 = RegExp(r'(?:\+91[-\s]?)?([6-9][0-9]{9})\b');
    final phoneMatch = phoneRegex.firstMatch(text) ?? phoneRegex2.firstMatch(text);
    final phone = phoneMatch?.group(1);

    // ── Email ──────────────────────────────────────────────────────────────────
    final emailRegex = RegExp(
      r'\b([a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,})\b',
    );
    final emailMatch = emailRegex.firstMatch(text);
    final email = emailMatch?.group(1);

    // ── Invoice Number ─────────────────────────────────────────────────────────
    final invNoRegex = RegExp(
      r'(?:invoice\s*(?:no|number|#)?|inv(?:\.|#)?|bill\s*(?:no|#)?)\s*[:\-]?\s*([A-Z0-9\/\-_]{4,20})',
      caseSensitive: false,
    );
    final invNoMatch = invNoRegex.firstMatch(text);
    final invoiceNumber = invNoMatch?.group(1);

    // ── Date ──────────────────────────────────────────────────────────────────
    final dateRegex = RegExp(
      r'\b(\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4}|\d{4}[\/\-\.]\d{1,2}[\/\-\.]\d{1,2})\b',
    );
    DateTime? invoiceDate;
    final dateMatch = dateRegex.firstMatch(text);
    if (dateMatch != null) {
      invoiceDate = _parseDate(dateMatch.group(1)!);
    }

    // ── Customer Name ──────────────────────────────────────────────────────────
    String? supplierName;
    String? customerName;

    // Explicit "Customer:" / "Bill To:" / "Buyer:" labels
    final billToRegex = RegExp(
      r'(?:bill\s*to|customer|buyer|sold\s*to|recipient|client)[:\s]+([A-Za-z][A-Za-z\s&\.]{2,50})',
      caseSensitive: false,
    );
    final billToMatch = billToRegex.firstMatch(text);
    if (billToMatch != null) {
      customerName = _cleanName(billToMatch.group(1));
    }

    // Seller / supplier
    final fromRegex = RegExp(
      r'(?:from|seller|vendor|supplier|company)[:\s]+([A-Za-z][A-Za-z\s&\.]{2,50})',
      caseSensitive: false,
    );
    final fromMatch = fromRegex.firstMatch(text);
    if (fromMatch != null) {
      supplierName = _cleanName(fromMatch.group(1));
    }

    // Heuristic: first line that looks like a company name
    if (supplierName == null && lines.isNotEmpty) {
      for (final line in lines.take(5)) {
        if (_looksLikeCompanyName(line)) {
          supplierName = line;
          break;
        }
      }
    }

    // ── Customer Address ──────────────────────────────────────────────────────
    String? customerAddress;
    final addrRegex = RegExp(
      r'(?:address|addr|location)[:\s]+(.{10,100})',
      caseSensitive: false,
    );
    final addrMatch = addrRegex.firstMatch(text);
    if (addrMatch != null) {
      customerAddress = addrMatch.group(1)?.trim();
    }

    // ── Amounts ───────────────────────────────────────────────────────────────
    final amountRegex = RegExp(
      r'(?:total|grand\s+total|amount|net\s+amount)[^\d]*?([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    );
    double? totalAmount;
    final amountMatches = amountRegex.allMatches(text).toList();
    if (amountMatches.isNotEmpty) {
      totalAmount = _parseAmount(amountMatches.last.group(1) ?? '');
    }

    final taxRegex = RegExp(
      r'(?:total\s*(?:gst|tax)|gst\s*amount|tax\s*amount)[^\d]*?([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    );
    double? totalGst;
    final taxMatch = taxRegex.firstMatch(text);
    if (taxMatch != null) {
      totalGst = _parseAmount(taxMatch.group(1) ?? '');
    }

    final subtotalRegex = RegExp(
      r'(?:sub\s*total|subtotal|taxable\s*(?:amount|value))[^\d]*?([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    );
    double? subTotal;
    final subtotalMatch = subtotalRegex.firstMatch(text);
    if (subtotalMatch != null) {
      subTotal = _parseAmount(subtotalMatch.group(1) ?? '');
    }

    // ── Line Items ────────────────────────────────────────────────────────────
    final lineItems = _extractLineItems(text, lines);

    // ── Confidence Score ──────────────────────────────────────────────────────
    int fieldsFound = 0;
    if (supplierGstin != null) fieldsFound += 2;
    if (customerGstin != null) fieldsFound += 2;
    if (phone != null) fieldsFound++;
    if (email != null) fieldsFound++;
    if (invoiceNumber != null) fieldsFound++;
    if (invoiceDate != null) fieldsFound++;
    if (totalAmount != null) fieldsFound++;
    fieldsFound += lineItems.length;
    final confidence = (fieldsFound / 10.0).clamp(0.0, 1.0);

    return ScannedBillData(
      customerName: customerName,
      customerGstin: customerGstin,
      customerPhone: phone,
      customerEmail: email,
      customerAddress: customerAddress,
      supplierName: supplierName,
      supplierGstin: supplierGstin,
      invoiceNumber: invoiceNumber,
      invoiceDate: invoiceDate,
      lineItems: lineItems,
      totalAmount: totalAmount,
      totalGst: totalGst,
      subTotal: subTotal,
      rawText: text,
      confidence: confidence,
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Item Extraction — 4-strategy approach
  // ───────────────────────────────────────────────────────────────────────────

  static List<ScannedLineItem> _extractLineItems(String text, List<String> lines) {
    final items = <ScannedLineItem>[];

    // ── Strategy 1: Structured table rows ───────────────────────��─────────────
    // e.g.: "1  Product Name  2  500.00  18%  1090.00"
    final itemRowRegex = RegExp(
      r'^(\d+)\s+(.{3,50}?)\s+(\d+(?:\.\d+)?)\s+([\d,]+(?:\.\d{1,2})?)\s+([\d,]+(?:\.\d{1,2})?)$',
    );
    final hsnRegex = RegExp(r'(?:hsn|sac)[:\s#]*(\d{4,8})', caseSensitive: false);
    final gstRateInlineRegex = RegExp(r'(\d+(?:\.\d+)?)\s*%', caseSensitive: false);

    bool inItemSection = false;
    for (final line in lines) {
      if (RegExp(r'(?:sr\.?\s*no|s\.no|item|description|particulars|product)', caseSensitive: false).hasMatch(line)) {
        inItemSection = true;
        continue;
      }
      if (inItemSection && RegExp(r'(?:sub.?total|total|tax|gst|amount\s+due)', caseSensitive: false).hasMatch(line)) {
        inItemSection = false;
        continue;
      }
      if (inItemSection) {
        final match = itemRowRegex.firstMatch(line);
        if (match != null) {
          final description = match.group(2)?.trim() ?? '';
          final qty = double.tryParse(match.group(3) ?? '1') ?? 1.0;
          final price = _parseAmount(match.group(4) ?? '0');
          final total = _parseAmount(match.group(5) ?? '0');
          if (description.isNotEmpty && (price > 0 || total > 0)) {
            final hsnMatch = hsnRegex.firstMatch(line);
            final gstMatch = gstRateInlineRegex.firstMatch(line);
            items.add(ScannedLineItem(
              description: description,
              quantity: qty,
              unitPrice: price > 0 ? price : (qty > 0 ? total / qty : total),
              gstRate: _nearestGstSlab(double.tryParse(gstMatch?.group(1) ?? '18') ?? 18.0),
              amount: total,
              hsnCode: hsnMatch?.group(1),
            ));
          }
        }
      }
    }
    if (items.isNotEmpty) return items.take(20).toList();

    // ── Strategy 2: Labeled multi-line format ─────────────────────────────────
    // Handles "Item - Book", "Item Price - 500 RS", "5% GST", "Item HSN #1234"
    // Also supports multiple items if they repeat with "Item 2 -" etc.
    final labeledItems = _parseLabeledMultiLineItems(text, lines);
    if (labeledItems.isNotEmpty) return labeledItems.take(20).toList();

    // ── Strategy 3: Inline "description  qty  price" on one line ──────────────
    final priceLineRegex = RegExp(
      r'^(.{3,40}?)\s+(\d+)\s*(?:nos?\.?|pcs?\.?|units?)?\s+([\d,]+(?:\.\d{1,2})?)\b',
      caseSensitive: false,
    );
    for (final line in lines) {
      final match = priceLineRegex.firstMatch(line);
      if (match != null) {
        final desc = match.group(1)?.trim() ?? '';
        final qty = double.tryParse(match.group(2) ?? '1') ?? 1.0;
        final price = _parseAmount(match.group(3) ?? '0');
        if (desc.isNotEmpty && price > 0 &&
            !RegExp(r'(?:total|tax|gst|amount|date|invoice|phone|customer|address)',
                caseSensitive: false).hasMatch(desc)) {
          items.add(ScannedLineItem(
            description: desc,
            quantity: qty,
            unitPrice: price,
            gstRate: 18.0,
            amount: qty * price,
          ));
        }
      }
    }
    if (items.isNotEmpty) return items.take(20).toList();

    // ── Strategy 4: "Description  ₹Price" anywhere ────────────────────────────
    // e.g. "Book Rapids  500 RS" or "Book Rapids ₹500"
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      // Skip metadata lines
      if (RegExp(r'(?:customer|phone|mobile|address|invoice|date|total|tax|gst|email|from|to)',
          caseSensitive: false).hasMatch(line)) continue;

      final m = RegExp(r'^(.{2,50}?)\s+(?:rs\.?|₹)\s*([\d,]+(?:\.\d{1,2})?)',
          caseSensitive: false).firstMatch(line);
      if (m != null) {
        final desc = m.group(1)?.trim() ?? '';
        final price = _parseAmount(m.group(2) ?? '0');
        if (desc.isNotEmpty && price > 0) {
          // Look ahead for GST / HSN in next 5 lines
          double gstRate = 18.0;
          String? hsnCode;
          for (int j = i; j < lines.length && j < i + 5; j++) {
            final ctx = lines[j];
            final gm = RegExp(r'(\d+(?:\.\d+)?)\s*%', caseSensitive: false).firstMatch(ctx);
            if (gm != null) gstRate = _nearestGstSlab(double.tryParse(gm.group(1)!) ?? 18.0);
            final hm = hsnRegex.firstMatch(ctx);
            if (hm != null) hsnCode = hm.group(1);
          }
          items.add(ScannedLineItem(
            description: desc,
            quantity: 1,
            unitPrice: price,
            gstRate: gstRate,
            amount: price,
            hsnCode: hsnCode,
          ));
        }
      }
    }

    return items.take(20).toList();
  }

  /// Labeled multi-line parser.
  /// Handles formats like:
  ///   Item - Book Rapids
  ///   Item Price - 500 RS
  ///   5% GST on ITEM
  ///   Item HSN #6432892
  static List<ScannedLineItem> _parseLabeledMultiLineItems(String text, List<String> lines) {
    final items = <ScannedLineItem>[];

    // Regexes for each field type
    final itemNameRx = RegExp(
      r'^(?:item\s*(?:name|desc(?:ription)?|detail|no\.?\s*\d*)?|product|goods|description|particular|service)\s*[-:]\s*(.+)',
      caseSensitive: false,
    );
    final itemPriceRx = RegExp(
      r'^(?:item\s*)?(?:price|rate|amount|cost|value|mrp|unit\s*price)\s*[-:]\s*(?:rs\.?|₹\s*)?([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    );
    final standalonePriceRx = RegExp(
      r'(?:rs\.?\s*|₹\s*)([\d,]+(?:\.\d{1,2})?)\b|^([\d,]+(?:\.\d{1,2})?)\s*(?:rs\.?|rupees?|/-)',
      caseSensitive: false,
    );
    final gstRx = RegExp(
      r'(\d+(?:\.\d+)?)\s*%\s*(?:gst|igst|cgst|sgst|tax|on\b)?',
      caseSensitive: false,
    );
    final hsnRx = RegExp(
      r'(?:item\s+)?(?:hsn|sac)[\s:#]*(\d{4,8})',
      caseSensitive: false,
    );
    final qtyRx = RegExp(
      r'(?:qty|quantity)\s*[-:]\s*(\d+(?:\.\d+)?)|(\d+(?:\.\d+)?)\s*(?:nos?\.?|pcs?\.?|units?)',
      caseSensitive: false,
    );

    String? pendingName;
    double? pendingPrice;
    double pendingQty = 1.0;
    double? pendingGst;
    String? pendingHsn;
    bool foundAnyItemLabel = false;

    void _flush() {
      if (pendingName != null && pendingName!.isNotEmpty && (pendingPrice ?? 0) > 0) {
        items.add(ScannedLineItem(
          description: pendingName!,
          quantity: pendingQty,
          unitPrice: pendingPrice!,
          gstRate: _nearestGstSlab(pendingGst ?? 18.0),
          amount: pendingPrice! * pendingQty,
          hsnCode: pendingHsn,
        ));
      }
      pendingName = null;
      pendingPrice = null;
      pendingQty = 1.0;
      pendingGst = null;
      pendingHsn = null;
    }

    for (final line in lines) {
      // New item label — flush previous item if we had one
      final nameMatch = itemNameRx.firstMatch(line);
      if (nameMatch != null) {
        final candidate = nameMatch.group(1)?.trim() ?? '';
        // Must not look like a price/GST line
        if (!RegExp(r'^\d|price|gst|tax|rs\.?|₹|hsn', caseSensitive: false).hasMatch(candidate)) {
          if (foundAnyItemLabel && pendingName != null) _flush();
          pendingName = candidate;
          foundAnyItemLabel = true;
          continue;
        }
      }

      if (!foundAnyItemLabel) continue; // Haven't seen an item label yet

      // Price line
      final priceMatch = itemPriceRx.firstMatch(line);
      if (priceMatch != null && pendingPrice == null) {
        pendingPrice = _parseAmount(priceMatch.group(1) ?? '0');
        continue;
      }

      // Standalone price with RS / ₹
      if (pendingPrice == null) {
        final spMatch = standalonePriceRx.firstMatch(line);
        if (spMatch != null) {
          pendingPrice = _parseAmount(spMatch.group(1) ?? spMatch.group(2) ?? '0');
          if (pendingPrice == 0) pendingPrice = null;
          if (pendingPrice != null) continue;
        }
      }

      // GST rate
      final gstMatch = gstRx.firstMatch(line);
      if (gstMatch != null && pendingGst == null) {
        pendingGst = double.tryParse(gstMatch.group(1) ?? '') ?? 18.0;
        continue;
      }

      // HSN code
      final hsnMatch = hsnRx.firstMatch(line);
      if (hsnMatch != null && pendingHsn == null) {
        pendingHsn = hsnMatch.group(1);
        continue;
      }

      // Qty
      final qtyMatch = qtyRx.firstMatch(line);
      if (qtyMatch != null) {
        pendingQty = double.tryParse(qtyMatch.group(1) ?? qtyMatch.group(2) ?? '1') ?? 1.0;
      }
    }

    // Flush last item
    _flush();

    // ── Global fallback if we found no labeled item names ─────────────────────
    // But DID find price + GST + HSN labels → build one item from global context
    if (items.isEmpty && foundAnyItemLabel == false) {
      final globalName = _extractGlobalItemName(text, lines);
      final globalPrice = _extractGlobalPrice(text);
      final globalGst = _extractGlobalGstRate(text);
      final globalHsn = hsnRx.firstMatch(text)?.group(1);

      if (globalName != null && (globalPrice ?? 0) > 0) {
        items.add(ScannedLineItem(
          description: globalName,
          quantity: 1.0,
          unitPrice: globalPrice!,
          gstRate: _nearestGstSlab(globalGst ?? 18.0),
          amount: globalPrice,
          hsnCode: globalHsn,
        ));
      }
    }

    return items;
  }

  /// Try to find an item name even when there's no explicit "Item -" label.
  static String? _extractGlobalItemName(String text, List<String> lines) {
    // Look for "Item - name" even without strict label prefix
    final m = RegExp(r'\bitem\s*[-:]\s*([^\n\d]{2,60})', caseSensitive: false).firstMatch(text);
    if (m != null) {
      final candidate = m.group(1)?.trim() ?? '';
      if (!RegExp(r'price|gst|tax|hsn|rs\.?|₹', caseSensitive: false).hasMatch(candidate)) {
        return candidate;
      }
    }
    return null;
  }

  static double? _extractGlobalPrice(String text) {
    // "500 RS", "RS 500", "₹500", "Price: 500"
    final patterns = [
      RegExp(r'(?:price|rate|amount|cost)\s*[-:]\s*(?:rs\.?|₹\s*)?([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
      RegExp(r'(?:rs\.?\s*|₹\s*)([\d,]+(?:\.\d{1,2})?)\b', caseSensitive: false),
      RegExp(r'\b([\d,]+(?:\.\d{1,2})?)\s*(?:rs\.?|rupees?)', caseSensitive: false),
    ];
    for (final rx in patterns) {
      final m = rx.firstMatch(text);
      final v = _parseAmount(m?.group(1) ?? '');
      if (v > 0) return v;
    }
    return null;
  }

  static double? _extractGlobalGstRate(String text) {
    final m = RegExp(r'(\d+(?:\.\d+)?)\s*%\s*(?:gst|igst|cgst|sgst|tax|on)?', caseSensitive: false).firstMatch(text);
    if (m != null) return double.tryParse(m.group(1) ?? '');
    return null;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Helpers
  // ───────────────────────────────────────────────────────────────────────────

  static double _nearestGstSlab(double rate) {
    const slabs = [0.0, 5.0, 12.0, 18.0, 28.0];
    return slabs.reduce((a, b) => (a - rate).abs() < (b - rate).abs() ? a : b);
  }

  static String? _cleanName(String? raw) {
    if (raw == null) return null;
    // Stop at first line-break or common keywords that follow the name
    var clean = raw
        .replaceAll(RegExp(r'\n.*', dotAll: true), '')
        .replaceAll(RegExp(r'(?:phone|mobile|email|address|item|price|gst|hsn).*', caseSensitive: false, dotAll: true), '')
        .trim();
    return clean.isEmpty ? null : clean;
  }

  static double _parseAmount(String raw) {
    final cleaned = raw
        .replaceAll(',', '')
        .replaceAll(RegExp(r'₹|Rs\.?|rupees?', caseSensitive: false), '')
        .trim();
    return double.tryParse(cleaned) ?? 0.0;
  }

  static DateTime? _parseDate(String raw) {
    try {
      final parts = raw.split(RegExp(r'[\/\-\.]'));
      if (parts.length == 3) {
        int? day, month, year;
        if (parts[0].length == 4) {
          year = int.tryParse(parts[0]);
          month = int.tryParse(parts[1]);
          day = int.tryParse(parts[2]);
        } else {
          day = int.tryParse(parts[0]);
          month = int.tryParse(parts[1]);
          year = int.tryParse(parts[2]);
          if (year != null && year < 100) year += 2000;
        }
        if (day != null && month != null && year != null) {
          return DateTime(year, month, day);
        }
      }
    } catch (_) {}
    return null;
  }

  static bool _looksLikeCompanyName(String line) {
    if (line.length < 3 || line.length > 80) return false;
    if (RegExp(r'\d{6,}').hasMatch(line)) return false;
    if (RegExp(r'[0-9]{2}[A-Z]{5}').hasMatch(line)) return false;
    if (RegExp(r'(?:invoice|date|phone|email|address|total|tax|gst|item|price)',
        caseSensitive: false).hasMatch(line)) return false;
    return RegExp(r'^[A-Za-z][A-Za-z\s&\.,\-\(\)]{2,}').hasMatch(line);
  }
}

