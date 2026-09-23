const { Server } = require('socket.io');

let io = null;

/**
 * Initialize Socket.IO with HTTP server
 * @param {import('http').Server} httpServer
 */
function initSocket(httpServer) {
  io = new Server(httpServer, {
    cors: {
      origin: '*',
      methods: ['GET', 'POST']
    }
  });

  io.on('connection', (socket) => {
    console.log(`[Socket.IO] Receiver/Client connected: ${socket.id}`);

    socket.on('disconnect', () => {
      console.log(`[Socket.IO] Client disconnected: ${socket.id}`);
    });
  });

  return io;
}

/**
 * Get the initialized Socket.IO instance
 */
function getIO() {
  return io;
}

/**
 * Broadcast updated location to all connected receivers
 * @param {{ latitude: number, longitude: number, accuracy: number, timestamp: string|Date }} locationData
 */
function emitLocationUpdated(locationData) {
  if (!io) {
    console.warn('[Socket.IO] Warning: emitLocationUpdated called before Socket.IO was initialized.');
    return;
  }

  const payload = {
    latitude: Number(locationData.latitude),
    longitude: Number(locationData.longitude),
    accuracy: Number(locationData.accuracy),
    timestamp: locationData.timestamp instanceof Date
      ? locationData.timestamp.toISOString()
      : new Date(locationData.timestamp).toISOString()
  };

  io.emit('locationUpdated', payload);
  console.log(`[Socket.IO] Broadcasted locationUpdated to ${io.engine.clientsCount} client(s):`, payload);
}

module.exports = {
  initSocket,
  getIO,
  emitLocationUpdated
};
