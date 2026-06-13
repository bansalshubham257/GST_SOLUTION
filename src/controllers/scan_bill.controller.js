// backend/src/controllers/scan_bill.controller.js
// Smart bill parser using regex patterns for Indian GST bills

/**
 * Extract structured data from raw OCR text of an Indian GST bill/invoice.
 * Supports various bill formats: thermal receipts, printed invoices, handwritten bills.
 */
function parseBillText(text) {
  if (!text || text.trim().length === 0) {
    return { success: false, error: 'Empty text provided', data: null };
  }

  const lines = text.split('\n').map(l => l.trim()).filter(l => l.length > 0);

  // ── GSTINs ─────────────────────────────────────────────────────────────────
  const gstinRegex = /\b([0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1})\b/g;
  const gstins = [...text.matchAll(gstinRegex)].map(m => m[1]);
  const supplierGstin = gstins[0] || null;
  const customerGstin = gstins[1] || null;

  // ── Phone ──────────────────────────────────────────────────────────────────
  const phoneRegex = /(?:\+91[-\s]?)?([6-9][0-9]{9})\b/g;
  const phones = [...text.matchAll(phoneRegex)].map(m => m[1]);
  const phone = phones[0] || null;

  // ── Email ──────────────────────────────────────────────────────────────────
  const emailRegex = /\b([a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,})\b/;
  const emailMatch = text.match(emailRegex);
  const email = emailMatch ? emailMatch[1] : null;

  // ── Invoice Number ─────────────────────────────────────────────────────────
  const invNoRegex = /(?:invoice\s*(?:no|number|#)?|inv(?:\.|#)?|bill\s*(?:no|#)?)\s*[:\-]?\s*([A-Z0-9\/\-_]{4,20})/i;
  const invNoMatch = text.match(invNoRegex);
  const invoiceNumber = invNoMatch ? invNoMatch[1] : null;

  // ── Date ──────────────────────────────────────────────────────────────────
  const dateRegex = /\b(\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4}|\d{4}[\/\-\.]\d{1,2}[\/\-\.]\d{1,2})\b/;
  const dateMatch = text.match(dateRegex);
  let invoiceDate = null;
  if (dateMatch) {
    invoiceDate = parseDate(dateMatch[1]);
  }

  // ── Company / Customer Names ───────────────────────────────────────────────
  let supplierName = null;
  let customerName = null;

  const billToRegex = /(?:bill\s*to|customer|buyer|sold\s*to|recipient)[:\s]+([A-Za-z][A-Za-z\s&\.]{2,50})/i;
  const billToMatch = text.match(billToRegex);
  if (billToMatch) customerName = billToMatch[1].trim();

  const fromRegex = /(?:from|seller|vendor|supplier|company)[:\s]+([A-Za-z][A-Za-z\s&\.]{2,50})/i;
  const fromMatch = text.match(fromRegex);
  if (fromMatch) supplierName = fromMatch[1].trim();

  // Try to infer supplier name from first non-numeric line
  if (!supplierName) {
    for (const line of lines.slice(0, 5)) {
      if (looksLikeCompanyName(line)) {
        supplierName = line;
        break;
      }
    }
  }

  // ── Address ────────────────────────────────────────────────────────────────
  let customerAddress = null;
  const addrRegex = /(?:address|addr|location)[:\s]+(.{10,100})/i;
  const addrMatch = text.match(addrRegex);
  if (addrMatch) customerAddress = addrMatch[1].trim();

  // ── Amounts ────────────────────────────────────────────────────────────────
  const amountRegex = /(?:total|grand\s+total|amount|net\s+amount)[^\d]*([\d,]+(?:\.\d{1,2})?)/gi;
  const amountMatches = [...text.matchAll(amountRegex)];
  let totalAmount = null;
  if (amountMatches.length > 0) {
    totalAmount = parseAmount(amountMatches[amountMatches.length - 1][1]);
  }

  const taxRegex = /(?:total\s*(?:gst|tax)|gst\s*amount|tax\s*amount)[^\d]*([\d,]+(?:\.\d{1,2})?)/i;
  const taxMatch = text.match(taxRegex);
  const totalGst = taxMatch ? parseAmount(taxMatch[1]) : null;

  const subtotalRegex = /(?:sub\s*total|subtotal|taxable\s*(?:amount|value))[^\d]*([\d,]+(?:\.\d{1,2})?)/i;
  const subtotalMatch = text.match(subtotalRegex);
  const subTotal = subtotalMatch ? parseAmount(subtotalMatch[1]) : null;

  // ── GST Rate ───────────────────────────────────────────────────────────────
  const gstRateRegex = /\b(5|12|18|28)%?\s*(?:gst|igst|cgst|sgst)?\b/i;
  const gstRateMatch = text.match(gstRateRegex);
  const defaultGstRate = gstRateMatch ? parseFloat(gstRateMatch[1]) : 18;

  // ── Line Items ─────────────────────────────────────────────────────────────
  const lineItems = extractLineItems(text, lines, defaultGstRate);

  // ── Confidence Score ───────────────────────────────────────────────────────
  let fieldsFound = 0;
  if (supplierGstin) fieldsFound += 2;
  if (customerGstin) fieldsFound += 2;
  if (phone) fieldsFound++;
  if (email) fieldsFound++;
  if (invoiceNumber) fieldsFound++;
  if (invoiceDate) fieldsFound++;
  if (totalAmount) fieldsFound++;
  fieldsFound += Math.min(lineItems.length, 5);
  const confidence = Math.min(fieldsFound / 12, 1.0);

  return {
    success: true,
    data: {
      customerName,
      customerGstin,
      customerPhone: phone,
      customerEmail: email,
      customerAddress,
      supplierName,
      supplierGstin,
      invoiceNumber,
      invoiceDate: invoiceDate ? invoiceDate.toISOString() : null,
      lineItems,
      totalAmount,
      totalGst,
      subTotal,
      rawText: text,
      confidence,
    },
  };
}

function extractLineItems(text, lines, defaultGstRate) {
  const items = [];

  // Pattern: number + description + qty + price + total
  const itemRowRegex = /^(\d+)\s+(.{3,50}?)\s+(\d+(?:\.\d+)?)\s+([\d,]+(?:\.\d{1,2})?)\s+([\d,]+(?:\.\d{1,2})?)$/;
  const hsnRegex = /\b(\d{4,8})\b/;
  const gstRateRegex = /\b(5|12|18|28)%?\s*(?:gst|igst|cgst|sgst)?\b/i;

  let inItemSection = false;

  for (const line of lines) {
    if (/(?:sr\.?\s*no|s\.no|item|description|particulars|product)/i.test(line)) {
      inItemSection = true;
      continue;
    }
    if (inItemSection && /(?:sub.?total|total|tax|gst|amount\s+due)/i.test(line)) {
      inItemSection = false;
      continue;
    }

    if (inItemSection) {
      const match = line.match(itemRowRegex);
      if (match) {
        const description = match[2].trim();
        const qty = parseFloat(match[3]) || 1;
        const price = parseAmount(match[4]);
        const total = parseAmount(match[5]);

        if (description && (price > 0 || total > 0)) {
          const hsnMatch = line.match(hsnRegex);
          const gstMatch = text.match(gstRateRegex);
          items.push({
            description,
            quantity: qty,
            unitPrice: price > 0 ? price : (qty > 0 ? total / qty : total),
            gstRate: gstMatch ? parseFloat(gstMatch[1]) : defaultGstRate,
            amount: total,
            hsnCode: hsnMatch ? hsnMatch[1] : null,
          });
        }
      }
    }
  }

  // Fallback: look for price-like lines
  if (items.length === 0) {
    const priceLineRegex = /^(.{3,40}?)\s+(\d+)\s*(?:nos?|pcs?|units?)?\s+([\d,]+(?:\.\d{1,2})?)$/i;
    for (const line of lines) {
      const match = line.match(priceLineRegex);
      if (match) {
        const desc = match[1].trim();
        const qty = parseFloat(match[2]) || 1;
        const price = parseAmount(match[3]);
        if (desc && price > 0 && !/(?:total|tax|gst|amount|date|invoice)/i.test(desc)) {
          items.push({
            description: desc,
            quantity: qty,
            unitPrice: price,
            gstRate: defaultGstRate,
            amount: qty * price,
            hsnCode: null,
          });
        }
      }
    }
  }

  return items.slice(0, 20);
}

function parseAmount(raw) {
  if (!raw) return 0;
  const cleaned = raw.toString().replace(/,/g, '').replace(/[₹Rs]/g, '').trim();
  return parseFloat(cleaned) || 0;
}

function parseDate(raw) {
  try {
    const parts = raw.split(/[\/\-\.]/);
    if (parts.length === 3) {
      let day, month, year;
      if (parts[0].length === 4) {
        [year, month, day] = parts.map(Number);
      } else {
        [day, month, year] = parts.map(Number);
        if (year < 100) year += 2000;
      }
      const d = new Date(year, month - 1, day);
      return isNaN(d.getTime()) ? null : d;
    }
  } catch (_) {}
  return null;
}

function looksLikeCompanyName(line) {
  if (!line || line.length < 3 || line.length > 80) return false;
  if (/\d{6,}/.test(line)) return false;
  if (/[0-9]{2}[A-Z]{5}/.test(line)) return false;
  if (/(?:invoice|date|phone|email|address|total|tax|gst)/i.test(line)) return false;
  return /^[A-Za-z][A-Za-z\s&\.,\-\(\)]{2,}/.test(line);
}

// ─── Controller ───────────────────────────────────────────────────────────────

/**
 * POST /api/v1/invoices/scan-bill
 * Accepts:
 *   - multipart/form-data with image file (field: "bill")
 *   - OR application/json with { text: "raw OCR text" }
 */
async function scanBill(req, res, next) {
  try {
    let rawText = '';

    // Case 1: text sent directly (from Flutter ML Kit extraction)
    if (req.body && req.body.text) {
      rawText = req.body.text;
    }

    // Case 2: image file uploaded — in a production app, you'd run OCR here
    // e.g., using Google Cloud Vision API or Tesseract.js
    if (req.file && !rawText) {
      // Placeholder: in production, call your OCR service here
      // const visionResult = await googleCloudVision.detectText(req.file.buffer);
      // rawText = visionResult.text;

      // For now, return a message indicating server-side OCR is not configured
      return res.status(422).json({
        success: false,
        error: 'Server-side OCR requires Google Cloud Vision API setup. Please use the app\'s on-device scan feature.',
        hint: 'Send extracted text via the "text" field instead.',
      });
    }

    if (!rawText) {
      return res.status(400).json({
        success: false,
        error: 'No bill text or image provided. Include a "text" field or upload a "bill" image.',
      });
    }

    const result = parseBillText(rawText);

    if (!result.success) {
      return res.status(422).json(result);
    }

    res.json({
      success: true,
      message: `Extracted ${result.data.lineItems.length} items, confidence: ${Math.round(result.data.confidence * 100)}%`,
      data: result.data,
    });
  } catch (err) {
    next(err);
  }
}

module.exports = { scanBill, parseBillText };

