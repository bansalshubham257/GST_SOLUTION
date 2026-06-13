// backend/src/controllers/admin.controller.js

const bcrypt = require('bcryptjs');
const { query } = require('../config/database');

/**
 * GET /admin/stats
 */
const getAdminStats = async (req, res, next) => {
  try {
    const [users, businesses, invoices, revenue] = await Promise.all([
      query('SELECT COUNT(*) FROM users WHERE is_active = true'),
      query('SELECT COUNT(*) FROM businesses WHERE is_active = true'),
      query('SELECT COUNT(*) FROM invoices WHERE status != \'cancelled\''),
      query('SELECT COALESCE(SUM(grand_total), 0) as total FROM invoices WHERE status = \'sent\''),
    ]);

    res.json({
      totalUsers: parseInt(users.rows[0].count),
      totalBusinesses: parseInt(businesses.rows[0].count),
      totalInvoices: parseInt(invoices.rows[0].count),
      totalRevenue: parseFloat(revenue.rows[0].total),
    });
  } catch (err) {
    next(err);
  }
};

/**
 * GET /admin/users
 */
const getUsers = async (req, res, next) => {
  try {
    const { page = 1, limit = 20, search } = req.query;
    const offset = (page - 1) * limit;

    let where = 'WHERE u.is_active = true';
    const params = [];
    if (search) {
      params.push(`%${search}%`);
      where += ` AND (u.name ILIKE $${params.length} OR u.email ILIKE $${params.length})`;
    }
    params.push(limit, offset);

    const result = await query(
      `SELECT u.id, u.name, u.email, u.phone, u.role, u.created_at,
              b.name as business_name, b.gstin
       FROM users u
       LEFT JOIN businesses b ON b.user_id = u.id AND b.is_active = true
       ${where}
       ORDER BY u.created_at DESC
       LIMIT $${params.length - 1} OFFSET $${params.length}`,
      params
    );

    res.json({ users: result.rows });
  } catch (err) {
    next(err);
  }
};

/**
 * GET /admin/logs
 */
const getLogs = async (req, res, next) => {
  try {
    // In production, read from a logs table or external log service
    res.json({ logs: [], message: 'Log viewing coming soon' });
  } catch (err) {
    next(err);
  }
};

/**
 * POST /admin/create-user
 * Create a new user in gst_app.users (for admin to provision accounts).
 * Protected by X-Admin-Key header matching ADMIN_SECRET_KEY env var.
 */
const createUser = async (req, res, next) => {
  try {
    const adminKey = req.headers['x-admin-key'];
    const expectedKey = process.env.ADMIN_SECRET_KEY || 'admin_secret_key_2024';
    if (adminKey !== expectedKey) {
      return res.status(403).json({ error: 'Invalid admin key' });
    }

    const { username, password, name, email, phone, planType, maxStaff, maxServices, maxSales } = req.body;
    if (!username || !password) {
      return res.status(400).json({ error: 'Username and password are required' });
    }

    // Check if username already exists
    const existing = await query('SELECT id FROM gst_app.users WHERE username = $1', [username]);
    if (existing.rows.length > 0) {
      return res.status(409).json({ error: 'Username already exists' });
    }

    const passwordHash = await bcrypt.hash(password, 10);
    const result = await query(
      `INSERT INTO gst_app.users (username, password_hash, name, email, phone, plan_type, max_staff, max_services, max_sales)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       RETURNING id, username, name, email, phone, plan_type, max_staff, max_services, max_sales, created_at`,
      [
        username, passwordHash, name || '', email || '', phone || '',
        planType || 'free',
        maxStaff || 2,
        maxServices || 2,
        maxSales || 2,
      ]
    );

    res.status(201).json({ user: result.rows[0] });
  } catch (err) {
    next(err);
  }
};

module.exports = { getAdminStats, getUsers, getLogs, createUser };

