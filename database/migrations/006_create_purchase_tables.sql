CREATE TABLE IF NOT EXISTS gst_app.purchase_invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES gst_app.businesses(id) ON DELETE CASCADE,
    purchase_number VARCHAR(50) NOT NULL,
    supplier_name VARCHAR(255) NOT NULL DEFAULT '',
    supplier_gstin VARCHAR(20) DEFAULT '',
    supplier_phone VARCHAR(20) DEFAULT '',
    supplier_email VARCHAR(255) DEFAULT '',
    supplier_address TEXT DEFAULT '',
    invoice_date DATE NOT NULL DEFAULT CURRENT_DATE,
    due_date DATE,
    status VARCHAR(20) NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'paid', 'cancelled', 'overdue')),
    payment_status VARCHAR(20) NOT NULL DEFAULT 'unpaid' CHECK (payment_status IN ('paid', 'unpaid', 'partial')),
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

CREATE INDEX IF NOT EXISTS idx_purchase_invoices_business_id ON gst_app.purchase_invoices(business_id);
CREATE INDEX IF NOT EXISTS idx_purchase_invoices_status ON gst_app.purchase_invoices(status);
CREATE INDEX IF NOT EXISTS idx_purchase_invoices_date ON gst_app.purchase_invoices(invoice_date);
CREATE INDEX IF NOT EXISTS idx_purchase_invoices_number ON gst_app.purchase_invoices(business_id, purchase_number);

CREATE TABLE IF NOT EXISTS gst_app.purchase_invoice_line_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    purchase_invoice_id UUID NOT NULL REFERENCES gst_app.purchase_invoices(id) ON DELETE CASCADE,
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

CREATE INDEX IF NOT EXISTS idx_purchase_line_items_invoice_id ON gst_app.purchase_invoice_line_items(purchase_invoice_id);
