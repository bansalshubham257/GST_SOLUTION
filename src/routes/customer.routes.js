// backend/src/routes/customer.routes.js
const router = require('express').Router();
const { authenticate, requireBusiness } = require('../middleware/auth');
const {
  getCustomers, getCustomerById, createCustomer, updateCustomer,
  deleteCustomer, getCustomerInvoices, getCustomerLedger,
} = require('../controllers/customer.controller');

router.use(authenticate, requireBusiness);
router.get('/', getCustomers);
router.post('/', createCustomer);
router.get('/:id', getCustomerById);
router.put('/:id', updateCustomer);
router.delete('/:id', deleteCustomer);
router.get('/:id/invoices', getCustomerInvoices);
router.get('/:id/ledger', getCustomerLedger);

module.exports = router;

