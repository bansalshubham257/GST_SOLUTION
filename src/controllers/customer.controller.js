// backend/src/controllers/customer.controller.js

const { query } = require('../config/database');
const { validateGstin } = require('../services/gstService');
const { AppError } = require('../middleware/errorHandler');

const formatCustomer = (c) => ({
  id: c.id,
  businessId: c.business_id,
  name: c.name,
  gstin: c.gstin,
  pan: c.pan,
  phone: c.phone,
  email: c.email,
  address: c.address,
  city: c.city,
  state: c.state,
  stateCode: c.state_code,
  pincode: c.pincode,
  invoiceCount: parseInt(c.invoice_count || 0),
  totalBusiness: parseFloat(c.total_business || 0),
  notes: c.notes,
  createdAt: c.created_at,
  updatedAt: c.updated_at,
});

/**
 * GET /customers
 */
const getCustomers = async (req, res, next) => {
  try {
    const { search, page = 1, limit = 50 } = req.query;
    const offset = (page - 1) * limit;
    const params = [req.user.businessId];
    let where = 'WHERE business_id = $1 AND is_active = true';

    if (search) {
      params.push(`%${search}%`);
      where += ` AND (name ILIKE $${params.length} OR gstin ILIKE $${params.length} OR phone ILIKE $${params.length})`;
    }

    params.push(limit, offset);
    const result = await query(
      `SELECT * FROM customers ${where} ORDER BY name ASC LIMIT $${params.length - 1} OFFSET $${params.length}`,
      params
    );

    const countResult = await query(
      `SELECT COUNT(*) FROM customers ${where}`,
      params.slice(0, -2)
    );

    res.json({
      customers: result.rows.map(formatCustomer),
      pagination: { page: parseInt(page), limit: parseInt(limit), total: parseInt(countResult.rows[0].count) },
    });
  } catch (err) {
    next(err);
  }
};

/**
 * GET /customers/:id
 */
const getCustomerById = async (req, res, next) => {
  try {
    const result = await query(
      'SELECT * FROM customers WHERE id = $1 AND business_id = $2',
      [req.params.id, req.user.businessId]
    );
    if (!result.rows[0]) throw new AppError('Customer not found', 404, 'NOT_FOUND');
    res.json({ customer: formatCustomer(result.rows[0]) });
  } catch (err) {
    next(err);
  }
};

/**
 * POST /customers
 */
const createCustomer = async (req, res, next) => {
  try {
    const { name, gstin, pan, phone, email, address, city, state, stateCode, pincode, notes } = req.body;
    if (!name) return res.status(400).json({ error: 'Customer name is required' });

    if (gstin) {
      const validation = validateGstin(gstin.toUpperCase());
      if (!validation.valid) return res.status(400).json({ error: validation.error });
    }

    const result = await query(
      `INSERT INTO customers (business_id, name, gstin, pan, phone, email, address, city, state,
         state_code, pincode, notes, created_at, updated_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,NOW(),NOW())
       RETURNING *`,
      [req.user.businessId, name, gstin?.toUpperCase(), pan?.toUpperCase(), phone, email,
        address, city, state, stateCode || gstin?.substring(0, 2), pincode, notes]
    );

    res.status(201).json({ customer: formatCustomer(result.rows[0]), message: 'Customer added' });
  } catch (err) {
    next(err);
  }
};

/**
 * PUT /customers/:id
 */
const updateCustomer = async (req, res, next) => {
  try {
    const { name, gstin, pan, phone, email, address, city, state, stateCode, pincode, notes } = req.body;

    if (gstin) {
      const validation = validateGstin(gstin.toUpperCase());
      if (!validation.valid) return res.status(400).json({ error: validation.error });
    }

    const result = await query(
      `UPDATE customers SET
         name = COALESCE($1, name),
         gstin = COALESCE($2, gstin),
         pan = COALESCE($3, pan),
         phone = COALESCE($4, phone),
         email = COALESCE($5, email),
         address = COALESCE($6, address),
         city = COALESCE($7, city),
         state = COALESCE($8, state),
         state_code = COALESCE($9, state_code),
         pincode = COALESCE($10, pincode),
         notes = $11,
         updated_at = NOW()
       WHERE id = $12 AND business_id = $13
       RETURNING *`,
      [name, gstin?.toUpperCase(), pan?.toUpperCase(), phone, email, address, city, state,
        stateCode, pincode, notes, req.params.id, req.user.businessId]
    );
    if (!result.rows[0]) throw new AppError('Customer not found', 404, 'NOT_FOUND');
    res.json({ customer: formatCustomer(result.rows[0]), message: 'Customer updated' });
  } catch (err) {
    next(err);
  }
};

/**
 * DELETE /customers/:id
 */
const deleteCustomer = async (req, res, next) => {
  try {
    await query(
      'UPDATE customers SET is_active = false, updated_at = NOW() WHERE id = $1 AND business_id = $2',
      [req.params.id, req.user.businessId]
    );
    res.json({ message: 'Customer deleted' });
  } catch (err) {
    next(err);
  }
};

/**
 * GET /customers/:id/invoices
 */
const getCustomerInvoices = async (req, res, next) => {
  try {
    const result = await query(
      `SELECT id, invoice_number, invoice_date, grand_total, status
       FROM invoices WHERE customer_id = $1 AND business_id = $2
       ORDER BY created_at DESC`,
      [req.params.id, req.user.businessId]
    );
    res.json({ invoices: result.rows });
  } catch (err) {
    next(err);
  }
};

/**
 * GET /customers/:id/ledger
 */
const getCustomerLedger = async (req, res, next) => {
  try {
    const result = await query(
      `SELECT invoice_number, invoice_date, grand_total, status,
              SUM(grand_total) OVER (ORDER BY invoice_date) as running_balance
       FROM invoices WHERE customer_id = $1 AND business_id = $2 AND status != 'cancelled'
       ORDER BY invoice_date`,
      [req.params.id, req.user.businessId]
    );
    res.json({ ledger: result.rows });
  } catch (err) {
    next(err);
  }
};

module.exports = { getCustomers, getCustomerById, createCustomer, updateCustomer, deleteCustomer, getCustomerInvoices, getCustomerLedger };

