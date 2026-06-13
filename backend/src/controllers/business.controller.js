// backend/src/controllers/business.controller.js

const { query, transaction } = require('../config/database');
const { validateGstin, validatePan } = require('../services/gstService');
const logger = require('../utils/logger');

/**
 * GET /business
 */
const getBusiness = async (req, res, next) => {
  try {
    const result = await query(
      'SELECT * FROM businesses WHERE user_id = $1 AND is_active = true LIMIT 1',
      [req.user.id]
    );
    if (!result.rows[0]) return res.status(404).json({ error: 'Business not found' });
    res.json({ business: formatBusiness(result.rows[0]) });
  } catch (err) {
    next(err);
  }
};

/**
 * POST /business/setup
 * Create or update business profile
 */
const setupBusiness = async (req, res, next) => {
  try {
    const {
      name, gstin, pan, email, phone, address, city, state, stateCode,
      pincode, businessType, registrationType, logoUrl, invoicePrefix,
      bankName, bankAccount, bankIfsc, bankBranch,
    } = req.body;

    if (!name) return res.status(400).json({ error: 'Business name is required' });
    if (gstin) {
      const gstinVal = validateGstin(gstin.toUpperCase());
      if (!gstinVal.valid) return res.status(400).json({ error: gstinVal.error });
    }

    const existing = await query(
      'SELECT id FROM businesses WHERE user_id = $1 AND is_active = true LIMIT 1',
      [req.user.id]
    );

    let business;
    if (existing.rows[0]) {
      const result = await query(
        `UPDATE businesses SET
           name = $1, gstin = $2, pan = $3, email = $4, phone = $5, address = $6,
           city = $7, state = $8, state_code = $9, pincode = $10, business_type = $11,
           registration_type = $12, logo_url = COALESCE($13, logo_url),
           invoice_prefix = COALESCE($14, invoice_prefix),
           bank_name = $15, bank_account = $16, bank_ifsc = $17, bank_branch = $18,
           updated_at = NOW()
         WHERE id = $19 AND user_id = $20
         RETURNING *`,
        [name, gstin?.toUpperCase(), pan?.toUpperCase(), email, phone, address,
          city, state, stateCode || gstin?.substring(0, 2), pincode, businessType,
          registrationType, logoUrl, invoicePrefix,
          bankName, bankAccount, bankIfsc, bankBranch,
          existing.rows[0].id, req.user.id]
      );
      business = result.rows[0];
    } else {
      const result = await query(
        `INSERT INTO businesses
          (user_id, name, gstin, pan, email, phone, address, city, state, state_code,
           pincode, business_type, registration_type, logo_url, invoice_prefix,
           bank_name, bank_account, bank_ifsc, bank_branch, created_at, updated_at)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,NOW(),NOW())
         RETURNING *`,
        [req.user.id, name, gstin?.toUpperCase(), pan?.toUpperCase(), email, phone,
          address, city, state, stateCode || gstin?.substring(0, 2), pincode,
          businessType || 'sole_proprietorship', registrationType || 'regular',
          logoUrl, invoicePrefix || 'INV',
          bankName, bankAccount, bankIfsc, bankBranch]
      );
      business = result.rows[0];

      // Mark user as setup done
      await query('UPDATE users SET business_setup_done = true, updated_at = NOW() WHERE id = $1', [req.user.id]);
    }

    res.json({ business: formatBusiness(business), message: 'Business profile saved' });
  } catch (err) {
    next(err);
  }
};

/**
 * PATCH /business/logo
 */
const updateLogo = async (req, res, next) => {
  try {
    const { logoUrl } = req.body;
    if (!logoUrl) return res.status(400).json({ error: 'Logo URL required' });
    const result = await query(
      'UPDATE businesses SET logo_url = $1, updated_at = NOW() WHERE user_id = $2 AND is_active = true RETURNING logo_url',
      [logoUrl, req.user.id]
    );
    res.json({ logoUrl: result.rows[0]?.logo_url });
  } catch (err) {
    next(err);
  }
};

/**
 * PATCH /business/settings
 */
const updateSettings = async (req, res, next) => {
  try {
    const { invoicePrefix, termsAndConditions, signatureUrl, defaultNotes } = req.body;
    const result = await query(
      `UPDATE businesses SET
         invoice_prefix = COALESCE($1, invoice_prefix),
         terms_and_conditions = COALESCE($2, terms_and_conditions),
         signature_url = COALESCE($3, signature_url),
         default_notes = COALESCE($4, default_notes),
         updated_at = NOW()
       WHERE user_id = $5 AND is_active = true
       RETURNING *`,
      [invoicePrefix, termsAndConditions, signatureUrl, defaultNotes, req.user.id]
    );
    res.json({ business: formatBusiness(result.rows[0]) });
  } catch (err) {
    next(err);
  }
};

const formatBusiness = (b) => ({
  id: b.id,
  userId: b.user_id,
  name: b.name,
  gstin: b.gstin,
  pan: b.pan,
  email: b.email,
  phone: b.phone,
  address: b.address,
  city: b.city,
  state: b.state,
  stateCode: b.state_code,
  pincode: b.pincode,
  businessType: b.business_type,
  registrationType: b.registration_type,
  logoUrl: b.logo_url,
  invoicePrefix: b.invoice_prefix,
  bankName: b.bank_name,
  bankAccount: b.bank_account,
  bankIfsc: b.bank_ifsc,
  bankBranch: b.bank_branch,
  termsAndConditions: b.terms_and_conditions,
  signatureUrl: b.signature_url,
  defaultNotes: b.default_notes,
  createdAt: b.created_at,
  updatedAt: b.updated_at,
});

module.exports = { getBusiness, setupBusiness, updateLogo, updateSettings };

