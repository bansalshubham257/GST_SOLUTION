// backend/src/routes/sync.routes.js
const router = require('express').Router();
const { authenticate, requireBusiness } = require('../middleware/auth');
const { syncAll } = require('../controllers/sync.controller');

router.post('/', authenticate, requireBusiness, syncAll);

module.exports = router;
