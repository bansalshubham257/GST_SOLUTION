// backend/src/routes/product.routes.js
const router = require('express').Router();
const { authenticate, requireBusiness } = require('../middleware/auth');
const { getProducts, createProduct, updateProduct, deleteProduct } = require('../controllers/product.controller');

router.use(authenticate, requireBusiness);
router.get('/', getProducts);
router.post('/', createProduct);
router.put('/:id', updateProduct);
router.delete('/:id', deleteProduct);

module.exports = router;

