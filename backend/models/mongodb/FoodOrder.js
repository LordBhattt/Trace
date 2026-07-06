// models/FoodOrder.js
const mongoose = require('mongoose');

const foodOrderSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },

    // If this order is linked to a cab ride (for detour mode)
    linkedRideId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'CabRide',
      default: null,
    },

    // Delivery mode
    deliveryMode: {
      type: String,
      enum: ['detour_cab', 'dedicated_delivery'],
      required: true,
    },

    // NEW: How user paid / will pay
    paymentMode: {
      type: String,
      enum: ['online', 'cod'],
      default: 'online',
    },

    restaurantId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Restaurant',
      required: true,
    },

    // Line items
    items: [
      {
        menuItemId: {
          type: mongoose.Schema.Types.ObjectId,
          ref: 'MenuItem',
        },
        name: String,
        quantity: Number,
        unitPrice: Number,
        addOns: [
          {
            label: String,
            price: Number,
          },
        ],
        itemTotal: Number,
      },
    ],

    // Amount breakdown – must match frontend’s pricePreview usage
    amounts: {
      itemsTotal: { type: Number, required: true },
      platformFee: { type: Number, default: 5 },
      deliveryFee: { type: Number, default: 0 },
      distanceFee: { type: Number, default: 0 },
      discounts: { type: Number, default: 0 },
      gstAmount: { type: Number, default: 0 },
      finalPayableAmount: { type: Number, required: true },
    },

    // Where the food is to be delivered
    locationDelivery: {
      lat: { type: Number, required: true },
      lon: { type: Number, required: true },
      address: { type: String, required: true },
    },

    // High-level status
    status: {
      type: String,
      enum: [
        'placed',
        'accepted',
        'preparing',
        'ready_for_pickup',
        'picked_up',
        'on_the_way',
        'delivered',
        'cancelled',
      ],
      default: 'placed',
    },

    // Assigned driver / rider (if any)
    assignedDriverId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
    },

    // OTPs for pickup & drop
    otpPickup: {
      type: String,
      default: null,
    },
    otpDrop: {
      type: String,
      default: null,
    },

    // Simple flags
    isCancelled: {
      type: Boolean,
      default: false,
    },
    cancellationReason: {
      type: String,
      default: null,
    },

    // For cancelled orders where original customer still pays full
    originalCustomerPaysFull: {
      type: Boolean,
      default: false,
    },

    // Resale (50% off) logic
    isResellable: {
      type: Boolean,
      default: false,
    },
    resellStatus: {
      type: String,
      enum: ['none', 'listed', 'claimed', 'expired', 'sold'],
      default: 'none',
    },
    resellPrice: {
      type: Number,
      default: null,
    },
    resellBuyerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
    },

    // Payment fields (original customer)
    razorpayOrderId: { type: String, default: null },
    razorpayPaymentId: { type: String, default: null },
    razorpaySignature: { type: String, default: null },
    isPaid: { type: Boolean, default: false },

    // Resale payment tracking (separate from original payment)
    resalePaymentInfo: {
      razorpayPaymentId: { type: String, default: null },
      razorpayOrderId: { type: String, default: null },
      razorpaySignature: { type: String, default: null },
      paidAt: { type: Date, default: null },
    },

    // ETA for delivery (in minutes, snapshot at creation)
    etaMinutes: {
      type: Number,
      default: null,
    },

    // Timeline stamps (for tracking screen / stepper)
    placedAt: { type: Date, default: Date.now },
    acceptedAt: { type: Date, default: null },
    preparingAt: { type: Date, default: null },
    pickedUpAt: { type: Date, default: null },
    deliveredAt: { type: Date, default: null },
    cancelledAt: { type: Date, default: null },
    resellListedAt: { type: Date, default: null },
    resellClaimedAt: { type: Date, default: null },
  },
  {
    timestamps: true,
  }
);

// Indexes for performance
foodOrderSchema.index({ userId: 1, status: 1 });
foodOrderSchema.index({ restaurantId: 1, status: 1 });
foodOrderSchema.index({ assignedDriverId: 1, status: 1 });
foodOrderSchema.index({ isResellable: 1, resellStatus: 1 });
foodOrderSchema.index({ resellListedAt: 1 });

module.exports = mongoose.model('FoodOrder', foodOrderSchema);
