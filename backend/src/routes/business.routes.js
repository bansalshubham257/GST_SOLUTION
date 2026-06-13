// backend/src/routes/business.routes.js
const router = require('express').Router();
const { authenticate } = require('../middleware/auth');
const { getBusiness, setupBusiness, updateLogo, updateSettings } = require('../controllers/business.controller');

router.use(authenticate);
router.get('/', getBusiness);
router.post('/setup', setupBusiness);
router.patch('/logo', updateLogo);
router.patch('/settings', updateSettings);

module.exports = router;

