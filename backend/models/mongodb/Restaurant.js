// models/Restaurant.js
const mongoose = require('mongoose');

const restaurantSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: true,
      trim: true,
    },

    description: {
      type: String,
      default: '',
    },

    coverImageUrl: {
      type: String,
      default: 'https://via.placeholder.com/400x200?text=Restaurant',
    },

    logoImageUrl: {
      type: String,
      default: 'https://via.placeholder.com/100?text=Logo',
    },

    location: {
      lat: { type: Number, required: true },
      lon: { type: Number, required: true },
      address: { type: String, required: true },
    },

    // eg. ["Pizza", "Burger", "North Indian"]
    cuisines: {
      type: [String],
      default: [],
    },

    avgRating: {
      type: Number,
      default: 4.0,
      min: 0,
      max: 5,
    },

    totalRatings: {
      type: Number,
      default: 0,
    },

    isVegOnly: {
      type: Boolean,
      default: false,
    },

    isActive: {
      type: Boolean,
      default: true,
    },

    deliveryRadiusKm: {
      type: Number,
      default: 5,
    },

    openingHours: {
      open: { type: String, default: '09:00' },
      close: { type: String, default: '23:00' },
    },

    // Base preparation time – used in ETA
    preparationTimeMin: {
      type: Number,
      default: 30,
    },

    // Flat discount % displayed on card ("20% OFF")
    discount: {
      type: Number,
      default: 0,
      min: 0,
      max: 100,
    },
  },
  {
    timestamps: true,
  }
);

// Index for location-based queries & filters
restaurantSchema.index({ 'location.lat': 1, 'location.lon': 1 });
restaurantSchema.index({ cuisines: 1 });
restaurantSchema.index({ isActive: 1 });

module.exports = mongoose.model('Restaurant', restaurantSchema);
