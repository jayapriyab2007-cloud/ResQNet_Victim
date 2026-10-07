const { Server } = require('socket.io');

let io = null;

const initSocket = (server, allowedOrigins = ['http://localhost:3000', 'http://localhost:5173']) => {
  io = new Server(server, {
    cors: {
      origin: allowedOrigins,
      methods: ['GET', 'POST', 'PATCH', 'PUT', 'DELETE'],
      credentials: true
    }
  });

  io.on('connection', (socket) => {
    // Client joins rooms based on role or id
    socket.on('join', (data) => {
      try {
        if (!data) return;
        const { role, userId, emergencyId } = data;

        if (role === 'ADMIN') {
          socket.join('admins');
        } else if (role === 'RESPONDER') {
          socket.join('responders');
        }

        if (userId) {
          socket.join(`user_${userId}`);
        }

        if (emergencyId) {
          socket.join(`emergency_${emergencyId}`);
        }
      } catch (err) {
        console.error('Socket join error:', err.message);
      }
    });

    socket.on('disconnect', () => {
      // Clean disconnect
    });
  });

  return io;
};

const init = initSocket;
const getIO = () => io;

const broadcastNewEmergency = (emergency) => {
  if (!io) return;
  io.emit('new_emergency', emergency);
};

const broadcastEmergencyAssigned = (emergency, responderId) => {
  if (!io) return;
  io.emit('emergency_assigned', { emergency, responder_id: responderId });
};

const broadcastEmergencyUpdated = (emergency) => {
  if (!io) return;
  io.emit('emergency_updated', emergency);
};

const broadcastEmergencyStatusChanged = (payload) => {
  if (!io) return;
  io.emit('emergency_status_changed', payload);
};

const broadcastResponderLocation = (payload) => {
  if (!io) return;
  io.emit('responder_location_updated', payload);
};

const broadcastResponderStatus = (payload) => {
  if (!io) return;
  io.emit('responder_status_updated', payload);
};

const broadcastNotification = (notification) => {
  if (!io) return;
  if (notification.user_id) {
    io.to(`user_${notification.user_id}`).emit('notification_created', notification);
  }
  io.to('admins').emit('notification_created', notification);
};

const broadcastMessage = (message) => {
  if (!io) return;
  io.emit('message_received', message);
};

// Aliases for route handlers
const emitNewEmergency = broadcastNewEmergency;
const emitEmergencyAssigned = broadcastEmergencyAssigned;
const emitEmergencyUpdated = broadcastEmergencyUpdated;
const emitEmergencyStatusChanged = broadcastEmergencyStatusChanged;
const emitResponderLocation = (responderId, latitude, longitude) => {
  broadcastResponderLocation({
    responder_id: responderId,
    latitude,
    longitude,
    timestamp: new Date()
  });
};
const emitResponderStatus = (responderId, availability) => {
  broadcastResponderStatus({
    responder_id: responderId,
    availability,
    timestamp: new Date()
  });
};
const emitNotification = broadcastNotification;
const emitChatMessage = broadcastMessage;

module.exports = {
  init,
  initSocket,
  getIO,
  broadcastNewEmergency,
  broadcastEmergencyAssigned,
  broadcastEmergencyUpdated,
  broadcastEmergencyStatusChanged,
  broadcastResponderLocation,
  broadcastResponderStatus,
  broadcastNotification,
  broadcastMessage,
  // Helper aliases
  emitNewEmergency,
  emitEmergencyAssigned,
  emitEmergencyUpdated,
  emitEmergencyStatusChanged,
  emitResponderLocation,
  emitResponderStatus,
  emitNotification,
  emitChatMessage
};
