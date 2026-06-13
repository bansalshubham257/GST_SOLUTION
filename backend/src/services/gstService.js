// backend/src/services/gstService.js

/**
 * Core GST engine - CGST/SGST/IGST calculation
 * Handles intra-state and inter-state transactions
 */

// Validate GSTIN format: 15-char alphanumeric
const validateGstin = (gstin) => {
  if (!gstin) return { valid: false, error: 'GSTIN is required' };
  const gstinRegex = /^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$/;
  if (!gstinRegex.test(gstin)) return { valid: false, error: 'Invalid GSTIN format' };
  return { valid: true, stateCode: gstin.substring(0, 2) };
};

// Validate PAN format
const validatePan = (pan) => {
  const panRegex = /^[A-Z]{5}[0-9]{4}[A-Z]{1}$/;
  return panRegex.test(pan);
};

// Get state code from GSTIN
const getStateCodeFromGstin = (gstin) => {
  if (!gstin || gstin.length < 2) return null;
  return gstin.substring(0, 2);
};

// Check if transaction is inter-state
const isInterState = (sellerGstin, buyerGstin, sellerStateCode, buyerStateCode) => {
  const sellerState = sellerGstin ? sellerGstin.substring(0, 2) : sellerStateCode;
  const buyerState = buyerGstin ? buyerGstin.substring(0, 2) : buyerStateCode;
  if (!sellerState || !buyerState) return false;
  return sellerState !== buyerState;
};

// Round to 2 decimal places
const round2 = (val) => Math.round(val * 100) / 100;

// Calculate GST breakdown for a single amount
const calculateGst = ({ taxableAmount, gstRate, interState }) => {
  const totalGst = round2((taxableAmount * gstRate) / 100);
  return {
    taxableAmount: round2(taxableAmount),
    gstRate,
    cgst: interState ? 0 : round2(totalGst / 2),
    sgst: interState ? 0 : round2(totalGst / 2),
    igst: interState ? totalGst : 0,
    totalGst,
    totalAmount: round2(taxableAmount + totalGst),
  };
};

// Calculate full invoice totals
const calculateInvoiceTotals = (lineItems, interState) => {
  let subTotal = 0;
  let totalCgst = 0;
  let totalSgst = 0;
  let totalIgst = 0;
  let totalGst = 0;
  const gstSlabs = {};

  for (const item of lineItems) {
    const qty = parseFloat(item.quantity) || 0;
    const price = parseFloat(item.unitPrice) || 0;
    const discount = parseFloat(item.discountPercent) || 0;
    const taxable = round2(qty * price * (1 - discount / 100));

    const breakdown = calculateGst({ taxableAmount: taxable, gstRate: item.gstRate, interState });

    subTotal += taxable;
    totalCgst += breakdown.cgst;
    totalSgst += breakdown.sgst;
    totalIgst += breakdown.igst;
    totalGst += breakdown.totalGst;

    // Aggregate by GST slab
    const key = String(item.gstRate);
    if (!gstSlabs[key]) {
      gstSlabs[key] = { rate: item.gstRate, taxableAmount: 0, cgst: 0, sgst: 0, igst: 0 };
    }
    gstSlabs[key].taxableAmount += taxable;
    gstSlabs[key].cgst += breakdown.cgst;
    gstSlabs[key].sgst += breakdown.sgst;
    gstSlabs[key].igst += breakdown.igst;
  }

  const grandTotal = subTotal + totalGst;
  const roundOff = round2(Math.round(grandTotal) - grandTotal);
  const roundedTotal = round2(grandTotal + roundOff);

  return {
    subTotal: round2(subTotal),
    totalCgst: round2(totalCgst),
    totalSgst: round2(totalSgst),
    totalIgst: round2(totalIgst),
    totalTax: round2(totalGst),
    grandTotal: round2(grandTotal),
    roundOff,
    roundedTotal,
    gstSlabs: Object.values(gstSlabs).map((s) => ({
      ...s,
      taxableAmount: round2(s.taxableAmount),
      cgst: round2(s.cgst),
      sgst: round2(s.sgst),
      igst: round2(s.igst),
    })),
  };
};

// Generate GSTR-1 JSON (B2B invoices)
const generateGstr1Json = (business, invoices, period) => {
  const b2b = [];
  const b2cs = [];
  const nil = { nilRated: 0, exempted: 0, nonGst: 0 };

  for (const inv of invoices) {
    if (inv.customer_gstin) {
      // B2B transaction
      let ctin = b2b.find((x) => x.ctin === inv.customer_gstin);
      if (!ctin) {
        ctin = { ctin: inv.customer_gstin, inv: [] };
        b2b.push(ctin);
      }
      ctin.inv.push({
        inum: inv.invoice_number,
        idt: formatDate(inv.invoice_date),
        val: parseFloat(inv.grand_total),
        pos: inv.customer_gstin?.substring(0, 2) || business.state_code,
        rchrg: 'N',
        inv_typ: 'R',
        itms: inv.line_items.map((item) => ({
          num: 1,
          itm_det: {
            txval: parseFloat(item.taxable_amount),
            rt: parseFloat(item.gst_rate),
            camt: parseFloat(item.cgst),
            samt: parseFloat(item.sgst),
            iamt: parseFloat(item.igst),
          },
        })),
      });
    } else {
      // B2C - group by state and rate
      const stateCode = business.state_code;
      for (const item of inv.line_items) {
        const key = `${stateCode}_${item.gst_rate}`;
        let b2csEntry = b2cs.find((x) => x._key === key);
        if (!b2csEntry) {
          b2csEntry = { _key: key, pos: stateCode, rt: parseFloat(item.gst_rate), sup_typ: 'OE', txval: 0, iamt: 0, camt: 0, samt: 0 };
          b2cs.push(b2csEntry);
        }
        b2csEntry.txval += parseFloat(item.taxable_amount);
        b2csEntry.iamt += parseFloat(item.igst);
        b2csEntry.camt += parseFloat(item.cgst);
        b2csEntry.samt += parseFloat(item.sgst);
      }
    }
  }

  // Clean internal keys
  const cleanedB2cs = b2cs.map(({ _key, ...rest }) => ({
    ...rest,
    txval: round2(rest.txval),
    iamt: round2(rest.iamt),
    camt: round2(rest.camt),
    samt: round2(rest.samt),
  }));

  return {
    version: 'GST3.0.4',
    hash: 'hash',
    gstin: business.gstin,
    fp: period, // e.g. "032024"
    gt: round2(invoices.reduce((s, i) => s + parseFloat(i.grand_total), 0)),
    cur_gt: round2(invoices.reduce((s, i) => s + parseFloat(i.grand_total), 0)),
    b2b,
    b2cs: cleanedB2cs,
    nil,
  };
};

// Generate GSTR-3B summary
const generateGstr3bSummary = (invoices, period) => {
  let totalTaxableValue = 0;
  let totalIgst = 0;
  let totalCgst = 0;
  let totalSgst = 0;

  for (const inv of invoices) {
    totalTaxableValue += parseFloat(inv.sub_total || 0);
    totalIgst += parseFloat(inv.total_igst || 0);
    totalCgst += parseFloat(inv.total_cgst || 0);
    totalSgst += parseFloat(inv.total_sgst || 0);
  }

  return {
    gstin: null, // filled by caller
    ret_period: period,
    sup_details: {
      osup_det: {
        txval: round2(totalTaxableValue),
        iamt: round2(totalIgst),
        camt: round2(totalCgst),
        samt: round2(totalSgst),
        csamt: 0,
      },
      osup_zero: { txval: 0, iamt: 0, camt: 0, samt: 0, csamt: 0 },
      osup_nil_exmp: { txval: 0, camt: 0, samt: 0 },
      isup_rev: { txval: 0, iamt: 0, camt: 0, samt: 0, csamt: 0 },
      osup_nongst: { txval: 0 },
    },
    inter_sup: { unreg_details: [], comp_details: [], uin_details: [] },
    itc_elg: {
      itc_avl: [
        { ty: 'IMPG', iamt: 0, camt: 0, samt: 0, csamt: 0 },
        { ty: 'IMPS', iamt: 0, camt: 0, samt: 0, csamt: 0 },
        { ty: 'ISRC', iamt: 0, camt: 0, samt: 0, csamt: 0 },
        { ty: 'ISD', iamt: 0, camt: 0, samt: 0, csamt: 0 },
        { ty: 'OTH', iamt: 0, camt: 0, samt: 0, csamt: 0 },
      ],
      itc_rev: [
        { ty: 'RUL_37', iamt: 0, camt: 0, samt: 0, csamt: 0 },
        { ty: 'RUL_39', iamt: 0, camt: 0, samt: 0, csamt: 0 },
        { ty: 'RUL_42', iamt: 0, camt: 0, samt: 0, csamt: 0 },
        { ty: 'RUL_43', iamt: 0, camt: 0, samt: 0, csamt: 0 },
        { ty: 'RUL_44', iamt: 0, camt: 0, samt: 0, csamt: 0 },
        { ty: 'OTHERS', iamt: 0, camt: 0, samt: 0, csamt: 0 },
      ],
      itc_net: { iamt: 0, camt: 0, samt: 0, csamt: 0 },
      itc_inelg: [
        { ty: 'RUL_38', iamt: 0, camt: 0, samt: 0, csamt: 0 },
        { ty: 'OTHERS', iamt: 0, camt: 0, samt: 0, csamt: 0 },
      ],
    },
    inward_sup: {
      isup_details: [
        { ty: 'GST', inter: 0, intra: 0 },
        { ty: 'NONGST', inter: 0, intra: 0 },
      ],
    },
    intr_ltfee: { intr_details: { iamt: 0, camt: 0, samt: 0, csamt: 0 } },
  };
};

const formatDate = (date) => {
  const d = new Date(date);
  return `${String(d.getDate()).padStart(2, '0')}-${String(d.getMonth() + 1).padStart(2, '0')}-${d.getFullYear()}`;
};

module.exports = {
  validateGstin,
  validatePan,
  getStateCodeFromGstin,
  isInterState,
  calculateGst,
  calculateInvoiceTotals,
  generateGstr1Json,
  generateGstr3bSummary,
};

