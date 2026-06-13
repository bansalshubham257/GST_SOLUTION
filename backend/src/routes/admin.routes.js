// backend/src/routes/admin.routes.js
const router = require('express').Router();
const { authenticate, requireAdmin } = require('../middleware/auth');
const { getAdminStats, getUsers, getLogs, createUser } = require('../controllers/admin.controller');

// Create-user endpoint — protected by X-Admin-Key header, not Firebase
router.post('/create-user', createUser);

router.use(authenticate, requireAdmin);
router.get('/stats', getAdminStats);
router.get('/users', getUsers);
router.get('/logs', getLogs);

module.exports = router;

