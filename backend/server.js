// backend/server.js

require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const morgan = require('morgan');
const http = require('http');
const { Server } = require('socket.io');
const rateLimit = require('express-rate-limit');

const { initDB } = require('./src/config/database');
const { initFirebase } = require('./src/config/firebase');
const routes = require('./src/routes');
const { errorHandler, notFoundHandler } = require('./src/middleware/errorHandler');
const logger = require('./src/utils/logger');
const { initSocketIO } = require('./src/services/socketService');

const app = express();
const httpServer = http.createServer(app);
const io = new Server(httpServer, {
  cors: {
    origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000', 'http://10.0.2.2:3000'],
    methods: ['GET', 'POST'],
  },
});

const PORT = process.env.PORT || 5000;

// ─── Middleware ─────────────────────────────────────────────────────────────

// Security
app.use(helmet());

// CORS
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || '*',
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true,
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 300,
  message: { error: 'Too many requests, please try again later.' },
});
app.use('/api/', limiter);

// Body parsing
app.use(compression());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Logging
app.use(morgan('combined', {
  stream: { write: (message) => logger.info(message.trim()) },
}));

// Request ID
app.use((req, _, next) => {
  req.requestId = require('uuid').v4();
  next();
});

// ─── Health Check ──────────────────────────────────────────────────────────

app.get('/health', (_, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    version: '1.0.0',
    service: 'GST Solution API',
  });
});

// ─── API Routes ───────────────────────────────────────────────────────────

app.use('/api/v1', routes);

// ─── Error Handling ───────────────────────────────────────────────────────

app.use(notFoundHandler);
app.use(errorHandler);

// ─── Socket.IO ────────────────────────────────────────────────────────────

initSocketIO(io);

// ─── Start Server ─────────────────────────────────────────────────────────

async function start() {
  try {
    // Initialize database
    await initDB();
    logger.info('✅ Database connected');

    // Initialize Firebase Admin
    initFirebase();
    logger.info('✅ Firebase initialized');

    httpServer.listen(PORT, () => {
      logger.info(`🚀 GST Solution API running on port ${PORT}`);
      logger.info(`📊 Environment: ${process.env.NODE_ENV || 'development'}`);
    });
  } catch (error) {
    logger.error('Failed to start server:', error);
    process.exit(1);
  }
}

start();

module.exports = { app, io };

