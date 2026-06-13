// backend/src/controllers/product.controller.js

const { query } = require('../config/database');
const { AppError } = require('../middleware/errorHandler');

const formatProduct = (p) => ({
  id: p.id,
  businessId: p.business_id,
  name: p.name,
  description: p.description,
  hsnSacCode: p.hsn_sac_code,
  isService: p.is_service,
  unitPrice: parseFloat(p.unit_price || 0),
  unit: p.unit,
  gstRate: parseFloat(p.gst_rate || 18),
  isActive: p.is_active,
  createdAt: p.created_at,
  updatedAt: p.updated_at,
});

/**
 * GET /products
 */
const getProducts = async (req, res, next) => {
  try {
    const { search } = req.query;
    const params = [req.user.businessId];
    let where = 'WHERE business_id = $1 AND is_active = true';

    if (search) {
      params.push(`%${search}%`);
      where += ` AND (name ILIKE $${params.length} OR description ILIKE $${params.length})`;
    }

    const result = await query(
      `SELECT * FROM products ${where} ORDER BY name ASC`,
      params
    );
    res.json({ products: result.rows.map(formatProduct) });
  } catch (err) {
    next(err);
  }
};

/**
 * POST /products
 */
const createProduct = async (req, res, next) => {
  try {
    const { name, description, hsnSacCode, isService, unitPrice, unit, gstRate } = req.body;
    if (!name) return res.status(400).json({ error: 'Product name required' });

    const result = await query(
      `INSERT INTO products (business_id, name, description, hsn_sac_code, is_service, unit_price, unit, gst_rate, created_at, updated_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,NOW(),NOW())
       RETURNING *`,
      [req.user.businessId, name, description, hsnSacCode, isService || false, unitPrice || 0, unit || 'Nos', gstRate || 18]
    );

    res.status(201).json({ product: formatProduct(result.rows[0]), message: 'Product created' });
  } catch (err) {
    next(err);
  }
};

/**
 * PUT /products/:id
 */
const updateProduct = async (req, res, next) => {
  try {
    const { name, description, hsnSacCode, isService, unitPrice, unit, gstRate } = req.body;

    const result = await query(
      `UPDATE products SET
         name = COALESCE($1, name),
         description = COALESCE($2, description),
         hsn_sac_code = COALESCE($3, hsn_sac_code),
         is_service = COALESCE($4, is_service),
         unit_price = COALESCE($5, unit_price),
         unit = COALESCE($6, unit),
         gst_rate = COALESCE($7, gst_rate),
         updated_at = NOW()
       WHERE id = $8 AND business_id = $9
       RETURNING *`,
      [name, description, hsnSacCode, isService, unitPrice, unit, gstRate, req.params.id, req.user.businessId]
    );
    if (!result.rows[0]) throw new AppError('Product not found', 404, 'NOT_FOUND');
    res.json({ product: formatProduct(result.rows[0]) });
  } catch (err) {
    next(err);
  }
};

/**
 * DELETE /products/:id
 */
const deleteProduct = async (req, res, next) => {
  try {
    await query(
      'UPDATE products SET is_active = false, updated_at = NOW() WHERE id = $1 AND business_id = $2',
      [req.params.id, req.user.businessId]
    );
    res.json({ message: 'Product deleted' });
  } catch (err) {
    next(err);
  }
};

module.exports = { getProducts, createProduct, updateProduct, deleteProduct };

