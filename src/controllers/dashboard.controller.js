// backend/src/controllers/dashboard.controller.js

const { query } = require('../config/database');

/**
 * GET /dashboard/stats
 */
const getStats = async (req, res, next) => {
  try {
    const businessId = req.user.businessId;
    if (!businessId) return res.json({ totalSales: 0, totalGstCollected: 0, invoiceCount: 0, customerCount: 0, salesGrowth: 0 });

    const now = new Date();
    const currentMonth = now.getMonth() + 1;
    const currentYear = now.getFullYear();
    const prevMonth = currentMonth === 1 ? 12 : currentMonth - 1;
    const prevYear = currentMonth === 1 ? currentYear - 1 : currentYear;

    const [currentStats, prevStats, customerCount] = await Promise.all([
      query(
        `SELECT
           COALESCE(SUM(grand_total), 0) as total_sales,
           COALESCE(SUM(total_tax), 0) as total_gst,
           COUNT(*) as invoice_count
         FROM invoices
         WHERE business_id = $1 AND status != 'cancelled'
           AND EXTRACT(MONTH FROM invoice_date) = $2
           AND EXTRACT(YEAR FROM invoice_date) = $3`,
        [businessId, currentMonth, currentYear]
      ),
      query(
        `SELECT COALESCE(SUM(grand_total), 0) as total_sales
         FROM invoices
         WHERE business_id = $1 AND status != 'cancelled'
           AND EXTRACT(MONTH FROM invoice_date) = $2
           AND EXTRACT(YEAR FROM invoice_date) = $3`,
        [businessId, prevMonth, prevYear]
      ),
      query(
        'SELECT COUNT(*) FROM customers WHERE business_id = $1 AND is_active = true',
        [businessId]
      ),
    ]);

    const currentSales = parseFloat(currentStats.rows[0].total_sales);
    const prevSales = parseFloat(prevStats.rows[0].total_sales);
    const salesGrowth = prevSales > 0 ? ((currentSales - prevSales) / prevSales) * 100 : 0;

    res.json({
      totalSales: currentSales,
      totalGstCollected: parseFloat(currentStats.rows[0].total_gst),
      invoiceCount: parseInt(currentStats.rows[0].invoice_count),
      customerCount: parseInt(customerCount.rows[0].count),
      salesGrowth: Math.round(salesGrowth * 10) / 10,
      month: currentMonth,
      year: currentYear,
    });
  } catch (err) {
    next(err);
  }
};

/**
 * GET /dashboard/monthly-summary
 */
const getMonthlySummary = async (req, res, next) => {
  try {
    const businessId = req.user.businessId;
    if (!businessId) return res.json({ summary: [] });

    const result = await query(
      `SELECT
         EXTRACT(MONTH FROM invoice_date) as month,
         EXTRACT(YEAR FROM invoice_date) as year,
         COALESCE(SUM(grand_total), 0) as total_sales,
         COALESCE(SUM(total_tax), 0) as total_gst,
         COUNT(*) as invoice_count
       FROM invoices
       WHERE business_id = $1 AND status != 'cancelled'
         AND invoice_date >= NOW() - INTERVAL '12 months'
       GROUP BY EXTRACT(MONTH FROM invoice_date), EXTRACT(YEAR FROM invoice_date)
       ORDER BY year ASC, month ASC`,
      [businessId]
    );

    res.json({
      summary: result.rows.map((r) => ({
        month: parseInt(r.month),
        year: parseInt(r.year),
        totalSales: parseFloat(r.total_sales),
        totalGst: parseFloat(r.total_gst),
        invoiceCount: parseInt(r.invoice_count),
      })),
    });
  } catch (err) {
    next(err);
  }
};

/**
 * GET /dashboard/recent-invoices
 */
const getRecentInvoices = async (req, res, next) => {
  try {
    const result = await query(
      `SELECT id, invoice_number, customer_name, grand_total, status, invoice_date
       FROM invoices
       WHERE business_id = $1 AND status != 'cancelled'
       ORDER BY created_at DESC LIMIT 5`,
      [req.user.businessId]
    );
    res.json({ invoices: result.rows });
  } catch (err) {
    next(err);
  }
};

module.exports = { getStats, getMonthlySummary, getRecentInvoices };

