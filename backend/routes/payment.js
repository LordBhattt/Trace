// routes/payment.js
const express = require("express");
const Razorpay = require("razorpay");
const crypto = require("crypto");
const dotenv = require("dotenv");
const CabRide = require("../models/mongodb/CabRide");
const authMiddleware = require("../middleware/auth");

// ⭐ Added for notifications
const { sendNotification } = require("../services/firebase/notificationService");
const User = require("../models/mongodb/User");

dotenv.config();

const router = express.Router();

// Razorpay Instance
const razorpay = new Razorpay({
  key_id: process.env.RAZORPAY_KEY_ID,
  key_secret: process.env.RAZORPAY_KEY_SECRET,
});

/* ---------------------------------------------------------
   GET PUBLIC KEY  
   GET /api/payment/key
--------------------------------------------------------- */
router.get("/key", authMiddleware, (req, res) => {
  return res.json({
    success: true,
    keyId: process.env.RAZORPAY_KEY_ID,
  });
});

/* ---------------------------------------------------------
   CREATE ORDER
   POST /api/payment/create-order
--------------------------------------------------------- */
router.post("/create-order", authMiddleware, async (req, res) => {
  try {
    const { rideId } = req.body;

    if (!rideId) {
      return res.status(400).json({
        success: false,
        message: "rideId is required",
      });
    }

    const ride = await CabRide.findOne({
      _id: rideId,
      userId: req.user.id,
    });

    if (!ride) {
      return res.status(404).json({
        success: false,
        message: "Ride not found",
      });
    }

    if (ride.status !== "completed") {
      return res.status(400).json({
        success: false,
        message: "Ride must be completed before payment",
      });
    }

    const amount = ride.pricing.totalFare;

    if (!amount || amount <= 0) {
      return res.status(400).json({
        success: false,
        message: "Invalid fare amount",
      });
    }

    // Receipt guaranteed < 40 chars
    const rideShort = rideId.toString().slice(-8);
    const timestamp = Date.now().toString(36).slice(-6);
    const receipt = `r_${rideShort}_${timestamp}`;

    const order = await razorpay.orders.create({
      amount: Math.round(amount * 100),
      currency: "INR",
      receipt,
    });

    return res.json({
      success: true,
      orderId: order.id,
      amount,
      ride,
    });
  } catch (err) {
    console.error("Order Error:", err);
    return res.status(500).json({
      success: false,
      message: "Order creation failed",
      error: err.message,
    });
  }
});

/* ---------------------------------------------------------
   VERIFY PAYMENT
   POST /api/payment/verify
--------------------------------------------------------- */
router.post("/verify", authMiddleware, async (req, res) => {
  try {
    const { paymentId, orderId, signature, rideId } = req.body;

    if (!paymentId || !orderId || !signature || !rideId) {
      return res.status(400).json({
        success: false,
        message: "Missing fields",
      });
    }

    const ride = await CabRide.findOne({
      _id: rideId,
      userId: req.user.id,
    });

    if (!ride) {
      return res.status(404).json({
        success: false,
        message: "Ride not found",
      });
    }

    // Already paid (idempotent)
    if (ride.isPaid && ride.paymentId === paymentId) {
      return res.json({
        success: true,
        message: "Payment already verified",
        ride,
      });
    }

    // Signature validation
    const expectedSig = crypto
      .createHmac("sha256", process.env.RAZORPAY_KEY_SECRET)
      .update(orderId + "|" + paymentId)
      .digest("hex");

    if (expectedSig !== signature) {
      return res.status(400).json({
        success: false,
        message: "Invalid payment signature",
      });
    }

    // Update ride
    ride.paymentId = paymentId;
    ride.orderId = orderId;
    ride.signature = signature;
    ride.isPaid = true;
    ride.status = "paid";
    ride.paidAt = new Date();

    await ride.save();

    /* ---------------------------------------------------------
       🔥 SEND PAYMENT SUCCESS NOTIFICATION TO USER
    --------------------------------------------------------- */
    try {
      const user = await User.findById(req.user.id);

      if (user && user.fcmToken) {
        await sendNotification(
          user.fcmToken,
          "Payment Successful!",
          `₹${ride.pricing.totalFare} paid successfully. Thank you for riding with TRACE!`,
          {
            type: "payment_success",
            rideId: ride._id.toString(),
            amount: ride.pricing.totalFare.toString(),
          }
        );
      }
    } catch (notifyErr) {
      console.error("Notification send error:", notifyErr);
    }

    return res.json({
      success: true,
      message: "Payment verified successfully",
      ride,
    });
  } catch (err) {
    console.error("Verify Error:", err);
    return res.status(500).json({
      success: false,
      message: "Payment verification failed",
      error: err.message,
    });
  }
});

module.exports = router;
