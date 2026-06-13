// backend/src/controllers/chat.controller.js

const { query } = require('../config/database');
const { broadcastMessage } = require('../services/socketService');
const { AppError } = require('../middleware/errorHandler');
const { v4: uuidv4 } = require('uuid');

/**
 * GET /chat/rooms
 */
const getRooms = async (req, res, next) => {
  try {
    const result = await query(
      `SELECT cr.*, cm.content as last_message, cm.created_at as last_message_at,
              cm.sender_type as last_sender
       FROM chat_rooms cr
       LEFT JOIN LATERAL (
         SELECT content, created_at, sender_type FROM chat_messages
         WHERE room_id = cr.id ORDER BY created_at DESC LIMIT 1
       ) cm ON true
       WHERE cr.user_id = $1
       ORDER BY COALESCE(cm.created_at, cr.created_at) DESC`,
      [req.user.id]
    );

    res.json({ rooms: result.rows });
  } catch (err) {
    next(err);
  }
};

/**
 * POST /chat/rooms
 */
const createRoom = async (req, res, next) => {
  try {
    const { subject } = req.body;

    // Check if open room exists
    const existing = await query(
      `SELECT * FROM chat_rooms WHERE user_id = $1 AND status = 'open' ORDER BY created_at DESC LIMIT 1`,
      [req.user.id]
    );

    if (existing.rows[0]) {
      return res.json({ room: existing.rows[0] });
    }

    const result = await query(
      `INSERT INTO chat_rooms (user_id, business_id, subject, status, created_at, updated_at)
       VALUES ($1, $2, $3, 'open', NOW(), NOW())
       RETURNING *`,
      [req.user.id, req.user.businessId, subject || 'Support Request']
    );

    // Auto-greeting
    await query(
      `INSERT INTO chat_messages (room_id, content, sender_type, created_at)
       VALUES ($1, $2, 'bot', NOW())`,
      [result.rows[0].id, '👋 Hello! Welcome to GST Solution Support. How can we help you today?\n\nYou can ask about:\n• Invoice creation\n• GST calculations\n• GST returns\n• Account settings']
    );

    res.status(201).json({ room: result.rows[0] });
  } catch (err) {
    next(err);
  }
};

/**
 * GET /chat/rooms/:id/messages
 */
const getMessages = async (req, res, next) => {
  try {
    const { page = 1, limit = 50 } = req.query;
    const offset = (page - 1) * limit;

    const [room, messages] = await Promise.all([
      query('SELECT * FROM chat_rooms WHERE id = $1 AND user_id = $2', [req.params.id, req.user.id]),
      query(
        `SELECT * FROM chat_messages WHERE room_id = $1
         ORDER BY created_at DESC LIMIT $2 OFFSET $3`,
        [req.params.id, limit, offset]
      ),
    ]);

    if (!room.rows[0]) throw new AppError('Chat room not found', 404, 'NOT_FOUND');

    res.json({ messages: messages.rows.reverse(), room: room.rows[0] });
  } catch (err) {
    next(err);
  }
};

/**
 * POST /chat/rooms/:id/messages
 */
const sendMessage = async (req, res, next) => {
  try {
    const { content, messageType = 'text' } = req.body;
    if (!content?.trim()) return res.status(400).json({ error: 'Message content required' });

    const room = await query('SELECT * FROM chat_rooms WHERE id = $1 AND user_id = $2', [req.params.id, req.user.id]);
    if (!room.rows[0]) throw new AppError('Chat room not found', 404, 'NOT_FOUND');

    const message = await query(
      `INSERT INTO chat_messages (room_id, user_id, content, message_type, sender_type, created_at)
       VALUES ($1, $2, $3, $4, 'user', NOW())
       RETURNING *`,
      [req.params.id, req.user.id, content.trim(), messageType]
    );

    const newMessage = message.rows[0];

    // Broadcast via Socket.IO
    broadcastMessage(req.params.id, newMessage);

    // Update room timestamp
    await query('UPDATE chat_rooms SET updated_at = NOW() WHERE id = $1', [req.params.id]);

    // Simple AI auto-reply for common queries
    const aiReply = getAiAutoReply(content.toLowerCase());
    if (aiReply) {
      setTimeout(async () => {
        const botMsg = await query(
          `INSERT INTO chat_messages (room_id, content, sender_type, created_at)
           VALUES ($1, $2, 'bot', NOW()) RETURNING *`,
          [req.params.id, aiReply]
        );
        broadcastMessage(req.params.id, botMsg.rows[0]);
      }, 1500);
    }

    res.status(201).json({ message: newMessage });
  } catch (err) {
    next(err);
  }
};

/**
 * POST /chat/ai-assist
 */
const aiAssist = async (req, res, next) => {
  try {
    const { query: userQuery } = req.body;
    const reply = getAiAutoReply(userQuery?.toLowerCase() || '');
    res.json({
      reply: reply || 'I\'ll connect you with our support team for this query. Please wait.',
      handoffRequired: !reply,
    });
  } catch (err) {
    next(err);
  }
};

const getAiAutoReply = (content) => {
  const replies = {
    invoice: '📄 To create an invoice:\n1. Go to Invoices tab\n2. Tap "New Invoice"\n3. Add customer & items\n4. GST is auto-calculated\n5. Tap "Create Invoice"',
    gstin: '🔍 GSTIN is a 15-character alphanumeric code. Format: 2 digits (state) + 10 PAN chars + 1 + Z + 1 check digit\nExample: 27AABCU9603R1ZX',
    gst: '📊 Our platform auto-calculates:\n• CGST + SGST for intra-state sales\n• IGST for inter-state sales\nGST rates: 0%, 5%, 12%, 18%, 28%',
    'gstr-1': 'GSTR-1 is the monthly/quarterly return for outward supplies. Go to GST Reports → GSTR-1 Draft to view and export.',
    'gstr-3b': 'GSTR-3B is the monthly summary return. Go to GST Reports → GSTR-3B Draft to view the summary.',
    pdf: '🖨️ To download invoice PDF:\n1. Open the invoice\n2. Tap the download icon\n3. PDF will be saved to your device',
    customer: '👤 To add a customer:\n1. Go to Customers tab\n2. Tap "Add Customer"\n3. Fill in details\n4. Customer GSTIN is optional but recommended',
    report: '📈 GST Reports available:\n• Sales Register\n• GST Summary\n• Tax Liability\n• GSTR-1 Draft\n• GSTR-3B Draft\n\nExport as PDF, Excel, or JSON',
  };

  for (const [key, reply] of Object.entries(replies)) {
    if (content.includes(key)) return reply;
  }
  return null;
};

module.exports = { getRooms, createRoom, getMessages, sendMessage, aiAssist };

