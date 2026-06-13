// backend/src/config/migrate.js
// Simple migration runner

require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { pool } = require('./database');
const logger = require('../utils/logger');

async function runMigrations() {
  const migrationsDir = path.join(__dirname, '../../database/migrations');

  if (!fs.existsSync(migrationsDir)) {
    logger.warn('No migrations directory found');
    return;
  }

  const files = fs.readdirSync(migrationsDir)
    .filter((f) => f.endsWith('.sql'))
    .sort();

  // Create migrations table if not exists
  await pool.query(`
    CREATE TABLE IF NOT EXISTS _migrations (
      id SERIAL PRIMARY KEY,
      filename VARCHAR(255) UNIQUE NOT NULL,
      run_at TIMESTAMPTZ DEFAULT NOW()
    )
  `);

  for (const file of files) {
    const alreadyRun = await pool.query(
      'SELECT id FROM _migrations WHERE filename = $1',
      [file]
    );

    if (alreadyRun.rows.length > 0) {
      logger.info(`Skipping already run migration: ${file}`);
      continue;
    }

    const sql = fs.readFileSync(path.join(migrationsDir, file), 'utf8');
    logger.info(`Running migration: ${file}`);

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      await client.query(sql);
      await client.query('INSERT INTO _migrations (filename) VALUES ($1)', [file]);
      await client.query('COMMIT');
      logger.info(`✅ Migration complete: ${file}`);
    } catch (error) {
      await client.query('ROLLBACK');
      logger.error(`❌ Migration failed: ${file}`, error.message);
      throw error;
    } finally {
      client.release();
    }
  }

  logger.info('All migrations complete');
  await pool.end();
}

runMigrations().catch((err) => {
  logger.error('Migration error:', err);
  process.exit(1);
});

