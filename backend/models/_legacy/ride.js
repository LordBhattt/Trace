// models/Ride.js
const mongoose = require("mongoose");

const rideSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
    },

    driver: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Driver",
      default: null,
    },

    pickup: {
      address: String,
      coordinates: [Number], // [lng, lat]
    },

    drop: {
      address: String,
      coordinates: [Number],
    },

    distance: Number,
    duration: Number,

    fare: {
      baseFare: Number,
      distanceFare: Number,
      timeFare: Number,
      total: Number,
    },

    cabType: String,

    status: {
      type: String,
      default: "created", // created, assigned, arriving, in-progress, completed, cancelled
    },

    paymentStatus: {
      type: String,
      default: "pending", // pending, paid, failed
    },

    razorpayOrderId: String,
    razorpayPaymentId: String,
  },
  { timestamps: true }
);

module.exports = mongoose.model("Ride", rideSchema);