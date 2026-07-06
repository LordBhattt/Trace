// models/Driver.js
const mongoose = require("mongoose");

const DriverSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: true,
      trim: true,
    },

    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
    },

    phone: {
      type: String,
      required: true,
      unique: true,
    },

    password: {
      type: String,
      required: true,
      select: false,
    },

    // ⭐ ADDED — FCM Token for push notifications
    fcmToken: {
      type: String,
      default: null,
    },

    // Vehicle info
    vehicleNumber: {
      type: String,
      required: true,
      uppercase: true,
    },
    vehicleModel: {
      type: String,
      required: true,
    },
    vehicleType: {
      type: String,
      enum: ["sedan", "suv", "hatchback", "auto"],
      default: "sedan",
    },

    // License & documents
    licenseNumber: {
      type: String,
      required: true,
    },
    licenseExpiry: {
      type: Date,
      required: true,
    },
    documentStatus: {
      type: String,
      enum: ["pending", "approved", "rejected"],
      default: "pending",
    },

    // Status
    isOnline: {
      type: Boolean,
      default: false,
    },
    isAvailable: {
      type: Boolean,
      default: true,
    },
    isBlocked: {
      type: Boolean,
      default: false,
    },

    // Location
    currentLocation: {
      lat: { type: Number, default: null },
      lon: { type: Number, default: null },
    },
    lastLocationUpdate: {
      type: Date,
      default: null,
    },

    // Stats
    rating: {
      type: Number,
      default: 5.0,
      min: 0,
      max: 5,
    },
    totalRides: {
      type: Number,
      default: 0,
    },
    totalEarnings: {
      type: Number,
      default: 0,
    },

    // Bank details
    bankAccount: {
      accountNumber: String,
      ifsc: String,
      accountHolderName: String,
    },

    profilePicture: {
      type: String,
      default: null,
    },
  },
  {
    timestamps: true,
  }
);

// Indexes
DriverSchema.index({ email: 1 });
DriverSchema.index({ phone: 1 });
DriverSchema.index({ isOnline: 1, isAvailable: 1 });
DriverSchema.index({ "currentLocation.lat": 1, "currentLocation.lon": 1 });

module.exports = mongoose.model("Driver", DriverSchema);
