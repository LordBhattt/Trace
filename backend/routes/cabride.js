// routes/cabride.js
const express = require('express');
const CabRide = require("../models/mongodb/CabRide");
const authMiddleware = require("../middleware/auth");
const { sendNotification } = require("../services/firebase/notificationService");
const User = require("../models/mongodb/User");

const router = express.Router();

/* ---------------------------------------------------
   🔥 PRICING LOGIC (Backend Authoritative)
---------------------------------------------------- */
function calculateFare(distanceKm, etaMin, foodStops) {
  const BASE_FARE = 50;           // ₹50 base
  const PER_KM = 12;              // ₹12/km
  const PER_MIN = 2;              // ₹2/min
  const PER_STOP = 15;            // ₹15 per food stop

  const baseFare = BASE_FARE;
  const distanceFare = Math.round(distanceKm * PER_KM);
  const timeFare = Math.round(etaMin * PER_MIN);
  const foodStopFare = foodStops * PER_STOP;

  const totalFare = baseFare + distanceFare + timeFare + foodStopFare;

  return {
    baseFare,
    distanceFare,
    timeFare,
    foodStopFare,
    totalFare,
  };
}

/* ---------------------------------------------------
   CREATE RIDE
   🔥 FIX: Backend computes REAL fare + sets status to "confirmed"
---------------------------------------------------- */
router.post("/create", authMiddleware, async (req, res) => {
  try {
    const {
      pickup,
      drop,
      distanceKm,
      etaMin,
      foodStops = 0,
      selectedSuggestions = [],
    } = req.body;

    // 🔥 Backend computes authoritative pricing
    const pricing = calculateFare(distanceKm, etaMin, foodStops);

    const ride = await CabRide.create({
      userId: req.user.id,
      pickup,
      drop,
      distanceKm,
      etaMin,
      foodStops,
      pricing,
      selectedSuggestions,
      status: "confirmed",
      confirmedAt: new Date(),
    });

    // 🔥 SEND NOTIFICATION
    try {
      const user = await User.findById(req.user.id);
      if (user && user.fcmToken) {
        await sendNotification(
          user.fcmToken,
          "Ride Confirmed!",
          `Your ride to ${drop.label} has been confirmed. Searching for drivers...`,
          {
            type: "ride_confirmed",
            rideId: ride._id.toString(),
          }
        );
      }
    } catch (notifErr) {
      console.log("Notification error (non-critical):", notifErr.message);
    }

    return res.json({ success: true, ride });
  } catch (err) {
    console.error("Create Ride Error:", err);
    return res
      .status(500)
      .json({ success: false, message: "Failed to create ride" });
  }
});

/* ---------------------------------------------------
   🔥 NEW: UPDATE RIDE STATUS
   PATCH /api/cabride/update-status
   
   Supports status transitions:
   - confirmed → assigned
   - assigned → arriving
   - arriving → atPickup
   - atPickup → started
   - started → completed
---------------------------------------------------- */
router.patch("/update-status", authMiddleware, async (req, res) => {
  try {
    const { rideId, status } = req.body;

    const validStatuses = [
      "confirmed",
      "assigned",
      "arriving",
      "atPickup",
      "started",
      "completed",
    ];

    if (!validStatuses.includes(status)) {
      return res.status(400).json({
        success: false,
        message: "Invalid status",
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

    // Don't allow status updates on cancelled/paid rides
    if (ride.status === "cancelled" || ride.status === "paid") {
      return res.status(400).json({
        success: false,
        message: "Cannot update status of cancelled/paid ride",
      });
    }

    ride.status = status;

    // 🔥 Track important timestamps
    if (status === "started" && !ride.startedAt) {
      ride.startedAt = new Date();
    }
    
    if (status === "completed" && !ride.completedAt) {
      ride.completedAt = new Date();
    }

    await ride.save();

    // 🔥 SEND NOTIFICATIONS BASED ON STATUS
    try {
      const user = await User.findById(req.user.id);
      if (user && user.fcmToken) {
        let title = "";
        let body = "";

        switch (status) {
          case "assigned":
            title = "Driver Assigned!";
            body = `${ride.driver?.name || "Your driver"} is on the way to pickup`;
            break;
          case "arriving":
            title = "Driver Arriving";
            body = "Your driver is arriving at the pickup location";
            break;
          case "atPickup":
            title = "Driver at Pickup";
            body = "Your driver has reached the pickup location";
            break;
          case "started":
            title = "Trip Started!";
            body = "Your trip has started. Enjoy the ride!";
            break;
          case "completed":
            title = "Trip Completed";
            body = "You've reached your destination. Please complete payment.";
            break;
        }

        if (title) {
          await sendNotification(user.fcmToken, title, body, {
            type: `ride_${status}`,
            rideId: ride._id.toString(),
          });
        }
      }
    } catch (notifErr) {
      console.log("Notification error (non-critical):", notifErr.message);
    }

    return res.json({ success: true, ride });
  } catch (err) {
    console.error("Update Status Error:", err);
    return res.status(500).json({
      success: false,
      message: "Failed to update ride status",
    });
  }
});

/* ---------------------------------------------------
   CANCEL RIDE
   🔥 FIX: Enhanced cancel logic
   
   RULES:
   - Cannot cancel if status = started/completed/paid
   - Cannot cancel after 3 minutes from confirmedAt
---------------------------------------------------- */
router.post("/cancel", authMiddleware, async (req, res) => {
  try {
    const { rideId } = req.body;

    const ride = await CabRide.findOne({
      _id: rideId,
      userId: req.user.id,
    });

    if (!ride) {
      return res
        .status(404)
        .json({ success: false, message: "Ride not found" });
    }

    // 🔥 FIX: Check if ride has started or completed
    if (["started", "completed", "paid"].includes(ride.status)) {
      return res.status(400).json({
        success: false,
        message: `Cannot cancel ride — status is ${ride.status}`,
      });
    }

    // 🔥 FIX: Check 3-minute window
    const diffMin =
      (Date.now() - new Date(ride.confirmedAt).getTime()) / 60000;

    if (diffMin > 3) {
      return res.status(400).json({
        success: false,
        message: "Cancellation window expired (3 minutes passed)",
      });
    }

    ride.status = "cancelled";
    ride.cancelledAt = new Date();
    await ride.save();

    return res.json({ success: true });
  } catch (err) {
    console.error("Cancel Ride Error:", err);
    return res
      .status(500)
      .json({ success: false, message: "Failed to cancel ride" });
  }
});

/* ---------------------------------------------------
   MARK RIDE COMPLETED
   🔥 FIX: Only sets status to "completed", NOT paid
   Payment happens separately via /payment/verify
---------------------------------------------------- */
router.post("/complete", authMiddleware, async (req, res) => {
  try {
    const { rideId } = req.body;

    const ride = await CabRide.findOne({
      _id: rideId,
      userId: req.user.id,
    });

    if (!ride) {
      return res
        .status(404)
        .json({ success: false, message: "Ride not found" });
    }

    // Idempotent
    if (ride.status === "completed" || ride.status === "paid") {
      return res.json({ success: true, ride });
    }

    ride.status = "completed";
    ride.completedAt = new Date();
    await ride.save();

    return res.json({ success: true, ride });
  } catch (err) {
    console.error("Complete Ride Error:", err);
    return res
      .status(500)
      .json({ success: false, message: "Failed to complete ride" });
  }
});

/* ---------------------------------------------------
   RIDE HISTORY
---------------------------------------------------- */
router.get("/history", authMiddleware, async (req, res) => {
  try {
    const rides = await CabRide.find({ userId: req.user.id }).sort({
      createdAt: -1,
    });

    return res.json({ success: true, rides });
  } catch (err) {
    console.error("Ride History Error:", err);
    return res
      .status(500)
      .json({ success: false, message: "Failed to fetch ride history" });
  }
});

module.exports = router;
