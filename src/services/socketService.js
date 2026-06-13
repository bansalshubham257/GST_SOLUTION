// backend/src/services/socketService.js

const logger = require('../utils/logger');

let io;

const initSocketIO = (socketIo) => {
  io = socketIo;

  io.on('connection', (socket) => {
    logger.info(`Client connected: ${socket.id}`);

    // Join a room based on user/business ID
    socket.on('join', ({ userId, businessId }) => {
      if (userId) socket.join(`user:${userId}`);
      if (businessId) socket.join(`business:${businessId}`);
      logger.info(`Socket ${socket.id} joined rooms: user:${userId}, business:${businessId}`);
    });

    // Join chat room
    socket.on('join_chat', ({ roomId }) => {
      socket.join(`chat:${roomId}`);
    });

    // Leave chat room
    socket.on('leave_chat', ({ roomId }) => {
      socket.leave(`chat:${roomId}`);
    });

    // Typing indicator
    socket.on('typing', ({ roomId, userId }) => {
      socket.to(`chat:${roomId}`).emit('user_typing', { userId });
    });

    socket.on('stop_typing', ({ roomId, userId }) => {
      socket.to(`chat:${roomId}`).emit('user_stopped_typing', { userId });
    });

    socket.on('disconnect', () => {
      logger.info(`Client disconnected: ${socket.id}`);
    });
  });
};

// Emit to a specific user
const emitToUser = (userId, event, data) => {
  if (!io) return;
  io.to(`user:${userId}`).emit(event, data);
};

// Emit to a business room
const emitToBusiness = (businessId, event, data) => {
  if (!io) return;
  io.to(`business:${businessId}`).emit(event, data);
};

// Emit to a chat room
const emitToChat = (roomId, event, data) => {
  if (!io) return;
  io.to(`chat:${roomId}`).emit(event, data);
};

// Broadcast new message to chat room
const broadcastMessage = (roomId, message) => {
  emitToChat(roomId, 'new_message', message);
};

module.exports = { initSocketIO, emitToUser, emitToBusiness, emitToChat, broadcastMessage, getIo: () => io };

