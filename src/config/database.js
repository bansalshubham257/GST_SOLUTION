// backend/src/config/database.js

const { Pool } = require('pg');
const logger = require('../utils/logger');

const searchPathUrl = process.env.DATABASE_URL + (process.env.DATABASE_URL.includes('?') ? '&' : '?') + 'options=-c%20search_path%3Dgst_app%2Cpublic';

const pool = new Pool({
  connectionString: searchPathUrl,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

pool.on('error', (err) => {
  logger.error('Unexpected database error:', err);
});

const query = async (text, params) => {
  const start = Date.now();
  const client = await pool.connect();
  try {
    await client.query("SET search_path TO gst_app, public");
    const res = await client.query(text, params);
    const duration = Date.now() - start;
    if (duration > 1000) {
      logger.warn('Slow query detected', { text, duration });
    }
    return res;
  } finally {
    client.release();
  }
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
    await client.query("SET search_path TO gst_app, public");
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

