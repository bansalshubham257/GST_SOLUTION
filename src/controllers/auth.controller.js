// backend/src/controllers/auth.controller.js

const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const { query } = require('../config/database');
const logger = require('../utils/logger');

const JWT_SECRET = process.env.JWT_SECRET || 'gst_app_jwt_secret_key_2024';

/**
 * POST /auth/login
 * Sync/create user after Firebase auth
 */
const login = async (req, res, next) => {
  try {
    const { uid, email, phone, name, photoUrl } = req.body;
    if (!uid) return res.status(400).json({ error: 'Firebase UID required' });

    // Upsert user
    const result = await query(
      `INSERT INTO users (firebase_uid, email, phone, name, photo_url, last_login_at, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, NOW(), NOW(), NOW())
       ON CONFLICT (firebase_uid) DO UPDATE
         SET email = COALESCE(EXCLUDED.email, users.email),
             phone = COALESCE(EXCLUDED.phone, users.phone),
             name = COALESCE(EXCLUDED.name, users.name),
             photo_url = COALESCE(EXCLUDED.photo_url, users.photo_url),
             last_login_at = NOW(),
             updated_at = NOW()
       RETURNING *`,
      [uid, email, phone, name, photoUrl]
    );

    const user = result.rows[0];

    // Check if business exists
    const bizResult = await query(
      'SELECT id FROM businesses WHERE user_id = $1 AND is_active = true LIMIT 1',
      [user.id]
    );

    const responseUser = {
      id: user.id,
      firebaseUid: user.firebase_uid,
      email: user.email,
      phone: user.phone,
      name: user.name,
      photoUrl: user.photo_url,
      role: user.role,
      isBusinessSetupDone: bizResult.rows.length > 0,
      businessId: bizResult.rows[0]?.id || null,
      createdAt: user.created_at,
    };

    res.json({ user: responseUser });
  } catch (err) {
    next(err);
  }
};

/**
 * GET /auth/me
 */
const getMe = async (req, res) => {
  const user = req.user;

  // Fetch plan/limit info for custom JWT users
  let plan = 'free', maxStaff = 999, maxServices = 999, maxSales = 999;
  if (user.firebase_uid && user.firebase_uid.startsWith('custom_')) {
    const customId = user.firebase_uid.replace('custom_', '');
    try {
      const planResult = await query(
        'SELECT plan_type, max_staff, max_services, max_sales FROM gst_app.users WHERE id = $1',
        [customId]
      );
      if (planResult.rows.length > 0) {
        plan = planResult.rows[0].plan_type || 'free';
        maxStaff = planResult.rows[0].max_staff || 999;
        maxServices = planResult.rows[0].max_services || 999;
        maxSales = planResult.rows[0].max_sales || 999;
      }
    } catch (_) { /* gst_app schema might not exist */ }
  }

  res.json({
    id: user.id,
    firebaseUid: user.firebase_uid,
    email: user.email,
    phone: user.phone,
    name: user.name,
    photoUrl: user.photo_url,
    role: user.role,
    isBusinessSetupDone: !!user.businessId,
    businessId: user.businessId,
    businessGstin: user.businessGstin,
    plan,
    maxStaff,
    maxServices,
    maxSales,
    createdAt: user.created_at,
  });
};

/**
 * POST /auth/logout
 */
const logout = async (req, res) => {
  // Client side clears token; server side can blacklist if needed
  res.json({ message: 'Logged out successfully' });
};

/**
 * DELETE /auth/account
 */
const deleteAccount = async (req, res, next) => {
  try {
    await query('UPDATE users SET is_active = false, updated_at = NOW() WHERE id = $1', [req.user.id]);
    res.json({ message: 'Account deactivated' });
  } catch (err) {
    next(err);
  }
};

/**
 * POST /auth/dev-login  (DEVELOPMENT ONLY)
 * Returns the test token and creates/fetches the test user — no OTP needed.
 */
const devLogin = async (req, res, next) => {
  if (process.env.NODE_ENV === 'production') {
    return res.status(404).json({ error: 'Not found' });
  }
  try {
    const DEV_TEST_UID   = 'dev_test_uid_001';
    const DEV_TEST_TOKEN = process.env.DEV_TEST_TOKEN || 'dev_test_token_gst_2024';

    const result = await query(
      `INSERT INTO users (firebase_uid, email, phone, name, created_at, updated_at)
       VALUES ($1, $2, $3, $4, NOW(), NOW())
       ON CONFLICT (firebase_uid) DO UPDATE
         SET updated_at = NOW()
       RETURNING *`,
      [DEV_TEST_UID, 'testuser@dev.local', '+919999999999', 'Test User']
    );
    const user = result.rows[0];

    const bizResult = await query(
      'SELECT id FROM businesses WHERE user_id = $1 AND is_active = true LIMIT 1',
      [user.id]
    );

    res.json({
      message: '⚠️  DEV-ONLY login — remove before production',
      token: DEV_TEST_TOKEN,
      user: {
        id:                 user.id,
        firebaseUid:        user.firebase_uid,
        email:              user.email,
        phone:              user.phone,
        name:               user.name,
        role:               user.role,
        isBusinessSetupDone: bizResult.rows.length > 0,
        businessId:         bizResult.rows[0]?.id || null,
        createdAt:          user.created_at,
      },
    });
  } catch (err) {
    next(err);
  }
};

/**
 * POST /auth/db-login
 * Username/password login — queries gst_app.users, returns custom JWT.
 * No signup — admin creates users directly in the DB.
 */
const dbLogin = async (req, res, next) => {
  try {
    const { username, password } = req.body;
    if (!username || !password) {
      return res.status(400).json({ error: 'Username and password required' });
    }

    // Look up user in gst_app schema
    const userResult = await query(
      'SELECT * FROM gst_app.users WHERE username = $1 AND is_active = true',
      [username]
    );

    if (userResult.rows.length === 0) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const dbUser = userResult.rows[0];

    // Verify password
    const valid = await bcrypt.compare(password, dbUser.password_hash);
    if (!valid) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Update last login
    await query('UPDATE gst_app.users SET last_login_at = NOW() WHERE id = $1', [dbUser.id]);

    // Generate custom JWT
    const token = jwt.sign(
      {
        userId: dbUser.id,
        username: dbUser.username,
        plan: dbUser.plan_type,
      },
      JWT_SECRET,
      { expiresIn: '30d' }
    );

    // Check business setup
    const bizResult = await query(
      'SELECT id FROM gst_app.businesses WHERE user_id = $1 AND is_active = true LIMIT 1',
      [dbUser.id]
    );

    res.json({
      token,
      user: {
        id: dbUser.id,
        firebaseUid: `custom_${dbUser.id}`,
        email: dbUser.email || '',
        phone: dbUser.phone || '',
        name: dbUser.name || '',
        role: dbUser.role || 'user',
        plan: dbUser.plan_type,
        maxStaff: dbUser.max_staff,
        maxServices: dbUser.max_services,
        maxSales: dbUser.max_sales,
        isBusinessSetupDone: bizResult.rows.length > 0,
        businessId: bizResult.rows[0]?.id || null,
        createdAt: dbUser.created_at,
      },
    });
  } catch (err) {
    next(err);
  }
};

/**
 * POST /auth/db-demo-login
 * One-click demo login using a predefined demo account.
 */
const dbDemoLogin = async (req, res, next) => {
  req.body = { username: 'demo', password: 'demo123' };
  return dbLogin(req, res, next);
};

/**
 * POST /auth/signup
 * Create a new account with free plan (local-only, 2-record limit).
 * Admin can upgrade plan_type in DB to 'local_paid' or 'db_paid'.
 */
const signup = async (req, res, next) => {
  try {
    const { username, password, name } = req.body;
    if (!username || !password) {
      return res.status(400).json({ error: 'Username and password are required' });
    }
    if (password.length < 4) {
      return res.status(400).json({ error: 'Password must be at least 4 characters' });
    }

    // Check if username already exists
    const existing = await query(
      'SELECT id FROM gst_app.users WHERE username = $1',
      [username]
    );
    if (existing.rows.length > 0) {
      return res.status(409).json({ error: 'Username already taken' });
    }

    const passwordHash = await bcrypt.hash(password, 10);
    const result = await query(
      `INSERT INTO gst_app.users (username, password_hash, name, plan_type, max_staff, max_services, max_sales)
       VALUES ($1, $2, $3, 'free', 2, 2, 2)
       RETURNING id, username, name, plan_type, max_staff, max_services, max_sales, created_at`,
      [username, passwordHash, name || username]
    );

    const dbUser = result.rows[0];

    const token = jwt.sign(
      { userId: dbUser.id, username: dbUser.username, plan: dbUser.plan_type },
      JWT_SECRET,
      { expiresIn: '30d' }
    );

    res.status(201).json({
      token,
      user: {
        id: dbUser.id,
        firebaseUid: `custom_${dbUser.id}`,
        name: dbUser.name || '',
        plan: dbUser.plan_type,
        maxStaff: dbUser.max_staff,
        maxServices: dbUser.max_services,
        maxSales: dbUser.max_sales,
        isBusinessSetupDone: false,
        businessId: null,
        createdAt: dbUser.created_at,
      },
    });
  } catch (err) {
    next(err);
  }
};

module.exports = { login, getMe, logout, deleteAccount, devLogin, dbLogin, dbDemoLogin, signup };

