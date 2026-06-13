// backend/src/controllers/invoice.controller.js

const { query, transaction } = require('../config/database');
const { calculateInvoiceTotals, isInterState } = require('../services/gstService');
const { AppError } = require('../middleware/errorHandler');
const logger = require('../utils/logger');
const { v4: uuidv4 } = require('uuid');

const formatInvoice = (inv) => ({
  id: inv.id,
  invoiceNumber: inv.invoice_number,
  businessId: inv.business_id,
  customerId: inv.customer_id,
  customerName: inv.customer_name,
  customerGstin: inv.customer_gstin,
  customerPhone: inv.customer_phone,
  customerEmail: inv.customer_email,
  customerAddress: inv.customer_address,
  customerState: inv.customer_state,
  invoiceDate: inv.invoice_date,
  dueDate: inv.due_date,
  status: inv.status,
  isInterState: inv.is_inter_state,
  subTotal: parseFloat(inv.sub_total || 0),
  totalCgst: parseFloat(inv.total_cgst || 0),
  totalSgst: parseFloat(inv.total_sgst || 0),
  totalIgst: parseFloat(inv.total_igst || 0),
  totalCess: parseFloat(inv.total_cess || 0),
  totalTax: parseFloat(inv.total_tax || 0),
  discountAmount: parseFloat(inv.discount_amount || 0),
  grandTotal: parseFloat(inv.grand_total || 0),
  roundOff: parseFloat(inv.round_off || 0),
  notes: inv.notes,
  termsAndConditions: inv.terms_and_conditions,
  lineItems: inv.line_items || [],
  gstSlabs: inv.gst_slabs || [],
  createdAt: inv.created_at,
  updatedAt: inv.updated_at,
});

const generateInvoiceNumber = async (businessId, prefix) => {
  const result = await query(
    'SELECT COUNT(*) as cnt FROM invoices WHERE business_id = $1',
    [businessId]
  );
  const count = parseInt(result.rows[0].cnt) + 1;
  const year = new Date().getFullYear().toString().slice(-2);
  const month = String(new Date().getMonth() + 1).padStart(2, '0');
  return `${prefix || 'INV'}-${year}${month}-${String(count).padStart(4, '0')}`;
};

/**
 * GET /invoices
 */
const getInvoices = async (req, res, next) => {
  try {
    const { page = 1, limit = 20, search, status, month, year } = req.query;
    const offset = (page - 1) * limit;
    const params = [req.user.businessId];
    let where = 'WHERE i.business_id = $1';

    if (search) {
      params.push(`%${search}%`);
      where += ` AND (i.invoice_number ILIKE $${params.length} OR i.customer_name ILIKE $${params.length})`;
    }
    if (status) {
      params.push(status);
      where += ` AND i.status = $${params.length}`;
    }
    if (month && year) {
      where += ` AND EXTRACT(MONTH FROM i.invoice_date) = ${month} AND EXTRACT(YEAR FROM i.invoice_date) = ${year}`;
    }

    params.push(limit, offset);
    const result = await query(
      `SELECT i.*,
        COALESCE(
          json_agg(il ORDER BY il.sort_order) FILTER (WHERE il.id IS NOT NULL),
          '[]'
        ) as line_items
       FROM invoices i
       LEFT JOIN invoice_line_items il ON il.invoice_id = i.id
       ${where}
       GROUP BY i.id
       ORDER BY i.created_at DESC
       LIMIT $${params.length - 1} OFFSET $${params.length}`,
      params
    );

    const countResult = await query(
      `SELECT COUNT(*) FROM invoices i ${where.replace(/\$${params.length - 1}|\$${params.length}/g, '')}`,
      params.slice(0, -2)
    );

    res.json({
      invoices: result.rows.map(formatInvoice),
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: parseInt(countResult.rows[0].count),
      },
    });
  } catch (err) {
    next(err);
  }
};

/**
 * GET /invoices/:id
 */
const getInvoiceById = async (req, res, next) => {
  try {
    const result = await query(
      `SELECT i.*,
        COALESCE(
          json_agg(il ORDER BY il.sort_order) FILTER (WHERE il.id IS NOT NULL),
          '[]'
        ) as line_items
       FROM invoices i
       LEFT JOIN invoice_line_items il ON il.invoice_id = i.id
       WHERE i.id = $1 AND i.business_id = $2
       GROUP BY i.id`,
      [req.params.id, req.user.businessId]
    );
    if (!result.rows[0]) throw new AppError('Invoice not found', 404, 'NOT_FOUND');
    res.json(formatInvoice(result.rows[0]));
  } catch (err) {
    next(err);
  }
};

/**
 * POST /invoices
 */
const createInvoice = async (req, res, next) => {
  try {
    const businessId = req.user.businessId;
    if (!businessId) throw new AppError('Business setup required', 403, 'BUSINESS_REQUIRED');

    const bizResult = await query('SELECT * FROM businesses WHERE id = $1', [businessId]);
    const business = bizResult.rows[0];

    const invoiceNumber = await generateInvoiceNumber(businessId, business.invoice_prefix);

    const {
      customerId, customerName, customerGstin, customerPhone, customerEmail,
      customerAddress, customerState, invoiceDate, dueDate, status = 'sent',
      lineItems, notes, termsAndConditions, isInterState: interState,
      subTotal, totalCgst, totalSgst, totalIgst, totalTax, discountAmount,
      grandTotal, roundOff, gstSlabs,
    } = req.body;

    const invoice = await transaction(async (client) => {
      const invResult = await client.query(
        `INSERT INTO invoices (
           business_id, invoice_number, customer_id, customer_name, customer_gstin,
           customer_phone, customer_email, customer_address, customer_state,
           invoice_date, due_date, status, is_inter_state,
           sub_total, total_cgst, total_sgst, total_igst, total_cess, total_tax,
           discount_amount, grand_total, round_off, notes, terms_and_conditions,
           gst_slabs, created_at, updated_at
         ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,0,$18,$19,$20,$21,$22,$23,$24,NOW(),NOW())
         RETURNING *`,
        [businessId, invoiceNumber, customerId, customerName, customerGstin?.toUpperCase(),
          customerPhone, customerEmail, customerAddress, customerState,
          invoiceDate || new Date(), dueDate, status, interState || false,
          subTotal, totalCgst, totalSgst, totalIgst, totalTax,
          discountAmount || 0, grandTotal, roundOff || 0, notes, termsAndConditions,
          JSON.stringify(gstSlabs || [])]
      );

      const inv = invResult.rows[0];

      // Insert line items
      if (lineItems?.length) {
        for (let i = 0; i < lineItems.length; i++) {
          const item = lineItems[i];
          await client.query(
            `INSERT INTO invoice_line_items (
               invoice_id, description, hsn_sac_code, is_service, quantity, unit,
               unit_price, discount_percent, discount_amount, taxable_amount,
               gst_rate, cgst, sgst, igst, cess, total_amount, sort_order
             ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,0,$15,$16)`,
            [inv.id, item.description, item.hsnSacCode, item.isService || false,
              item.quantity, item.unit || 'Nos', item.unitPrice, item.discountPercent || 0,
              item.discountAmount || 0, item.taxableAmount, item.gstRate,
              item.cgst || 0, item.sgst || 0, item.igst || 0, item.totalAmount, i]
          );
        }
      }

      // Update customer invoice count if linked
      if (customerId) {
        await client.query(
          `UPDATE customers SET invoice_count = invoice_count + 1,
            total_business = total_business + $1, updated_at = NOW()
           WHERE id = $2`,
          [grandTotal, customerId]
        );
      }

      return inv;
    });

    res.status(201).json({ invoice: formatInvoice(invoice), message: 'Invoice created' });
  } catch (err) {
    next(err);
  }
};

/**
 * PUT /invoices/:id
 */
const updateInvoice = async (req, res, next) => {
  try {
    const existing = await query(
      'SELECT * FROM invoices WHERE id = $1 AND business_id = $2',
      [req.params.id, req.user.businessId]
    );
    if (!existing.rows[0]) throw new AppError('Invoice not found', 404, 'NOT_FOUND');
    if (existing.rows[0].status === 'cancelled') throw new AppError('Cannot edit cancelled invoice', 400, 'INVALID_STATUS');

    const {
      customerName, customerGstin, customerPhone, customerEmail, customerAddress,
      invoiceDate, dueDate, status, lineItems, notes, termsAndConditions,
      subTotal, totalCgst, totalSgst, totalIgst, totalTax, discountAmount,
      grandTotal, roundOff, isInterState: interState, gstSlabs,
    } = req.body;

    const invoice = await transaction(async (client) => {
      const result = await client.query(
        `UPDATE invoices SET
           customer_name = COALESCE($1, customer_name),
           customer_gstin = COALESCE($2, customer_gstin),
           customer_phone = COALESCE($3, customer_phone),
           customer_email = COALESCE($4, customer_email),
           customer_address = COALESCE($5, customer_address),
           invoice_date = COALESCE($6, invoice_date),
           due_date = $7, status = COALESCE($8, status),
           is_inter_state = COALESCE($9, is_inter_state),
           sub_total = COALESCE($10, sub_total),
           total_cgst = COALESCE($11, total_cgst),
           total_sgst = COALESCE($12, total_sgst),
           total_igst = COALESCE($13, total_igst),
           total_tax = COALESCE($14, total_tax),
           discount_amount = COALESCE($15, discount_amount),
           grand_total = COALESCE($16, grand_total),
           round_off = COALESCE($17, round_off),
           notes = $18, terms_and_conditions = $19,
           gst_slabs = COALESCE($20, gst_slabs),
           updated_at = NOW()
         WHERE id = $21 AND business_id = $22
         RETURNING *`,
        [customerName, customerGstin?.toUpperCase(), customerPhone, customerEmail,
          customerAddress, invoiceDate, dueDate, status, interState,
          subTotal, totalCgst, totalSgst, totalIgst, totalTax, discountAmount,
          grandTotal, roundOff, notes, termsAndConditions,
          gstSlabs ? JSON.stringify(gstSlabs) : null,
          req.params.id, req.user.businessId]
      );

      const inv = result.rows[0];

      if (lineItems?.length) {
        await client.query('DELETE FROM invoice_line_items WHERE invoice_id = $1', [inv.id]);
        for (let i = 0; i < lineItems.length; i++) {
          const item = lineItems[i];
          await client.query(
            `INSERT INTO invoice_line_items (
               invoice_id, description, hsn_sac_code, is_service, quantity, unit,
               unit_price, discount_percent, discount_amount, taxable_amount,
               gst_rate, cgst, sgst, igst, cess, total_amount, sort_order
             ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,0,$15,$16)`,
            [inv.id, item.description, item.hsnSacCode, item.isService || false,
              item.quantity, item.unit || 'Nos', item.unitPrice, item.discountPercent || 0,
              item.discountAmount || 0, item.taxableAmount, item.gstRate,
              item.cgst || 0, item.sgst || 0, item.igst || 0, item.totalAmount, i]
          );
        }
      }
      return inv;
    });

    res.json({ invoice: formatInvoice(invoice), message: 'Invoice updated' });
  } catch (err) {
    next(err);
  }
};

/**
 * POST /invoices/:id/cancel
 */
const cancelInvoice = async (req, res, next) => {
  try {
    const result = await query(
      `UPDATE invoices SET status = 'cancelled', updated_at = NOW()
       WHERE id = $1 AND business_id = $2 AND status != 'cancelled'
       RETURNING *`,
      [req.params.id, req.user.businessId]
    );
    if (!result.rows[0]) throw new AppError('Invoice not found or already cancelled', 404, 'NOT_FOUND');
    res.json({ message: 'Invoice cancelled', invoice: formatInvoice(result.rows[0]) });
  } catch (err) {
    next(err);
  }
};

/**
 * POST /invoices/:id/duplicate
 */
const duplicateInvoice = async (req, res, next) => {
  try {
    const original = await query(
      'SELECT * FROM invoices WHERE id = $1 AND business_id = $2',
      [req.params.id, req.user.businessId]
    );
    if (!original.rows[0]) throw new AppError('Invoice not found', 404, 'NOT_FOUND');

    const bizResult = await query('SELECT * FROM businesses WHERE id = $1', [req.user.businessId]);
    const business = bizResult.rows[0];
    const newNumber = await generateInvoiceNumber(req.user.businessId, business.invoice_prefix);

    const orig = original.rows[0];
    const newInv = await transaction(async (client) => {
      const result = await client.query(
        `INSERT INTO invoices (business_id, invoice_number, customer_id, customer_name, customer_gstin,
           customer_phone, customer_email, customer_address, customer_state,
           invoice_date, status, is_inter_state, sub_total, total_cgst, total_sgst, total_igst,
           total_cess, total_tax, discount_amount, grand_total, round_off, notes,
           terms_and_conditions, gst_slabs, created_at, updated_at)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,NOW(),'draft',$10,$11,$12,$13,$14,0,$15,$16,$17,$18,$19,$20,$21,NOW(),NOW())
         RETURNING *`,
        [req.user.businessId, newNumber, orig.customer_id, orig.customer_name, orig.customer_gstin,
          orig.customer_phone, orig.customer_email, orig.customer_address, orig.customer_state,
          orig.is_inter_state, orig.sub_total, orig.total_cgst, orig.total_sgst, orig.total_igst,
          orig.total_tax, orig.discount_amount, orig.grand_total, orig.round_off,
          orig.notes, orig.terms_and_conditions, orig.gst_slabs]
      );

      const items = await client.query('SELECT * FROM invoice_line_items WHERE invoice_id = $1', [orig.id]);
      for (const item of items.rows) {
        await client.query(
          `INSERT INTO invoice_line_items (invoice_id,description,hsn_sac_code,is_service,quantity,unit,
             unit_price,discount_percent,discount_amount,taxable_amount,gst_rate,cgst,sgst,igst,cess,total_amount,sort_order)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17)`,
          [result.rows[0].id, item.description, item.hsn_sac_code, item.is_service,
            item.quantity, item.unit, item.unit_price, item.discount_percent, item.discount_amount,
            item.taxable_amount, item.gst_rate, item.cgst, item.sgst, item.igst,
            item.cess, item.total_amount, item.sort_order]
        );
      }
      return result.rows[0];
    });

    res.status(201).json({ invoice: formatInvoice(newInv), message: 'Invoice duplicated' });
  } catch (err) {
    next(err);
  }
};

/**
 * DELETE /invoices/:id
 */
const deleteInvoice = async (req, res, next) => {
  try {
    const result = await query(
      `DELETE FROM invoices WHERE id = $1 AND business_id = $2 AND status = 'draft' RETURNING id`,
      [req.params.id, req.user.businessId]
    );
    if (!result.rows[0]) throw new AppError('Invoice not found or cannot be deleted', 404, 'NOT_FOUND');
    res.json({ message: 'Invoice deleted' });
  } catch (err) {
    next(err);
  }
};

module.exports = { getInvoices, getInvoiceById, createInvoice, updateInvoice, cancelInvoice, duplicateInvoice, deleteInvoice };

