-- Create the gst_app schema for custom auth (username/password, not Firebase)
-- Run this once against the Railway PostgreSQL database.

CREATE SCHEMA IF NOT EXISTS gst_app;

CREATE TABLE IF NOT EXISTS gst_app.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL DEFAULT '',
    email VARCHAR(255) DEFAULT '',
    phone VARCHAR(20) DEFAULT '',
    plan_type VARCHAR(20) NOT NULL DEFAULT 'free' CHECK (plan_type IN ('free', 'basic', 'premium')),
    max_staff INTEGER NOT NULL DEFAULT 2,
    max_services INTEGER NOT NULL DEFAULT 2,
    max_sales INTEGER NOT NULL DEFAULT 2,
    is_active BOOLEAN NOT NULL DEFAULT true,
    last_login_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_username ON gst_app.users(username);

-- Insert demo user (password: demo123)
-- bcrypt hash generated for 'demo123'
INSERT INTO gst_app.users (username, password_hash, name, phone, plan_type, max_staff, max_services, max_sales)
VALUES ('demo', '$2a$10$71zlJ73c40xnv7AnfVyxl.dubAsESmnmdR5qQGH9/MxZtEV65etsO', 'Demo User', '+919999999999', 'free', 2, 2, 2)
ON CONFLICT (username) DO NOTHING;

-- To add more users, run the create-user script:
--   DATABASE_URL="postgresql://postgres:PASSWORD@switchback.proxy.rlwy.net:22297/railway" node backend/scripts/create-user.js
-- Or insert directly:
--   First generate a bcrypt hash:
--     node -e "console.log(require('bcryptjs').hashSync('mypassword', 10))"
--   Then:
--     INSERT INTO gst_app.users (username, password_hash, name, plan_type, max_staff, max_services, max_sales)
--     VALUES ('username', '<hash>', 'Full Name', 'free', 2, 2, 2);
