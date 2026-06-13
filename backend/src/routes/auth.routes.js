// backend/src/routes/auth.routes.js
const router = require('express').Router();
const { authenticate } = require('../middleware/auth');
const {
  login, getMe, logout, deleteAccount, devLogin,
  dbLogin, dbDemoLogin,
} = require('../controllers/auth.controller');

router.post('/login', login);
router.get('/me', authenticate, getMe);
router.post('/logout', authenticate, logout);
router.delete('/account', authenticate, deleteAccount);

// ⚠️  DEV ONLY — no-OTP shortcut
router.post('/dev-login', devLogin);

// ─── Custom username/password auth (no Firebase required) ──────────────────
router.post('/db-login', dbLogin);
router.post('/db-demo-login', dbDemoLogin);

module.exports = router;

