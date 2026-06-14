-- Create remaining tables in gst_app schema for db_paid plan sync

CREATE TABLE IF NOT EXISTS gst_app.customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES gst_app.businesses(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    gstin VARCHAR(20) DEFAULT '',
    pan VARCHAR(20) DEFAULT '',
    phone VARCHAR(20) DEFAULT '',
    email VARCHAR(255) DEFAULT '',
    address TEXT DEFAULT '',
    city VARCHAR(100) DEFAULT '',
    state VARCHAR(100) DEFAULT '',
    state_code VARCHAR(10) DEFAULT '',
    pincode VARCHAR(10) DEFAULT '',
    notes TEXT DEFAULT '',
    is_active BOOLEAN NOT NULL DEFAULT true,
    invoice_count INTEGER NOT NULL DEFAULT 0,
    total_business DECIMAL(12,2) NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_customers_business_id ON gst_app.customers(business_id);
CREATE INDEX IF NOT EXISTS idx_customers_name ON gst_app.customers(name);
CREATE INDEX IF NOT EXISTS idx_customers_phone ON gst_app.customers(phone);
CREATE INDEX IF NOT EXISTS idx_customers_gstin ON gst_app.customers(gstin);

CREATE TABLE IF NOT EXISTS gst_app.products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES gst_app.businesses(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT DEFAULT '',
    hsn_sac_code VARCHAR(20) DEFAULT '',
    is_service BOOLEAN NOT NULL DEFAULT false,
    unit_price DECIMAL(12,2) NOT NULL DEFAULT 0,
    unit VARCHAR(50) DEFAULT 'nos',
    gst_rate DECIMAL(5,2) NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_products_business_id ON gst_app.products(business_id);

CREATE TABLE IF NOT EXISTS gst_app.invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES gst_app.businesses(id) ON DELETE CASCADE,
    invoice_number VARCHAR(50) NOT NULL,
    customer_id UUID REFERENCES gst_app.customers(id),
    customer_name VARCHAR(255) NOT NULL DEFAULT '',
    customer_gstin VARCHAR(20) DEFAULT '',
    customer_phone VARCHAR(20) DEFAULT '',
    customer_email VARCHAR(255) DEFAULT '',
    customer_address TEXT DEFAULT '',
    customer_state VARCHAR(100) DEFAULT '',
    invoice_date DATE NOT NULL DEFAULT CURRENT_DATE,
    due_date DATE,
    status VARCHAR(20) NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'sent', 'paid', 'cancelled', 'overdue')),
    is_inter_state BOOLEAN NOT NULL DEFAULT false,
    sub_total DECIMAL(12,2) NOT NULL DEFAULT 0,
    total_cgst DECIMAL(12,2) NOT NULL DEFAULT 0,
    total_sgst DECIMAL(12,2) NOT NULL DEFAULT 0,
    total_igst DECIMAL(12,2) NOT NULL DEFAULT 0,
    total_cess DECIMAL(12,2) NOT NULL DEFAULT 0,
    total_tax DECIMAL(12,2) NOT NULL DEFAULT 0,
    discount_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
    grand_total DECIMAL(12,2) NOT NULL DEFAULT 0,
    round_off DECIMAL(12,2) NOT NULL DEFAULT 0,
    notes TEXT DEFAULT '',
    terms_and_conditions TEXT DEFAULT '',
    gst_slabs JSONB DEFAULT '[]',
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_invoices_business_id ON gst_app.invoices(business_id);
CREATE INDEX IF NOT EXISTS idx_invoices_customer_id ON gst_app.invoices(customer_id);
CREATE INDEX IF NOT EXISTS idx_invoices_status ON gst_app.invoices(status);
CREATE INDEX IF NOT EXISTS idx_invoices_date ON gst_app.invoices(invoice_date);
CREATE INDEX IF NOT EXISTS idx_invoices_number ON gst_app.invoices(business_id, invoice_number);

CREATE TABLE IF NOT EXISTS gst_app.invoice_line_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id UUID NOT NULL REFERENCES gst_app.invoices(id) ON DELETE CASCADE,
    description TEXT NOT NULL,
    hsn_sac_code VARCHAR(20) DEFAULT '',
    is_service BOOLEAN NOT NULL DEFAULT false,
    quantity DECIMAL(12,3) NOT NULL DEFAULT 1,
    unit VARCHAR(50) DEFAULT 'nos',
    unit_price DECIMAL(12,2) NOT NULL DEFAULT 0,
    discount_percent DECIMAL(5,2) NOT NULL DEFAULT 0,
    discount_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
    taxable_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
    gst_rate DECIMAL(5,2) NOT NULL DEFAULT 0,
    cgst DECIMAL(12,2) NOT NULL DEFAULT 0,
    sgst DECIMAL(12,2) NOT NULL DEFAULT 0,
    igst DECIMAL(12,2) NOT NULL DEFAULT 0,
    cess DECIMAL(12,2) NOT NULL DEFAULT 0,
    total_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_line_items_invoice_id ON gst_app.invoice_line_items(invoice_id);

CREATE TABLE IF NOT EXISTS gst_app.chat_rooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES gst_app.users(id) ON DELETE CASCADE,
    business_id UUID REFERENCES gst_app.businesses(id),
    subject VARCHAR(255) DEFAULT '',
    status VARCHAR(20) NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed')),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_chat_rooms_user_id ON gst_app.chat_rooms(user_id);
CREATE INDEX IF NOT EXISTS idx_chat_rooms_status ON gst_app.chat_rooms(status);

CREATE TABLE IF NOT EXISTS gst_app.chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL REFERENCES gst_app.chat_rooms(id) ON DELETE CASCADE,
    user_id UUID REFERENCES gst_app.users(id),
    content TEXT NOT NULL,
    message_type VARCHAR(20) NOT NULL DEFAULT 'text' CHECK (message_type IN ('text', 'image', 'file')),
    sender_type VARCHAR(20) NOT NULL DEFAULT 'user' CHECK (sender_type IN ('user', 'admin', 'ai')),
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_chat_messages_room_id ON gst_app.chat_messages(room_id);
