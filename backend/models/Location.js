const mongoose = require('mongoose');

const locationSchema = new mongoose.Schema({
  _id: {
    type: String,
    default: "X"
  },
  latitude: Number,
  longitude: Number,
  accuracy: Number,
  timestamp: Date
}, {
  collection: 'locations',
  versionKey: false
});

module.exports = mongoose.model('Location', locationSchema);
