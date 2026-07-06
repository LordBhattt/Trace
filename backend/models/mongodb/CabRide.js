// models/CabRide.js
const mongoose = require("mongoose");

/**
 * CabRide Model - Complete & Production Ready
 *
 * Now supports:
 * - Proper driverId (ref: 'Driver') for populate()
 * - Embedded driver snapshot (name, phone, etc.) for quick reads
 * - Full status lifecycle + payment + cancellation rules
 */

const CabRideSchema = new mongoose.Schema(
  {
    // ===== USER REFERENCE =====
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },

    // ===== DRIVER REFERENCE (OPTION B) =====
    driverId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Driver",
      default: null,
      index: true,
    },

    // Optional driver snapshot (for quick display / historical data)
    driver: {
      id: {
        type: mongoose.Schema.Types.ObjectId,
        ref: "Driver",
        default: null,
      },
      name: { type: String, default: null },
      phone: { type: String, default: null },
      vehicle: { type: String, default: null },
      plate: { type: String, default: null },
      rating: {
        type: Number,
        default: null,
        min: 0,
        max: 5,
      },
    },

    // ===== LOCATION DATA =====
    pickup: {
      label: { type: String, default: "Pickup Location" },
      lat: { type: Number, required: true },
      lon: { type: Number, required: true },
    },

    drop: {
      label: { type: String, default: "Drop Location" },
      lat: { type: Number, required: true },
      lon: { type: Number, required: true },
    },

    // ===== ROUTE DETAILS =====
    distanceKm: {
      type: Number,
      required: true,
      min: 0,
    },

    etaMin: {
      type: Number,
      required: true,
      min: 0,
    },

    // ===== FOOD DELIVERY INTEGRATION =====
    foodStops: {
      type: Number,
      default: 0,
      min: 0,
      max: 5,
    },

    selectedSuggestions: {
      type: [mongoose.Schema.Types.Mixed],
      default: [],
    },

    // ===== PRICING (BACKEND AUTHORITATIVE) =====
    pricing: {
      baseFare: {
        type: Number,
        default: 0,
        min: 0,
      },
      distanceFare: {
        type: Number,
        default: 0,
        min: 0,
      },
      timeFare: {
        type: Number,
        default: 0,
        min: 0,
      },
      foodStopFare: {
        type: Number,
        default: 0,
        min: 0,
      },
      totalFare: {
        type: Number,
        default: 0,
        min: 0,
        required: true,
      },
    },

    // ===== RIDE LIFECYCLE STATUS =====
    status: {
      type: String,
      enum: [
        "pending",
        "confirmed",
        "assigned",
        "arriving",
        "atPickup",
        "started",
        "completed",
        "paid",
        "cancelled",
      ],
      default: "confirmed",
      required: true,
      index: true,
    },

    // ===== CRITICAL TIMESTAMPS =====

    // When ride was confirmed (used for 3-minute cancellation window)
    confirmedAt: {
      type: Date,
      default: Date.now,
      required: true,
    },

    // When driver accepted / was assigned
    acceptedAt: {
      type: Date,
      default: null,
    },

    // When trip actually started
    startedAt: {
      type: Date,
      default: null,
    },

    // When destination was reached
    completedAt: {
      type: Date,
      default: null,
    },

    // When payment was verified
    paidAt: {
      type: Date,
      default: null,
    },

    // When ride was cancelled
    cancelledAt: {
      type: Date,
      default: null,
    },

    // ===== PAYMENT INTEGRATION (RAZORPAY) =====
    paymentId: {
      type: String,
      default: null,
      index: true,
    },

    orderId: {
      type: String,
      default: null,
      index: true,
    },

    signature: {
      type: String,
      default: null,
    },

    isPaid: {
      type: Boolean,
      default: false,
      required: true,
      index: true,
    },

    // ===== CANCELLATION TRACKING =====
    cancellationReason: {
      type: String,
      default: null,
    },

    cancelledBy: {
      type: String,
      enum: ["user", "driver", "system", null],
      default: null,
    },

    // ===== ADDITIONAL METADATA =====
    notes: {
      type: String,
      default: null,
      maxlength: 500,
    },

    // Rating given by user after ride
    userRating: {
      rating: {
        type: Number,
        min: 1,
        max: 5,
        default: null,
      },
      feedback: {
        type: String,
        maxlength: 500,
        default: null,
      },
    },

    // OTP for pickup verification (if you add OTP later)
    pickupOTP: {
      type: String,
      default: null,
    },

    // For analytics and debugging
    metadata: {
      appVersion: String,
      deviceType: String,
      platform: String,
    },
  },
  {
    timestamps: true,
    collection: "cabrides",
  }
);

// ===== INDEXES =====
CabRideSchema.index({ userId: 1, createdAt: -1 });
CabRideSchema.index({ status: 1, confirmedAt: -1 });
CabRideSchema.index({ isPaid: 1, completedAt: -1 });
CabRideSchema.index({ driverId: 1, status: 1 }); // ✅ for admin / driver queries

// ===== VIRTUALS =====

// Can user cancel? (<= 3 minutes, and not started/completed/paid/cancelled)
CabRideSchema.virtual("canCancel").get(function () {
  if (["started", "completed", "paid", "cancelled"].includes(this.status)) {
    return false;
  }

  const diffMin = (Date.now() - new Date(this.confirmedAt).getTime()) / 60000;
  return diffMin <= 3;
});

// Is payment pending?
CabRideSchema.virtual("isPaymentPending").get(function () {
  return this.status === "completed" && !this.isPaid;
});

// Ride duration in minutes
CabRideSchema.virtual("rideDurationMin").get(function () {
  if (!this.startedAt || !this.completedAt) return null;
  return Math.round(
    (new Date(this.completedAt) - new Date(this.startedAt)) / 60000
  );
});

// ===== INSTANCE METHODS =====

// Cancel ride
CabRideSchema.methods.cancel = function (reason = null, by = "user") {
  this.status = "cancelled";
  this.cancelledAt = new Date();
  this.cancellationReason = reason;
  this.cancelledBy = by;
  return this.save();
};

// Assign driver (Option B: driverId + snapshot)
CabRideSchema.methods.assignDriver = function (driverData) {
  const id = driverData.id || driverData._id;

  this.driverId = id;
  this.driver = {
    id,
    name: driverData.name,
    phone: driverData.phone,
    vehicle: driverData.vehicle || driverData.vehicleNumber || null,
    plate: driverData.plate || driverData.vehicleNumber || null,
    rating: driverData.rating,
  };

  this.status = "assigned";
  this.acceptedAt = new Date();

  return this.save();
};

// Start trip
CabRideSchema.methods.startTrip = function () {
  if (!["assigned", "arriving", "atPickup"].includes(this.status)) {
    throw new Error("Trip can only start after driver is at pickup");
  }
  this.status = "started";
  this.startedAt = new Date();
  return this.save();
};

// Complete trip
CabRideSchema.methods.completeTrip = function () {
  if (this.status !== "started") {
    throw new Error("Trip can only be completed from started status");
  }
  this.status = "completed";
  this.completedAt = new Date();
  return this.save();
};

// Mark paid
CabRideSchema.methods.markPaid = function (paymentId, orderId, signature) {
  this.paymentId = paymentId;
  this.orderId = orderId;
  this.signature = signature;
  this.isPaid = true;
  this.status = "paid";
  this.paidAt = new Date();
  return this.save();
};

// ===== STATIC METHODS =====

// Active ride for user
CabRideSchema.statics.getActiveRide = function (userId) {
  return this.findOne({
    userId,
    status: { $nin: ["completed", "paid", "cancelled"] },
  }).sort({ confirmedAt: -1 });
};

// History for user
CabRideSchema.statics.getUserHistory = function (userId, limit = 50) {
  return this.find({ userId })
    .sort({ createdAt: -1 })
    .limit(limit);
};

// Pending payments
CabRideSchema.statics.getPendingPayments = function () {
  return this.find({
    status: "completed",
    isPaid: false,
  }).sort({ completedAt: 1 });
};

// Calculate earnings
CabRideSchema.statics.calculateEarnings = async function (filter = {}) {
  const result = await this.aggregate([
    { $match: { ...filter, isPaid: true } },
    {
      $group: {
        _id: null,
        total: { $sum: "$pricing.totalFare" },
      },
    },
  ]);

  return result.length > 0 ? result[0].total : 0;
};

// ===== PRE-SAVE HOOKS =====

// Validate pricing consistency
CabRideSchema.pre("save", function (next) {
  if (this.pricing && this.pricing.totalFare != null) {
    const calculated =
      (this.pricing.baseFare || 0) +
      (this.pricing.distanceFare || 0) +
      (this.pricing.timeFare || 0) +
      (this.pricing.foodStopFare || 0);

    if (Math.abs(this.pricing.totalFare - calculated) > 1) {
      return next(
        new Error("Total fare does not match sum of fare components")
      );
    }
  }
  next();
});

// Auto-set paidAt
CabRideSchema.pre("save", function (next) {
  if (this.isModified("isPaid") && this.isPaid && !this.paidAt) {
    this.paidAt = new Date();
  }
  next();
});

module.exports = mongoose.model("CabRide", CabRideSchema);
