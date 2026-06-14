// backend/src/controllers/sync.controller.js

const { v4: uuidv4 } = require('uuid');
const { query, transaction } = require('../config/database');
const logger = require('../utils/logger');

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function validUuid(val) {
  return typeof val === 'string' && UUID_RE.test(val);
}

/**
 * POST /sync
 * Upserts all local data to DB for db_paid plan users.
 * Accepts arrays of customers, products, invoices (with line items).
 */
const syncAll = async (req, res, next) => {
  const userId = req.user.id;

  // Find or create a business for this user
  let businessId = req.user.businessId || null;
  const { customers, products, invoices, business, staff, purchases } = req.body;
  const results = { customers: 0, products: 0, invoices: 0, staff: 0, purchases: 0, errors: [] };

  try {
    await transaction(async (client) => {
      // Look up or create business
      if (!businessId) {
        const bizResult = await client.query(
          'SELECT id FROM gst_app.businesses WHERE user_id = $1 AND is_active = true LIMIT 1',
          [userId]
        );
        if (bizResult.rows.length > 0) {
          businessId = bizResult.rows[0].id;
        } else if (business) {
          const newBiz = await client.query(
            `INSERT INTO gst_app.businesses (id, user_id, name, business_type, state, is_active)
             VALUES (gen_random_uuid(), $1, $2, $3, $4, true)
             RETURNING id`,
            [userId, business.name || 'My Business', business.business_type || business.businessType || 'retail', business.state || '']
          );
          businessId = newBiz.rows[0].id;
        } else {
          return; // no business to sync to
        }
      }

      // Update business details if provided
      if (business) {
        const BUSINESS_KEY_MAP = {
          'businessType': 'business_type',
          'logoUrl': 'logo_url',
        };
        const VALID_BUSINESS_COLUMNS = new Set([
          'name', 'gstin', 'pan', 'phone', 'email', 'address', 'city', 'state',
          'state_code', 'pincode', 'business_type', 'registration_type', 'logo_url',
          'invoice_prefix', 'bank_name', 'bank_account', 'bank_ifsc', 'bank_branch',
          'terms_and_conditions', 'signature_url', 'default_notes'
        ]);
        const fields = [];
        const values = [];
        let idx = 1;
        for (const [key, val] of Object.entries(business)) {
          if (['id', 'user_id', 'created_at', 'updated_at', 'is_active', 'setupDone'].includes(key)) continue;
          const dbKey = BUSINESS_KEY_MAP[key] || key;
          if (!VALID_BUSINESS_COLUMNS.has(dbKey)) continue;
          fields.push(`${dbKey} = $${idx++}`);
          values.push(val);
        }
        if (fields.length > 0) {
          values.push(businessId);
          await client.query(
            `UPDATE gst_app.businesses SET ${fields.join(', ')}, updated_at = NOW() WHERE id = $${idx}`,
            values
          );
        }
      }

      // Upsert customers
      if (Array.isArray(customers)) {
        for (const c of customers) {
          try {
            await client.query('SAVEPOINT sp');
            const cid = validUuid(c.id) ? c.id : null;
            const existing = cid ? await client.query('SELECT id FROM gst_app.customers WHERE id = $1', [cid]) : { rows: [] };
            if (existing.rows.length > 0) {
              await client.query(
                `UPDATE gst_app.customers SET name=$1,gstin=$2,pan=$3,phone=$4,email=$5,
                 address=$6,city=$7,state=$8,state_code=$9,pincode=$10,notes=$11,
                 invoice_count=COALESCE($12,invoice_count),total_business=COALESCE($13,total_business),
                 updated_at=NOW() WHERE id=$14`,
                [c.name, c.gstin||'', c.pan||'', c.phone||'', c.email||'',
                 c.address||'', c.city||'', c.state||'', c.state_code||'', c.pincode||'', c.notes||'',
                 c.invoice_count, c.total_business, cid]
              );
            } else {
              await client.query(
                `INSERT INTO gst_app.customers (id,business_id,name,gstin,pan,phone,email,address,city,state,state_code,pincode,notes,invoice_count,total_business)
                 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15)`,
                [cid||uuidv4(), businessId, c.name, c.gstin||'', c.pan||'', c.phone||'', c.email||'',
                 c.address||'', c.city||'', c.state||'', c.state_code||'', c.pincode||'', c.notes||'',
                 c.invoice_count||0, c.total_business||0]
              );
            }
            await client.query('RELEASE SAVEPOINT sp');
            results.customers++;
          } catch (err) {
            await client.query('ROLLBACK TO SAVEPOINT sp');
            results.errors.push({ type: 'customer', id: c.id, error: err.message });
          }
        }
      }

      // Upsert products
      if (Array.isArray(products)) {
        for (const p of products) {
          try {
            await client.query('SAVEPOINT sp');
            const pid = validUuid(p.id) ? p.id : null;
            const existing = pid ? await client.query('SELECT id FROM gst_app.products WHERE id = $1', [pid]) : { rows: [] };
            if (existing.rows.length > 0) {
              await client.query(
                `UPDATE gst_app.products SET name=$1,description=$2,hsn_sac_code=$3,is_service=$4,
                 unit_price=$5,unit=$6,gst_rate=$7,updated_at=NOW() WHERE id=$8`,
                [p.name, p.description||'', p.hsn_sac_code||'', p.is_service||false,
                 p.unit_price||0, p.unit||'nos', p.gst_rate||0, pid]
              );
            } else {
              await client.query(
                `INSERT INTO gst_app.products (id,business_id,name,description,hsn_sac_code,is_service,unit_price,unit,gst_rate)
                 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
                [pid||uuidv4(), businessId, p.name, p.description||'', p.hsn_sac_code||'',
                 p.is_service||false, p.unit_price||0, p.unit||'nos', p.gst_rate||0]
              );
            }
            await client.query('RELEASE SAVEPOINT sp');
            results.products++;
          } catch (err) {
            await client.query('ROLLBACK TO SAVEPOINT sp');
            results.errors.push({ type: 'product', id: p.id, error: err.message });
          }
        }
      }

      // Upsert invoices + line items
      if (Array.isArray(invoices)) {
        for (const inv of invoices) {
          try {
            await client.query('SAVEPOINT sp');
            let invId = validUuid(inv.id) ? inv.id : null;
            const customerId = validUuid(inv.customer_id) ? inv.customer_id : null;
            const lineItems = inv.line_items || inv.lineItems || [];
            const existing = invId ? await client.query('SELECT id FROM gst_app.invoices WHERE id = $1', [invId]) : { rows: [] };
            if (existing.rows.length > 0) {
              await client.query(
                `UPDATE gst_app.invoices SET invoice_number=$1,customer_id=$2,customer_name=$3,
                 customer_gstin=$4,customer_phone=$5,customer_email=$6,customer_address=$7,
                 customer_state=$8,invoice_date=$9,due_date=$10,status=$11,is_inter_state=$12,
                 sub_total=$13,total_cgst=$14,total_sgst=$15,total_igst=$16,total_cess=$17,
                 total_tax=$18,discount_amount=$19,grand_total=$20,round_off=$21,notes=$22,
                 terms_and_conditions=$23,gst_slabs=$24,updated_at=NOW() WHERE id=$25`,
                [inv.invoice_number, customerId, inv.customer_name||'',
                 inv.customer_gstin||'', inv.customer_phone||'', inv.customer_email||'', inv.customer_address||'',
                 inv.customer_state||'', inv.invoice_date, inv.due_date, inv.status||'draft',
                 inv.is_inter_state||false, inv.sub_total||0, inv.total_cgst||0, inv.total_sgst||0,
                 inv.total_igst||0, inv.total_cess||0, inv.total_tax||0, inv.discount_amount||0,
                 inv.grand_total||0, inv.round_off||0, inv.notes||'', inv.terms_and_conditions||'',
                 JSON.stringify(inv.gst_slabs||[]), invId]
              );
              if (lineItems.length > 0) {
                await client.query('DELETE FROM gst_app.invoice_line_items WHERE invoice_id = $1', [invId]);
              }
            } else {
              const result = await client.query(
                `INSERT INTO gst_app.invoices (id,business_id,invoice_number,customer_id,customer_name,
                 customer_gstin,customer_phone,customer_email,customer_address,customer_state,
                 invoice_date,due_date,status,is_inter_state,sub_total,total_cgst,total_sgst,total_igst,
                 total_cess,total_tax,discount_amount,grand_total,round_off,notes,terms_and_conditions,gst_slabs)
                 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22,$23,$24,$25,$26)
                 RETURNING id`,
                [invId||uuidv4(), businessId, inv.invoice_number, customerId, inv.customer_name||'',
                 inv.customer_gstin||'', inv.customer_phone||'', inv.customer_email||'', inv.customer_address||'',
                 inv.customer_state||'', inv.invoice_date, inv.due_date, inv.status||'draft',
                 inv.is_inter_state||false, inv.sub_total||0, inv.total_cgst||0, inv.total_sgst||0,
                 inv.total_igst||0, inv.total_cess||0, inv.total_tax||0, inv.discount_amount||0,
                 inv.grand_total||0, inv.round_off||0, inv.notes||'', inv.terms_and_conditions||'',
                 JSON.stringify(inv.gst_slabs||[])]
              );
              invId = result.rows[0].id;
            }

            // Upsert line items
            for (const li of lineItems) {
              await client.query(
                `INSERT INTO gst_app.invoice_line_items (id,invoice_id,description,hsn_sac_code,is_service,
                 quantity,unit,unit_price,discount_percent,discount_amount,taxable_amount,gst_rate,
                 cgst,sgst,igst,cess,total_amount,sort_order)
                 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18)
                 ON CONFLICT (id) DO UPDATE SET description=EXCLUDED.description,quantity=EXCLUDED.quantity,
                 unit_price=EXCLUDED.unit_price,taxable_amount=EXCLUDED.taxable_amount,total_amount=EXCLUDED.total_amount`,
                [li.id||uuidv4(), invId, li.description, li.hsn_sac_code||'', li.is_service||false,
                 li.quantity||1, li.unit||'nos', li.unit_price||0, li.discount_percent||0, li.discount_amount||0,
                 li.taxable_amount||0, li.gst_rate||0, li.cgst||0, li.sgst||0, li.igst||0, li.cess||0,
                 li.total_amount||0, li.sort_order||0]
              );
            }
            await client.query('RELEASE SAVEPOINT sp');
            results.invoices++;
          } catch (err) {
            await client.query('ROLLBACK TO SAVEPOINT sp');
            results.errors.push({ type: 'invoice', id: inv.id, error: err.message });
          }
        }
      }

      // Upsert purchases + line items
      if (Array.isArray(purchases)) {
        for (const inv of purchases) {
          try {
            await client.query('SAVEPOINT sp');
            let invId = validUuid(inv.id) ? inv.id : null;
            const lineItems = inv.line_items || inv.lineItems || [];
            const existing = invId ? await client.query('SELECT id FROM gst_app.purchase_invoices WHERE id = $1', [invId]) : { rows: [] };
            if (existing.rows.length > 0) {
              await client.query(
                `UPDATE gst_app.purchase_invoices SET purchase_number=$1,supplier_name=$2,
                 supplier_gstin=$3,supplier_phone=$4,supplier_email=$5,supplier_address=$6,
                 invoice_date=$7,due_date=$8,status=$9,payment_status=$10,is_inter_state=$11,
                 sub_total=$12,total_cgst=$13,total_sgst=$14,total_igst=$15,total_cess=$16,
                 total_tax=$17,discount_amount=$18,grand_total=$19,round_off=$20,notes=$21,
                 terms_and_conditions=$22,gst_slabs=$23,updated_at=NOW() WHERE id=$24`,
                [inv.purchase_number||inv.purchaseNumber, inv.supplier_name||inv.supplierName||'',
                 inv.supplier_gstin||'', inv.supplier_phone||'', inv.supplier_email||'', inv.supplier_address||'',
                 inv.invoice_date, inv.due_date, inv.status||'draft', inv.payment_status||'unpaid',
                 inv.is_inter_state||false, inv.sub_total||0, inv.total_cgst||0, inv.total_sgst||0,
                 inv.total_igst||0, inv.total_cess||0, inv.total_tax||0, inv.discount_amount||0,
                 inv.grand_total||0, inv.round_off||0, inv.notes||'', inv.terms_and_conditions||'',
                 JSON.stringify(inv.gst_slabs||[]), invId]
              );
              if (lineItems.length > 0) {
                await client.query('DELETE FROM gst_app.purchase_invoice_line_items WHERE purchase_invoice_id = $1', [invId]);
              }
            } else {
              const result = await client.query(
                `INSERT INTO gst_app.purchase_invoices (id,business_id,purchase_number,supplier_name,
                 supplier_gstin,supplier_phone,supplier_email,supplier_address,
                 invoice_date,due_date,status,payment_status,is_inter_state,sub_total,total_cgst,total_sgst,total_igst,
                 total_cess,total_tax,discount_amount,grand_total,round_off,notes,terms_and_conditions,gst_slabs)
                 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22,$23,$24,$25)
                 RETURNING id`,
                [invId||uuidv4(), businessId, inv.purchase_number||inv.purchaseNumber||'',
                 inv.supplier_name||inv.supplierName||'', inv.supplier_gstin||'', inv.supplier_phone||'',
                 inv.supplier_email||'', inv.supplier_address||'', inv.invoice_date, inv.due_date,
                 inv.status||'draft', inv.payment_status||'unpaid', inv.is_inter_state||false,
                 inv.sub_total||0, inv.total_cgst||0, inv.total_sgst||0, inv.total_igst||0,
                 inv.total_cess||0, inv.total_tax||0, inv.discount_amount||0,
                 inv.grand_total||0, inv.round_off||0, inv.notes||'', inv.terms_and_conditions||'',
                 JSON.stringify(inv.gst_slabs||[])]
              );
              invId = result.rows[0].id;
            }

            for (const li of lineItems) {
              await client.query(
                `INSERT INTO gst_app.purchase_invoice_line_items (id,purchase_invoice_id,description,hsn_sac_code,is_service,
                 quantity,unit,unit_price,discount_percent,discount_amount,taxable_amount,gst_rate,
                 cgst,sgst,igst,cess,total_amount,sort_order)
                 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18)
                 ON CONFLICT (id) DO UPDATE SET description=EXCLUDED.description,quantity=EXCLUDED.quantity,
                 unit_price=EXCLUDED.unit_price,taxable_amount=EXCLUDED.taxable_amount,total_amount=EXCLUDED.total_amount`,
                [li.id||uuidv4(), invId, li.description, li.hsn_sac_code||'', li.is_service||false,
                 li.quantity||1, li.unit||'nos', li.unit_price||0, li.discount_percent||0, li.discount_amount||0,
                 li.taxable_amount||0, li.gst_rate||0, li.cgst||0, li.sgst||0, li.igst||0, li.cess||0,
                 li.total_amount||0, li.sort_order||0]
              );
            }
            await client.query('RELEASE SAVEPOINT sp');
            results.purchases++;
          } catch (err) {
            await client.query('ROLLBACK TO SAVEPOINT sp');
            results.errors.push({ type: 'purchase', id: inv.id, error: err.message });
          }
        }
      }

      // Upsert staff
      if (Array.isArray(staff)) {
        for (const s of staff) {
          try {
            await client.query('SAVEPOINT sp');
            const sid = validUuid(s.id) ? s.id : null;
            const existing = sid ? await client.query('SELECT id FROM gst_app.staff WHERE id = $1', [sid]) : { rows: [] };
            if (existing.rows.length > 0) {
              await client.query(
                `UPDATE gst_app.staff SET name=$1,role=$2,phone=$3,commission_percentage=$4,
                 total_revenue=COALESCE($5,total_revenue),total_commission=COALESCE($6,total_commission),
                 updated_at=NOW() WHERE id=$7`,
                [s.name, s.role||'', s.phone||'', s.commission_percentage||0,
                 s.total_revenue||0, s.total_commission||0, sid]
              );
            } else {
              await client.query(
                `INSERT INTO gst_app.staff (id,business_id,name,role,phone,commission_percentage,total_revenue,total_commission)
                 VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
                [sid||uuidv4(), businessId, s.name, s.role||'', s.phone||'',
                 s.commission_percentage||0, s.total_revenue||0, s.total_commission||0]
              );
            }
            await client.query('RELEASE SAVEPOINT sp');
            results.staff++;
          } catch (err) {
            await client.query('ROLLBACK TO SAVEPOINT sp');
            results.errors.push({ type: 'staff', id: s.id, error: err.message });
          }
        }
      }
    });

    // After a successful push, return all business data so the client can
    // populate its local cache (e.g. after clear-data + login).
    let pulledData = null;
    if (businessId) {
      const [custRows, prodRows, invRows, staffRows, invLineRows, purRows, purLineRows] = await Promise.all([
        query('SELECT * FROM gst_app.customers WHERE business_id = $1 ORDER BY name', [businessId]),
        query('SELECT * FROM gst_app.products WHERE business_id = $1 ORDER BY name', [businessId]),
        query('SELECT * FROM gst_app.invoices WHERE business_id = $1 ORDER BY created_at DESC', [businessId]),
        query('SELECT * FROM gst_app.staff WHERE business_id = $1 ORDER BY name', [businessId]),
        query(`SELECT li.* FROM gst_app.invoice_line_items li
               JOIN gst_app.invoices i ON i.id = li.invoice_id
               WHERE i.business_id = $1 ORDER BY li.sort_order`, [businessId]),
        query('SELECT * FROM gst_app.purchase_invoices WHERE business_id = $1 ORDER BY created_at DESC', [businessId]),
        query(`SELECT li.* FROM gst_app.purchase_invoice_line_items li
               JOIN gst_app.purchase_invoices i ON i.id = li.purchase_invoice_id
               WHERE i.business_id = $1 ORDER BY li.sort_order`, [businessId]),
      ]);

      const lineMap = {};
      for (const li of invLineRows.rows) {
        if (!lineMap[li.invoice_id]) lineMap[li.invoice_id] = [];
        lineMap[li.invoice_id].push(li);
      }

      const purLineMap = {};
      for (const li of purLineRows.rows) {
        if (!purLineMap[li.purchase_invoice_id]) purLineMap[li.purchase_invoice_id] = [];
        purLineMap[li.purchase_invoice_id].push(li);
      }

      pulledData = {
        customers: custRows.rows.map(r => toCamel(r)),
        products: prodRows.rows.map(r => toCamel(r)),
        invoices: invRows.rows.map(r => ({ ...toCamel(r), lineItems: (lineMap[r.id] || []).map(li => toCamel(li)) })),
        staff: staffRows.rows.map(r => toCamel(r)),
        purchases: purRows.rows.map(r => ({ ...toCamel(r), lineItems: (purLineMap[r.id] || []).map(li => toCamel(li)) })),
      };
    }

    res.json({ success: true, ...results, data: pulledData });
  } catch (err) {
    next(err);
  }
};

// ─── Helpers ───────────────────────────────────────────────────────────────

const NUMERIC_COLS = new Set([
  'sub_total', 'total_cgst', 'total_sgst', 'total_igst', 'total_cess', 'total_tax',
  'discount_amount', 'grand_total', 'round_off', 'unit_price', 'gst_rate',
  'stock', 'quantity', 'discount_percent', 'taxable_amount', 'cgst', 'sgst',
  'igst', 'cess', 'total_amount', 'sort_order', 'commission_percentage',
  'total_revenue', 'total_commission', 'invoice_count', 'total_business',
]);

function toCamel(row) {
  const out = {};
  for (const key of Object.keys(row)) {
    const camel = key.replace(/_([a-z])/g, (_, c) => c.toUpperCase());
    let val = row[key];
    if (typeof val === 'string' && NUMERIC_COLS.has(key)) {
      val = parseFloat(val);
    }
    out[camel] = val;
  }
  return out;
}

module.exports = { syncAll };
