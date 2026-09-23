const express = require('express');
const router = express.Router();
const locationController = require('../controllers/locationController');

// POST /api/location - X uploads current location
router.post('/location', locationController.updateLocation);

// GET /api/location - Y fetches latest location for X
router.get('/location', locationController.getLocation);

module.exports = router;
