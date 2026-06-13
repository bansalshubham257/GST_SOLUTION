-- Add missing columns to gst_app.users for backward compatibility with controllers
ALTER TABLE gst_app.users
  ADD COLUMN IF NOT EXISTS firebase_uid VARCHAR(255) UNIQUE,
  ADD COLUMN IF NOT EXISTS role VARCHAR(20) NOT NULL DEFAULT 'user',
  ADD COLUMN IF NOT EXISTS business_setup_done BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS photo_url TEXT;

-- Allow NULL for username/password_hash so Firebase auth path can INSERT without them
ALTER TABLE gst_app.users ALTER COLUMN username DROP NOT NULL;
ALTER TABLE gst_app.users ALTER COLUMN password_hash DROP NOT NULL;

-- Create businesses table (needed by auth middleware LEFT JOIN and all controllers)
CREATE TABLE IF NOT EXISTS gst_app.businesses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES gst_app.users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL DEFAULT '',
    gstin VARCHAR(20) DEFAULT '',
    pan VARCHAR(20) DEFAULT '',
    phone VARCHAR(20) DEFAULT '',
    email VARCHAR(255) DEFAULT '',
    address TEXT DEFAULT '',
    city VARCHAR(100) DEFAULT '',
    state VARCHAR(100) DEFAULT '',
    state_code VARCHAR(10) DEFAULT '',
    pincode VARCHAR(10) DEFAULT '',
    business_type VARCHAR(50) DEFAULT '',
    registration_type VARCHAR(50) DEFAULT '',
    logo_url TEXT DEFAULT '',
    invoice_prefix VARCHAR(20) DEFAULT '',
    bank_name VARCHAR(255) DEFAULT '',
    bank_account VARCHAR(50) DEFAULT '',
    bank_ifsc VARCHAR(20) DEFAULT '',
    bank_branch VARCHAR(255) DEFAULT '',
    terms_and_conditions TEXT DEFAULT '',
    signature_url TEXT DEFAULT '',
    default_notes TEXT DEFAULT '',
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_businesses_user_id ON gst_app.businesses(user_id);
