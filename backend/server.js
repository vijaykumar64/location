const express = require('express');
const http = require('http');
const mongoose = require('mongoose');
const cors = require('cors');
const helmet = require('helmet');
require('dotenv').config();

const socketService = require('./services/socketService');
const locationRoutes = require('./routes/locationRoutes');

// Disable buffering so database operations fail quickly when offline
mongoose.set('bufferCommands', false);

const app = express();
const server = http.createServer(app);

// Initialize Socket.IO
socketService.initSocket(server);

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json());

// Request logger
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
  next();
});

// Health check endpoint
app.get('/api/health', (req, res) => {
  const mongoStatus = mongoose.connection.readyState === 1 ? 'connected' : 'disconnected';
  res.json({
    status: 'ok',
    service: 'location-sharing-backend',
    database: mongoStatus,
    timestamp: new Date().toISOString()
  });
});

// API Routes
app.use('/api', locationRoutes);

// Environment variables
const PORT = process.env.PORT || 5000;
const MONGODB_URI = process.env.MONGODB_URI;

// Connect to MongoDB Atlas (if URI provided)
let isConnecting = false;

const connectWithRetry = () => {
  if (!MONGODB_URI) {
    console.log('[MongoDB] Notice: MONGODB_URI is not set in .env. Server will run with resilient in-memory storage.');
    return;
  }

  if (mongoose.connection.readyState === 1 || isConnecting) return;
  isConnecting = true;
  console.log('[MongoDB] Attempting to connect to MongoDB Atlas...');

  mongoose
    .connect(MONGODB_URI, {
      serverSelectionTimeoutMS: 5000,
    })
    .then(() => {
      isConnecting = false;
      console.log('[MongoDB] Successfully connected to MongoDB Atlas.');
    })
    .catch((err) => {
      isConnecting = false;
      console.error('[MongoDB] Connection error:', err.message);
      console.log('[MongoDB] NOTE: If using MongoDB Atlas, check your IP whitelist:');
      console.log('          Atlas Dashboard -> Network Access -> Add IP Address -> Allow Access from Anywhere (0.0.0.0/0)');
      console.log('[MongoDB] Retrying connection in 15 seconds (server running in in-memory mode)...');
      setTimeout(connectWithRetry, 15000);
    });
};

mongoose.connection.on('disconnected', () => {
  console.warn('[MongoDB] Connection lost. Scheduling reconnect in 10s...');
  setTimeout(connectWithRetry, 10000);
});

// Start HTTP and WebSocket server
server.listen(PORT, '0.0.0.0', () => {
  console.log(`Server listening on port ${PORT}`);
  console.log(`Local address: http://localhost:${PORT}`);
  connectWithRetry();
});

module.exports = { app, server };
