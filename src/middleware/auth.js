// backend/src/middleware/auth.js

const jwt = require('jsonwebtoken');
const { verifyFirebaseToken } = require('../config/firebase');
const { query } = require('../config/database');
const logger = require('../utils/logger');

// ─── Custom JWT secret (for username/password auth) ────────────────────────
const JWT_SECRET = process.env.JWT_SECRET || 'gst_app_jwt_secret_key_2024';

// ─── DEV-ONLY test token bypass ────────────────────────────────────────────
const DEV_TEST_TOKEN = process.env.DEV_TEST_TOKEN || 'dev_test_token_gst_2024';
const DEV_TEST_UID   = 'dev_test_uid_001';

/**
 * Verify a custom JWT (issued by db-login) and look up the user.
 */
async function authenticateCustomJwt(token) {
  const decoded = jwt.verify(token, JWT_SECRET);

  // Query gst_app.users directly using the userId from JWT
  const userResult = await query(
    'SELECT * FROM gst_app.users WHERE id = $1 AND is_active = true LIMIT 1',
    [decoded.userId]
  );

  if (userResult.rows.length === 0) {
    throw new Error('User not found');
  }

  const dbUser = userResult.rows[0];

  // Check business setup
  const bizResult = await query(
    `SELECT id, name as business_name, gstin as business_gstin,
            state as business_state, state_code as business_state_code
     FROM gst_app.businesses
     WHERE user_id = $1 AND is_active = true
     LIMIT 1`,
    [decoded.userId]
  );

  const biz = bizResult.rows[0] || {};
  const u = {
    id: dbUser.id,
    firebase_uid: `custom_${dbUser.id}`,
    email: dbUser.email || '',
    phone: dbUser.phone || '',
    name: dbUser.name || '',
    photo_url: dbUser.photo_url || null,
    role: dbUser.role || 'user',
    business_setup_done: !!biz.id,
    is_active: dbUser.is_active,
    last_login_at: dbUser.last_login_at,
    created_at: dbUser.created_at,
    updated_at: dbUser.updated_at,
    businessId: biz.id || null,
    businessGstin: biz.business_gstin || null,
    businessState: biz.business_state || null,
    businessStateCode: biz.business_state_code || null,
  };
  return u;
}

/**
 * Middleware to verify Firebase JWT (or custom JWT) and attach user/business context
 */
const authenticate = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Authorization header missing' });
    }

    const token = authHeader.split(' ')[1];

    // ── DEV bypass: skip Firebase if test token is provided ──────────────
    if (process.env.NODE_ENV !== 'production' && token === DEV_TEST_TOKEN) {
      const userResult = await query(
        `SELECT u.*, b.id as business_id, b.name as business_name, b.gstin as business_gstin,
                b.state as business_state, b.state_code as business_state_code
         FROM users u
         LEFT JOIN businesses b ON b.user_id = u.id AND b.is_active = true
         WHERE u.firebase_uid = $1
         LIMIT 1`,
        [DEV_TEST_UID]
      );

      if (userResult.rows.length === 0) {
        const newUser = await query(
          `INSERT INTO users (firebase_uid, email, phone, name, created_at, updated_at)
           VALUES ($1, $2, $3, $4, NOW(), NOW())
           ON CONFLICT (firebase_uid) DO UPDATE SET updated_at = NOW()
           RETURNING *`,
          [DEV_TEST_UID, 'testuser@dev.local', '+919999999999', 'Test User']
        );
        req.user = newUser.rows[0];
        req.user.businessId = null;
      } else {
        req.user = userResult.rows[0];
        req.user.businessId    = userResult.rows[0].business_id;
        req.user.businessGstin = userResult.rows[0].business_gstin;
        req.user.businessState = userResult.rows[0].business_state;
        req.user.businessStateCode = userResult.rows[0].business_state_code;
      }
      logger.info('DEV bypass auth used for test user');
      return next();
    }
    // ─────────────────────────────────────────────────────────────────────

    // ── Try custom JWT first ────────────────────────────────────────────
    let isCustomToken = false;
    try {
      req.user = await authenticateCustomJwt(token);
      isCustomToken = true;
    } catch (customJwtError) {
      // Not a custom JWT — fall through to Firebase
    }

    if (isCustomToken) {
      return next();
    }
    // ─────────────────────────────────────────────────────────────────────

    const decoded = await verifyFirebaseToken(token);

    // Get or create user in DB
    const userResult = await query(
      `SELECT u.*, b.id as business_id, b.name as business_name, b.gstin as business_gstin,
              b.state as business_state, b.state_code as business_state_code
       FROM users u
       LEFT JOIN businesses b ON b.user_id = u.id AND b.is_active = true
       WHERE u.firebase_uid = $1
       LIMIT 1`,
      [decoded.uid]
    );

    if (userResult.rows.length === 0) {
      // Auto-create user
      const newUser = await query(
        `INSERT INTO users (firebase_uid, email, phone, name, photo_url, created_at)
         VALUES ($1, $2, $3, $4, $5, NOW())
         RETURNING *`,
        [decoded.uid, decoded.email, decoded.phone_number, decoded.name, decoded.picture]
      );
      req.user = newUser.rows[0];
      req.user.businessId = null;
    } else {
      req.user = userResult.rows[0];
      req.user.businessId = userResult.rows[0].business_id;
      req.user.businessGstin = userResult.rows[0].business_gstin;
      req.user.businessState = userResult.rows[0].business_state;
      req.user.businessStateCode = userResult.rows[0].business_state_code;
    }

    next();
  } catch (error) {
    logger.warn('Authentication failed:', error.message);
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
};

/**
 * Require business setup before accessing resource
 */
const requireBusiness = (req, res, next) => {
  if (!req.user?.businessId) {
    return res.status(403).json({
      error: 'Business setup required',
      code: 'BUSINESS_SETUP_REQUIRED',
    });
  }
  next();
};

/**
 * Admin role check
 */
const requireAdmin = (req, res, next) => {
  if (req.user?.role !== 'admin') {
    return res.status(403).json({ error: 'Admin access required' });
  }
  next();
};

module.exports = { authenticate, requireBusiness, requireAdmin };

