// backend/src/controllers/gst.controller.js

const { query } = require('../config/database');
const { validateGstin, generateGstr1Json, generateGstr3bSummary } = require('../services/gstService');
const { AppError } = require('../middleware/errorHandler');
const ExcelJS = require('exceljs');

const getPeriodDates = (month, year) => {
  const from = new Date(year, month - 1, 1);
  const to = new Date(year, month, 0);
  return { from, to };
};

/**
 * GET /gst/summary?month=3&year=2024
 */
const getGstSummary = async (req, res, next) => {
  try {
    const { month = new Date().getMonth() + 1, year = new Date().getFullYear() } = req.query;
    const { from, to } = getPeriodDates(parseInt(month), parseInt(year));

    const result = await query(
      `SELECT
         COALESCE(SUM(sub_total), 0) as taxable_value,
         COALESCE(SUM(total_cgst), 0) as total_cgst,
         COALESCE(SUM(total_sgst), 0) as total_sgst,
         COALESCE(SUM(total_igst), 0) as total_igst,
         COALESCE(SUM(total_tax), 0) as total_tax,
         COALESCE(SUM(grand_total), 0) as total_invoice_value,
         COUNT(*) as invoice_count,
         SUM(CASE WHEN customer_gstin IS NOT NULL THEN 1 ELSE 0 END) as b2b_count,
         SUM(CASE WHEN customer_gstin IS NULL THEN 1 ELSE 0 END) as b2c_count
       FROM invoices
       WHERE business_id = $1 AND status != 'cancelled'
         AND invoice_date BETWEEN $2 AND $3`,
      [req.user.businessId, from, to]
    );

    // GST slab-wise breakdown
    const slabResult = await query(
      `SELECT
         il.gst_rate,
         COALESCE(SUM(il.taxable_amount), 0) as taxable_amount,
         COALESCE(SUM(il.cgst), 0) as cgst,
         COALESCE(SUM(il.sgst), 0) as sgst,
         COALESCE(SUM(il.igst), 0) as igst
       FROM invoice_line_items il
       JOIN invoices i ON i.id = il.invoice_id
       WHERE i.business_id = $1 AND i.status != 'cancelled'
         AND i.invoice_date BETWEEN $2 AND $3
       GROUP BY il.gst_rate
       ORDER BY il.gst_rate`,
      [req.user.businessId, from, to]
    );

    const summary = result.rows[0];
    res.json({
      period: { month: parseInt(month), year: parseInt(year) },
      summary: {
        taxableValue: parseFloat(summary.taxable_value),
        totalCgst: parseFloat(summary.total_cgst),
        totalSgst: parseFloat(summary.total_sgst),
        totalIgst: parseFloat(summary.total_igst),
        totalTax: parseFloat(summary.total_tax),
        totalInvoiceValue: parseFloat(summary.total_invoice_value),
        invoiceCount: parseInt(summary.invoice_count),
        b2bCount: parseInt(summary.b2b_count),
        b2cCount: parseInt(summary.b2c_count),
      },
      slabWise: slabResult.rows.map((s) => ({
        gstRate: parseFloat(s.gst_rate),
        taxableAmount: parseFloat(s.taxable_amount),
        cgst: parseFloat(s.cgst),
        sgst: parseFloat(s.sgst),
        igst: parseFloat(s.igst),
        totalGst: parseFloat(s.cgst) + parseFloat(s.sgst) + parseFloat(s.igst),
      })),
    });
  } catch (err) {
    next(err);
  }
};

/**
 * GET /gst/sales-register?month=3&year=2024
 */
const getSalesRegister = async (req, res, next) => {
  try {
    const { month = new Date().getMonth() + 1, year = new Date().getFullYear() } = req.query;
    const { from, to } = getPeriodDates(parseInt(month), parseInt(year));

    const result = await query(
      `SELECT i.*, b.name as business_name, b.gstin as business_gstin
       FROM invoices i
       JOIN businesses b ON b.id = i.business_id
       WHERE i.business_id = $1 AND i.status != 'cancelled'
         AND i.invoice_date BETWEEN $2 AND $3
       ORDER BY i.invoice_date ASC`,
      [req.user.businessId, from, to]
    );

    res.json({
      period: { month: parseInt(month), year: parseInt(year) },
      invoices: result.rows.map((inv) => ({
        invoiceNumber: inv.invoice_number,
        invoiceDate: inv.invoice_date,
        customerName: inv.customer_name,
        customerGstin: inv.customer_gstin,
        isInterState: inv.is_inter_state,
        taxableValue: parseFloat(inv.sub_total || 0),
        cgst: parseFloat(inv.total_cgst || 0),
        sgst: parseFloat(inv.total_sgst || 0),
        igst: parseFloat(inv.total_igst || 0),
        totalTax: parseFloat(inv.total_tax || 0),
        grandTotal: parseFloat(inv.grand_total || 0),
        status: inv.status,
      })),
    });
  } catch (err) {
    next(err);
  }
};

/**
 * GET /gst/gstr1-draft?month=3&year=2024
 */
const getGstr1Draft = async (req, res, next) => {
  try {
    const { month = new Date().getMonth() + 1, year = new Date().getFullYear() } = req.query;
    const { from, to } = getPeriodDates(parseInt(month), parseInt(year));

    const [invoicesResult, businessResult] = await Promise.all([
      query(
        `SELECT i.*,
           json_agg(il ORDER BY il.sort_order) as line_items
         FROM invoices i
         LEFT JOIN invoice_line_items il ON il.invoice_id = i.id
         WHERE i.business_id = $1 AND i.status != 'cancelled'
           AND i.invoice_date BETWEEN $2 AND $3
         GROUP BY i.id`,
        [req.user.businessId, from, to]
      ),
      query('SELECT * FROM businesses WHERE id = $1', [req.user.businessId]),
    ]);

    const business = businessResult.rows[0];
    const period = `${String(month).padStart(2, '0')}${year}`;
    const gstr1 = generateGstr1Json(business, invoicesResult.rows, period);

    res.json({ gstr1, period: { month: parseInt(month), year: parseInt(year) } });
  } catch (err) {
    next(err);
  }
};

/**
 * GET /gst/gstr3b-draft?month=3&year=2024
 */
const getGstr3bDraft = async (req, res, next) => {
  try {
    const { month = new Date().getMonth() + 1, year = new Date().getFullYear() } = req.query;
    const { from, to } = getPeriodDates(parseInt(month), parseInt(year));

    const [invoicesResult, businessResult] = await Promise.all([
      query(
        `SELECT * FROM invoices
         WHERE business_id = $1 AND status != 'cancelled'
           AND invoice_date BETWEEN $2 AND $3`,
        [req.user.businessId, from, to]
      ),
      query('SELECT * FROM businesses WHERE id = $1', [req.user.businessId]),
    ]);

    const business = businessResult.rows[0];
    const period = `${String(month).padStart(2, '0')}${year}`;
    const gstr3b = generateGstr3bSummary(invoicesResult.rows, period);
    gstr3b.gstin = business?.gstin;

    res.json({ gstr3b, period: { month: parseInt(month), year: parseInt(year) } });
  } catch (err) {
    next(err);
  }
};

/**
 * GET /gst/tax-liability?month=3&year=2024
 */
const getTaxLiability = async (req, res, next) => {
  try {
    const { month = new Date().getMonth() + 1, year = new Date().getFullYear() } = req.query;
    const { from, to } = getPeriodDates(parseInt(month), parseInt(year));

    const result = await query(
      `SELECT
         COALESCE(SUM(total_cgst), 0) as cgst_liability,
         COALESCE(SUM(total_sgst), 0) as sgst_liability,
         COALESCE(SUM(total_igst), 0) as igst_liability,
         COALESCE(SUM(total_tax), 0) as total_liability
       FROM invoices
       WHERE business_id = $1 AND status != 'cancelled'
         AND invoice_date BETWEEN $2 AND $3`,
      [req.user.businessId, from, to]
    );

    const row = result.rows[0];
    res.json({
      period: { month: parseInt(month), year: parseInt(year) },
      taxLiability: {
        cgst: parseFloat(row.cgst_liability),
        sgst: parseFloat(row.sgst_liability),
        igst: parseFloat(row.igst_liability),
        total: parseFloat(row.total_liability),
      },
    });
  } catch (err) {
    next(err);
  }
};

/**
 * POST /gst/validate
 * Validate GSTIN
 */
const validateGstinEndpoint = async (req, res, next) => {
  try {
    const { gstin } = req.body;
    const result = validateGstin(gstin?.toUpperCase());
    res.json({
      valid: result.valid,
      error: result.error,
      stateCode: result.stateCode,
    });
  } catch (err) {
    next(err);
  }
};

/**
 * GET /gst/filing-checklist?month=3&year=2024
 */
const getFilingChecklist = async (req, res, next) => {
  try {
    const { month = new Date().getMonth() + 1, year = new Date().getFullYear() } = req.query;
    const { from, to } = getPeriodDates(parseInt(month), parseInt(year));

    // Missing GSTIN check
    const missingGstin = await query(
      `SELECT invoice_number, customer_name FROM invoices
       WHERE business_id = $1 AND status != 'cancelled'
         AND invoice_date BETWEEN $2 AND $3
         AND customer_gstin IS NULL AND grand_total > 250000`,
      [req.user.businessId, from, to]
    );

    // Duplicate invoice numbers
    const duplicates = await query(
      `SELECT invoice_number, COUNT(*) as cnt FROM invoices
       WHERE business_id = $1 AND invoice_date BETWEEN $2 AND $3
       GROUP BY invoice_number HAVING COUNT(*) > 1`,
      [req.user.businessId, from, to]
    );

    const invoiceCount = await query(
      `SELECT COUNT(*) FROM invoices
       WHERE business_id = $1 AND status != 'cancelled' AND invoice_date BETWEEN $2 AND $3`,
      [req.user.businessId, from, to]
    );

    res.json({
      period: { month: parseInt(month), year: parseInt(year) },
      checklist: {
        totalInvoices: parseInt(invoiceCount.rows[0].count),
        missingGstin: missingGstin.rows,
        duplicateInvoices: duplicates.rows,
        isReadyToFile: missingGstin.rows.length === 0 && duplicates.rows.length === 0,
      },
    });
  } catch (err) {
    next(err);
  }
};

/**
 * GET /gst/generate-json?month=3&year=2024
 * Export final GSTR-1 JSON for portal upload
 */
const generateFilingJson = async (req, res, next) => {
  try {
    const { month = new Date().getMonth() + 1, year = new Date().getFullYear(), type = 'gstr1' } = req.query;
    const { from, to } = getPeriodDates(parseInt(month), parseInt(year));

    const [invoicesResult, businessResult] = await Promise.all([
      query(
        `SELECT i.*, json_agg(il ORDER BY il.sort_order) as line_items
         FROM invoices i
         LEFT JOIN invoice_line_items il ON il.invoice_id = i.id
         WHERE i.business_id = $1 AND i.status != 'cancelled'
           AND i.invoice_date BETWEEN $2 AND $3
         GROUP BY i.id`,
        [req.user.businessId, from, to]
      ),
      query('SELECT * FROM businesses WHERE id = $1', [req.user.businessId]),
    ]);

    const business = businessResult.rows[0];
    const period = `${String(month).padStart(2, '0')}${year}`;

    let jsonData;
    if (type === 'gstr1') {
      jsonData = generateGstr1Json(business, invoicesResult.rows, period);
    } else {
      jsonData = generateGstr3bSummary(invoicesResult.rows, period);
      jsonData.gstin = business?.gstin;
    }

    res.setHeader('Content-Type', 'application/json');
    res.setHeader('Content-Disposition', `attachment; filename="${type}_${period}.json"`);
    res.json(jsonData);
  } catch (err) {
    next(err);
  }
};

/**
 * GET /gst/export?month=3&year=2024&format=excel
 */
const exportReport = async (req, res, next) => {
  try {
    const { month = new Date().getMonth() + 1, year = new Date().getFullYear(), format = 'excel' } = req.query;
    const { from, to } = getPeriodDates(parseInt(month), parseInt(year));

    const result = await query(
      `SELECT i.invoice_number, i.invoice_date, i.customer_name, i.customer_gstin,
              i.sub_total, i.total_cgst, i.total_sgst, i.total_igst, i.total_tax,
              i.grand_total, i.status, i.is_inter_state
       FROM invoices i
       WHERE i.business_id = $1 AND i.status != 'cancelled'
         AND i.invoice_date BETWEEN $2 AND $3
       ORDER BY i.invoice_date`,
      [req.user.businessId, from, to]
    );

    if (format === 'excel') {
      const workbook = new ExcelJS.Workbook();
      const sheet = workbook.addWorksheet('Sales Register');

      sheet.columns = [
        { header: 'Invoice No.', key: 'invoice_number', width: 18 },
        { header: 'Date', key: 'invoice_date', width: 14 },
        { header: 'Customer Name', key: 'customer_name', width: 25 },
        { header: 'Customer GSTIN', key: 'customer_gstin', width: 20 },
        { header: 'Taxable Value', key: 'sub_total', width: 15 },
        { header: 'CGST', key: 'total_cgst', width: 12 },
        { header: 'SGST', key: 'total_sgst', width: 12 },
        { header: 'IGST', key: 'total_igst', width: 12 },
        { header: 'Total Tax', key: 'total_tax', width: 12 },
        { header: 'Grand Total', key: 'grand_total', width: 15 },
        { header: 'Status', key: 'status', width: 10 },
        { header: 'Type', key: 'is_inter_state', width: 10 },
      ];

      sheet.getRow(1).font = { bold: true };
      sheet.getRow(1).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF1A73E8' } };
      sheet.getRow(1).font = { bold: true, color: { argb: 'FFFFFFFF' } };

      for (const inv of result.rows) {
        sheet.addRow({
          ...inv,
          invoice_date: new Date(inv.invoice_date).toLocaleDateString('en-IN'),
          is_inter_state: inv.is_inter_state ? 'Inter-State' : 'Intra-State',
          sub_total: parseFloat(inv.sub_total || 0),
          total_cgst: parseFloat(inv.total_cgst || 0),
          total_sgst: parseFloat(inv.total_sgst || 0),
          total_igst: parseFloat(inv.total_igst || 0),
          total_tax: parseFloat(inv.total_tax || 0),
          grand_total: parseFloat(inv.grand_total || 0),
        });
      }

      res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      res.setHeader('Content-Disposition', `attachment; filename="gst-report-${month}-${year}.xlsx"`);
      await workbook.xlsx.write(res);
      return;
    }

    res.json({ invoices: result.rows });
  } catch (err) {
    next(err);
  }
};

module.exports = {
  getGstSummary, getSalesRegister, getGstr1Draft, getGstr3bDraft,
  getTaxLiability, validateGstinEndpoint, getFilingChecklist, generateFilingJson, exportReport,
};

