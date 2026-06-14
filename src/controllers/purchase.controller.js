const { query, transaction } = require('../config/database');
const { AppError } = require('../middleware/errorHandler');

const formatPurchase = (inv) => ({
  id: inv.id,
  purchaseNumber: inv.purchase_number,
  businessId: inv.business_id,
  supplierName: inv.supplier_name,
  supplierGstin: inv.supplier_gstin,
  supplierPhone: inv.supplier_phone,
  supplierEmail: inv.supplier_email,
  supplierAddress: inv.supplier_address,
  invoiceDate: inv.invoice_date,
  dueDate: inv.due_date,
  status: inv.status,
  paymentStatus: inv.payment_status,
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

const generatePurchaseNumber = async (businessId, prefix) => {
  const result = await query(
    'SELECT COUNT(*) as cnt FROM gst_app.purchase_invoices WHERE business_id = $1',
    [businessId]
  );
  const count = parseInt(result.rows[0].cnt) + 1;
  const year = new Date().getFullYear().toString().slice(-2);
  const month = String(new Date().getMonth() + 1).padStart(2, '0');
  return `${prefix || 'PUR'}-${year}${month}-${String(count).padStart(4, '0')}`;
};

const getPurchases = async (req, res, next) => {
  try {
    const { page = 1, limit = 20, search, status, month, year } = req.query;
    const offset = (page - 1) * limit;
    const params = [req.user.businessId];
    let where = 'WHERE i.business_id = $1';

    if (search) {
      params.push(`%${search}%`);
      where += ` AND (i.purchase_number ILIKE $${params.length} OR i.supplier_name ILIKE $${params.length})`;
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
       FROM gst_app.purchase_invoices i
       LEFT JOIN gst_app.purchase_invoice_line_items il ON il.purchase_invoice_id = i.id
       ${where}
       GROUP BY i.id
       ORDER BY i.created_at DESC
       LIMIT $${params.length - 1} OFFSET $${params.length}`,
      params
    );

    const countResult = await query(
      `SELECT COUNT(*) FROM gst_app.purchase_invoices i ${where.replace(/\$${params.length - 1}|\$${params.length}/g, '')}`,
      params.slice(0, -2)
    );

    res.json({
      purchases: result.rows.map(formatPurchase),
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

const getPurchaseById = async (req, res, next) => {
  try {
    const result = await query(
      `SELECT i.*,
        COALESCE(
          json_agg(il ORDER BY il.sort_order) FILTER (WHERE il.id IS NOT NULL),
          '[]'
        ) as line_items
       FROM gst_app.purchase_invoices i
       LEFT JOIN gst_app.purchase_invoice_line_items il ON il.purchase_invoice_id = i.id
       WHERE i.id = $1 AND i.business_id = $2
       GROUP BY i.id`,
      [req.params.id, req.user.businessId]
    );
    if (!result.rows[0]) throw new AppError('Purchase not found', 404, 'NOT_FOUND');
    res.json(formatPurchase(result.rows[0]));
  } catch (err) {
    next(err);
  }
};

const createPurchase = async (req, res, next) => {
  try {
    const businessId = req.user.businessId;
    if (!businessId) throw new AppError('Business setup required', 403, 'BUSINESS_REQUIRED');

    const bizResult = await query('SELECT * FROM gst_app.businesses WHERE id = $1', [businessId]);
    const business = bizResult.rows[0];

    const purchaseNumber = await generatePurchaseNumber(businessId, business.invoice_prefix);

    const {
      supplierName, supplierGstin, supplierPhone, supplierEmail,
      supplierAddress, invoiceDate, dueDate, status = 'paid',
      paymentStatus = 'unpaid', lineItems, notes, termsAndConditions,
      isInterState: interState, subTotal, totalCgst, totalSgst, totalIgst,
      totalTax, discountAmount, grandTotal, roundOff, gstSlabs,
    } = req.body;

    const purchase = await transaction(async (client) => {
      const result = await client.query(
        `INSERT INTO gst_app.purchase_invoices (
           business_id, purchase_number, supplier_name, supplier_gstin,
           supplier_phone, supplier_email, supplier_address,
           invoice_date, due_date, status, payment_status, is_inter_state,
           sub_total, total_cgst, total_sgst, total_igst, total_cess, total_tax,
           discount_amount, grand_total, round_off, notes, terms_and_conditions,
           gst_slabs, created_at, updated_at
         ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,0,$17,$18,$19,$20,$21,$22,$23,$24,NOW(),NOW())
         RETURNING *`,
        [businessId, purchaseNumber, supplierName, supplierGstin?.toUpperCase(),
          supplierPhone, supplierEmail, supplierAddress,
          invoiceDate || new Date(), dueDate, status, paymentStatus,
          interState || false, subTotal, totalCgst, totalSgst, totalIgst,
          totalTax, discountAmount || 0, grandTotal, roundOff || 0,
          notes, termsAndConditions, JSON.stringify(gstSlabs || [])]
      );

      const inv = result.rows[0];

      if (lineItems?.length) {
        for (let i = 0; i < lineItems.length; i++) {
          const item = lineItems[i];
          await client.query(
            `INSERT INTO gst_app.purchase_invoice_line_items (
               purchase_invoice_id, description, hsn_sac_code, is_service, quantity, unit,
               unit_price, discount_percent, discount_amount, taxable_amount,
               gst_rate, cgst, sgst, igst, cess, total_amount, sort_order
             ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,0,$15,$16)`,
            [inv.id, item.description, item.hsnSacCode, item.isService || false,
              item.quantity, item.unit || 'Nos', item.unitPrice,
              item.discountPercent || 0, item.discountAmount || 0,
              item.taxableAmount, item.gstRate,
              item.cgst || 0, item.sgst || 0, item.igst || 0, item.totalAmount, i]
          );
        }
      }

      return inv;
    });

    res.status(201).json({ purchase: formatPurchase(purchase), message: 'Purchase created' });
  } catch (err) {
    next(err);
  }
};

const updatePurchase = async (req, res, next) => {
  try {
    const existing = await query(
      'SELECT * FROM gst_app.purchase_invoices WHERE id = $1 AND business_id = $2',
      [req.params.id, req.user.businessId]
    );
    if (!existing.rows[0]) throw new AppError('Purchase not found', 404, 'NOT_FOUND');
    if (existing.rows[0].status === 'cancelled') throw new AppError('Cannot edit cancelled purchase', 400, 'INVALID_STATUS');

    const {
      supplierName, supplierGstin, supplierPhone, supplierEmail, supplierAddress,
      invoiceDate, dueDate, status, paymentStatus, lineItems, notes, termsAndConditions,
      subTotal, totalCgst, totalSgst, totalIgst, totalTax, discountAmount,
      grandTotal, roundOff, isInterState: interState, gstSlabs,
    } = req.body;

    const purchase = await transaction(async (client) => {
      const result = await client.query(
        `UPDATE gst_app.purchase_invoices SET
           supplier_name = COALESCE($1, supplier_name),
           supplier_gstin = COALESCE($2, supplier_gstin),
           supplier_phone = COALESCE($3, supplier_phone),
           supplier_email = COALESCE($4, supplier_email),
           supplier_address = COALESCE($5, supplier_address),
           invoice_date = COALESCE($6, invoice_date),
           due_date = $7, status = COALESCE($8, status),
           payment_status = COALESCE($9, payment_status),
           is_inter_state = COALESCE($10, is_inter_state),
           sub_total = COALESCE($11, sub_total),
           total_cgst = COALESCE($12, total_cgst),
           total_sgst = COALESCE($13, total_sgst),
           total_igst = COALESCE($14, total_igst),
           total_tax = COALESCE($15, total_tax),
           discount_amount = COALESCE($16, discount_amount),
           grand_total = COALESCE($17, grand_total),
           round_off = COALESCE($18, round_off),
           notes = $19, terms_and_conditions = $20,
           gst_slabs = COALESCE($21, gst_slabs),
           updated_at = NOW()
         WHERE id = $22 AND business_id = $23
         RETURNING *`,
        [supplierName, supplierGstin?.toUpperCase(), supplierPhone, supplierEmail,
          supplierAddress, invoiceDate, dueDate, status, paymentStatus, interState,
          subTotal, totalCgst, totalSgst, totalIgst, totalTax, discountAmount,
          grandTotal, roundOff, notes, termsAndConditions,
          gstSlabs ? JSON.stringify(gstSlabs) : null,
          req.params.id, req.user.businessId]
      );

      const inv = result.rows[0];

      if (lineItems?.length) {
        await client.query('DELETE FROM gst_app.purchase_invoice_line_items WHERE purchase_invoice_id = $1', [inv.id]);
        for (let i = 0; i < lineItems.length; i++) {
          const item = lineItems[i];
          await client.query(
            `INSERT INTO gst_app.purchase_invoice_line_items (
               purchase_invoice_id, description, hsn_sac_code, is_service, quantity, unit,
               unit_price, discount_percent, discount_amount, taxable_amount,
               gst_rate, cgst, sgst, igst, cess, total_amount, sort_order
             ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,0,$15,$16)`,
            [inv.id, item.description, item.hsnSacCode, item.isService || false,
              item.quantity, item.unit || 'Nos', item.unitPrice,
              item.discountPercent || 0, item.discountAmount || 0,
              item.taxableAmount, item.gstRate,
              item.cgst || 0, item.sgst || 0, item.igst || 0, item.totalAmount, i]
          );
        }
      }
      return inv;
    });

    res.json({ purchase: formatPurchase(purchase), message: 'Purchase updated' });
  } catch (err) {
    next(err);
  }
};

const cancelPurchase = async (req, res, next) => {
  try {
    const result = await query(
      `UPDATE gst_app.purchase_invoices SET status = 'cancelled', updated_at = NOW()
       WHERE id = $1 AND business_id = $2 AND status != 'cancelled'
       RETURNING *`,
      [req.params.id, req.user.businessId]
    );
    if (!result.rows[0]) throw new AppError('Purchase not found or already cancelled', 404, 'NOT_FOUND');
    res.json({ message: 'Purchase cancelled', purchase: formatPurchase(result.rows[0]) });
  } catch (err) {
    next(err);
  }
};

const duplicatePurchase = async (req, res, next) => {
  try {
    const original = await query(
      'SELECT * FROM gst_app.purchase_invoices WHERE id = $1 AND business_id = $2',
      [req.params.id, req.user.businessId]
    );
    if (!original.rows[0]) throw new AppError('Purchase not found', 404, 'NOT_FOUND');

    const bizResult = await query('SELECT * FROM gst_app.businesses WHERE id = $1', [req.user.businessId]);
    const business = bizResult.rows[0];
    const newNumber = await generatePurchaseNumber(req.user.businessId, business.invoice_prefix);

    const orig = original.rows[0];
    const newInv = await transaction(async (client) => {
      const result = await client.query(
        `INSERT INTO gst_app.purchase_invoices (business_id, purchase_number, supplier_name, supplier_gstin,
           supplier_phone, supplier_email, supplier_address,
           invoice_date, status, payment_status, is_inter_state, sub_total, total_cgst, total_sgst, total_igst,
           total_cess, total_tax, discount_amount, grand_total, round_off, notes,
           terms_and_conditions, gst_slabs, created_at, updated_at)
         VALUES ($1,$2,$3,$4,$5,$6,$7,NOW(),'draft','unpaid',$8,$9,$10,$11,$12,0,$13,$14,$15,$16,$17,$18,$19,NOW(),NOW())
         RETURNING *`,
        [req.user.businessId, newNumber, orig.supplier_name, orig.supplier_gstin,
          orig.supplier_phone, orig.supplier_email, orig.supplier_address,
          orig.is_inter_state, orig.sub_total, orig.total_cgst, orig.total_sgst, orig.total_igst,
          orig.total_tax, orig.discount_amount, orig.grand_total, orig.round_off,
          orig.notes, orig.terms_and_conditions, orig.gst_slabs]
      );

      const items = await client.query(
        'SELECT * FROM gst_app.purchase_invoice_line_items WHERE purchase_invoice_id = $1',
        [orig.id]
      );
      for (const item of items.rows) {
        await client.query(
          `INSERT INTO gst_app.purchase_invoice_line_items (purchase_invoice_id,description,hsn_sac_code,is_service,quantity,unit,
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

    res.status(201).json({ purchase: formatPurchase(newInv), message: 'Purchase duplicated' });
  } catch (err) {
    next(err);
  }
};

const deletePurchase = async (req, res, next) => {
  try {
    const result = await query(
      `DELETE FROM gst_app.purchase_invoices WHERE id = $1 AND business_id = $2 AND status = 'draft' RETURNING id`,
      [req.params.id, req.user.businessId]
    );
    if (!result.rows[0]) throw new AppError('Purchase not found or cannot be deleted', 404, 'NOT_FOUND');
    res.json({ message: 'Purchase deleted' });
  } catch (err) {
    next(err);
  }
};

module.exports = { getPurchases, getPurchaseById, createPurchase, updatePurchase, cancelPurchase, duplicatePurchase, deletePurchase };
