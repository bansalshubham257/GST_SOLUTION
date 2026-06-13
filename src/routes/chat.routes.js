// backend/src/routes/chat.routes.js
const router = require('express').Router();
const { authenticate } = require('../middleware/auth');
const { getRooms, createRoom, getMessages, sendMessage, aiAssist } = require('../controllers/chat.controller');

router.use(authenticate);
router.get('/rooms', getRooms);
router.post('/rooms', createRoom);
router.get('/rooms/:id/messages', getMessages);
router.post('/rooms/:id/messages', sendMessage);
router.post('/ai-assist', aiAssist);

module.exports = router;

