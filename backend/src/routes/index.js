// backend/src/routes/index.js

const router = require('express').Router();

const authRoutes = require('./auth.routes');
const businessRoutes = require('./business.routes');
const invoiceRoutes = require('./invoice.routes');
const customerRoutes = require('./customer.routes');
const productRoutes = require('./product.routes');
const gstRoutes = require('./gst.routes');
const dashboardRoutes = require('./dashboard.routes');
const chatRoutes = require('./chat.routes');
const adminRoutes = require('./admin.routes');
const uploadRoutes = require('./upload.routes');
const scanBillRoutes = require('./scan_bill.routes');

router.use('/auth', authRoutes);
router.use('/business', businessRoutes);
router.use('/invoices', invoiceRoutes);
router.use('/invoices/scan-bill', scanBillRoutes);
router.use('/customers', customerRoutes);
router.use('/products', productRoutes);
router.use('/gst', gstRoutes);
router.use('/dashboard', dashboardRoutes);
router.use('/chat', chatRoutes);
router.use('/admin', adminRoutes);
router.use('/upload', uploadRoutes);

module.exports = router;

