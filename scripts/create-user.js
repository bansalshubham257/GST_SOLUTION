/**
 * Create a user in gst_app.users for username/password login.
 *
 * Usage:
 *   DATABASE_URL="postgresql://postgres:PASSWORD@switchback.proxy.rlwy.net:22297/railway" node scripts/create-user.js
 *
 * This script will prompt you for the user details and
 * insert them directly into the Railway PostgreSQL database.
 */

const { Pool } = require('pg');
const bcrypt = require('bcryptjs');
const readline = require('readline');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

function ask(query) {
  return new Promise((resolve) => rl.question(query, resolve));
}

async function main() {
  console.log('\n=== Create a New User Account ===\n');

  const DATABASE_URL = process.env.DATABASE_URL;
  if (!DATABASE_URL) {
    console.log('ERROR: DATABASE_URL environment variable is not set.');
    console.log('Run this script with:');
    console.log('');
    console.log('  DATABASE_URL="postgresql://postgres:PASSWORD@switchback.proxy.rlwy.net:22297/railway" node scripts/create-user.js');
    console.log('');
    process.exit(1);
  }

  const username = await ask('Username: ');
  if (!username) { console.log('Username is required.'); process.exit(1); }

  const password = await ask('Password: ');
  if (!password) { console.log('Password is required.'); process.exit(1); }

  const name = await ask('Full Name (optional): ') || '';
  const email = await ask('Email (optional): ') || '';
  const phone = await ask('Phone (optional): ') || '';

  console.log('\nPlan limits (press Enter for defaults — 2 staff, 2 services, 2 sales):');
  const maxStaff = parseInt(await ask('  Max Staff [2]: ') || '2');
  const maxServices = parseInt(await ask('  Max Services [2]: ') || '2');
  const maxSales = parseInt(await ask('  Max Sales [2]: ') || '2');

  const pool = new Pool({ connectionString: DATABASE_URL, ssl: { rejectUnauthorized: false } });

  try {
    // Check if username exists
    const existing = await pool.query('SELECT id FROM gst_app.users WHERE username = $1', [username]);
    if (existing.rows.length > 0) {
      console.log(`\nERROR: Username "${username}" already exists.`);
      process.exit(1);
    }

    const passwordHash = await bcrypt.hash(password, 10);
    const result = await pool.query(
      `INSERT INTO gst_app.users (username, password_hash, name, email, phone, plan_type, max_staff, max_services, max_sales)
       VALUES ($1, $2, $3, $4, $5, 'free', $6, $7, $8)
       RETURNING id, username, name, plan_type, max_staff, max_services, max_sales`,
      [username, passwordHash, name, email, phone, maxStaff, maxServices, maxSales]
    );

    const user = result.rows[0];
    console.log('\n=== User Created Successfully! ===');
    console.log(`  ID:       ${user.id}`);
    console.log(`  Username: ${user.username}`);
    console.log(`  Name:     ${user.name || '(not set)'}`);
    console.log(`  Plan:     ${user.plan_type}`);
    console.log(`  Limits:   ${user.max_staff} staff, ${user.max_services} services, ${user.max_sales} sales`);
    console.log('\nGive the user these credentials:');
    console.log(`  Username: ${user.username}`);
    console.log(`  Password: ${password}`);
    console.log('');
  } catch (err) {
    console.error('\nError creating user:', err.message);
  } finally {
    await pool.end();
    rl.close();
  }
}

main();
