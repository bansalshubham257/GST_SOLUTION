// backend/src/routes/invoice.routes.js
const router = require('express').Router();
const { authenticate, requireBusiness } = require('../middleware/auth');
const {
  getInvoices, getInvoiceById, createInvoice, updateInvoice,
  cancelInvoice, duplicateInvoice, deleteInvoice,
} = require('../controllers/invoice.controller');

router.use(authenticate, requireBusiness);
router.get('/', getInvoices);
router.post('/', createInvoice);
router.get('/:id', getInvoiceById);
router.put('/:id', updateInvoice);
router.delete('/:id', deleteInvoice);
router.post('/:id/cancel', cancelInvoice);
router.post('/:id/duplicate', duplicateInvoice);

module.exports = router;

