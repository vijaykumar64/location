const Location = require('../models/Location');
const mongoose = require('mongoose');
const socketService = require('../services/socketService');

// In-memory fallback cache when MongoDB is offline or initial connection is pending
let inMemoryLocation = null;

/**
 * Validates coordinate numbers, rejecting null, undefined, NaN, Infinity, and out-of-range values.
 */
function isValidNumber(val) {
  return typeof val === 'number' && !Number.isNaN(val) && Number.isFinite(val);
}

/**
 * Update location for X
 * POST /api/location
 */
exports.updateLocation = async (req, res) => {
  try {
    const { latitude, longitude, accuracy } = req.body;

    // Validate presence and finite number status
    if (!isValidNumber(latitude)) {
      return res.status(400).json({ error: 'Latitude is required and must be a valid finite number' });
    }

    if (!isValidNumber(longitude)) {
      return res.status(400).json({ error: 'Longitude is required and must be a valid finite number' });
    }

    if (!isValidNumber(accuracy) || accuracy < 0) {
      return res.status(400).json({ error: 'Accuracy is required and must be a positive number' });
    }

    // Validate coordinate ranges
    if (latitude < -90 || latitude > 90) {
      return res.status(400).json({ error: 'Latitude must be between -90 and 90' });
    }

    if (longitude < -180 || longitude > 180) {
      return res.status(400).json({ error: 'Longitude must be between -180 and 180' });
    }

    const timestamp = new Date();
    let updatedLocation = {
      _id: "X",
      latitude,
      longitude,
      accuracy,
      timestamp
    };

    // Update MongoDB if connected
    if (mongoose.connection.readyState === 1) {
      try {
        const doc = await Location.findOneAndUpdate(
          { _id: "X" },
          {
            latitude,
            longitude,
            accuracy,
            timestamp
          },
          {
            upsert: true,
            new: true,
            setDefaultsOnInsert: true
          }
        );

        if (doc) {
          updatedLocation = {
            _id: doc._id,
            latitude: doc.latitude,
            longitude: doc.longitude,
            accuracy: doc.accuracy,
            timestamp: doc.timestamp
          };
        }
      } catch (dbErr) {
        console.warn('[LocationController] MongoDB write failed, using in-memory store:', dbErr.message);
      }
    } else {
      console.log('[LocationController] MongoDB not connected: cached location update in memory.');
    }

    // Always keep memory cache up to date
    inMemoryLocation = updatedLocation;

    // Broadcast real-time update via Socket.IO
    socketService.emitLocationUpdated(updatedLocation);

    return res.status(200).json({
      _id: updatedLocation._id,
      latitude: updatedLocation.latitude,
      longitude: updatedLocation.longitude,
      accuracy: updatedLocation.accuracy,
      timestamp: updatedLocation.timestamp
    });
  } catch (error) {
    console.error('[LocationController] Error updating location:', error);
    return res.status(500).json({ error: 'Failed to update location' });
  }
};

/**
 * Get latest location for X
 * GET /api/location
 */
exports.getLocation = async (req, res) => {
  try {
    let location = null;

    if (mongoose.connection.readyState === 1) {
      try {
        location = await Location.findById("X");
      } catch (dbErr) {
        console.warn('[LocationController] MongoDB read failed, checking in-memory cache:', dbErr.message);
      }
    }

    // Fall back to in-memory store if DB is offline or not found
    if (!location && inMemoryLocation) {
      location = inMemoryLocation;
    }

    if (!location) {
      return res.status(404).json({
        message: 'No location available for X yet. Please start sharing from X\'s phone.'
      });
    }

    return res.status(200).json({
      _id: location._id,
      latitude: location.latitude,
      longitude: location.longitude,
      accuracy: location.accuracy,
      timestamp: location.timestamp
    });
  } catch (error) {
    console.error('[LocationController] Error fetching location:', error);
    return res.status(500).json({ error: 'Failed to retrieve location' });
  }
};
