// backend/src/routes/sync.routes.js
const router = require('express').Router();
const { authenticate } = require('../middleware/auth');
const { syncAll } = require('../controllers/sync.controller');

router.post('/', authenticate, syncAll);

module.exports = router;
