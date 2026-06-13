// backend/src/routes/dashboard.routes.js
const router = require('express').Router();
const { authenticate } = require('../middleware/auth');
const { getStats, getMonthlySummary, getRecentInvoices } = require('../controllers/dashboard.controller');

router.use(authenticate);
router.get('/stats', getStats);
router.get('/monthly-summary', getMonthlySummary);
router.get('/recent-invoices', getRecentInvoices);

module.exports = router;

