-- Migration 005: Create staff table in gst_app schema

CREATE TABLE IF NOT EXISTS gst_app.staff (
  id UUID PRIMARY KEY,
  business_id UUID NOT NULL REFERENCES gst_app.businesses(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  role VARCHAR(255),
  phone VARCHAR(20),
  commission_percentage DECIMAL(5,2) DEFAULT 0,
  total_revenue DECIMAL(12,2) DEFAULT 0,
  total_commission DECIMAL(12,2) DEFAULT 0,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_staff_business_id ON gst_app.staff(business_id);
