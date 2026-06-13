// backend/src/config/database.js

const { Pool } = require('pg');
const logger = require('../utils/logger');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

// Set search_path so unqualified table references resolve to gst_app schema first
pool.on('connect', (client) => {
  client.query("SET search_path TO gst_app, public").catch((err) => {
    logger.warn('Failed to set search_path:', err.message);
  });
});

pool.on('error', (err) => {
  logger.error('Unexpected database error:', err);
});

const query = async (text, params) => {
  const start = Date.now();
  const res = await pool.query(text, params);
  const duration = Date.now() - start;
  if (duration > 1000) {
    logger.warn('Slow query detected', { text, duration });
  }
  return res;
};

const getClient = () => pool.connect();

const initDB = async () => {
  const client = await getClient();
  try {
    await client.query('SELECT 1');
    logger.info('Database connection verified');
  } finally {
    client.release();
  }
};

const transaction = async (callback) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await callback(client);
    await client.query('COMMIT');
    return result;
  } catch (e) {
    await client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }
};

module.exports = { pool, query, getClient, initDB, transaction };

