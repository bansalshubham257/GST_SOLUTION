const router = require('express').Router();
const { authenticate, requireBusiness } = require('../middleware/auth');
const {
  getPurchases, getPurchaseById, createPurchase, updatePurchase,
  cancelPurchase, duplicatePurchase, deletePurchase,
} = require('../controllers/purchase.controller');

router.use(authenticate, requireBusiness);
router.get('/', getPurchases);
router.post('/', createPurchase);
router.get('/:id', getPurchaseById);
router.put('/:id', updatePurchase);
router.delete('/:id', deletePurchase);
router.post('/:id/cancel', cancelPurchase);
router.post('/:id/duplicate', duplicatePurchase);

module.exports = router;
