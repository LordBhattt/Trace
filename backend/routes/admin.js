// routes/admin.js
const express = require("express");
const Driver = require("../models/mongodb/Driver");
const CabRide = require("../models/mongodb/CabRide");
const User = require("../models/mongodb/User");
const authMiddleware = require("../middleware/auth");
const bcrypt = require("bcryptjs");

const router = express.Router();

/* ===================================
   ADMIN AUTH MIDDLEWARE
   (Simple check - enhance with admin role later)
=================================== */
const adminAuth = async (req, res, next) => {
  try {
    // For now, any authenticated user can access admin
    // TODO: Add role-based access control
    const user = await User.findById(req.user.id);
    if (!user) {
      return res.status(403).json({ success: false, message: "Unauthorized" });
    }
    next();
  } catch (err) {
    return res.status(403).json({ success: false, message: "Unauthorized" });
  }
};

/* ===================================
   DASHBOARD STATS
=================================== */
router.get("/stats", authMiddleware, adminAuth, async (req, res) => {
  try {
    const totalDrivers = await Driver.countDocuments();
    const onlineDrivers = await Driver.countDocuments({ isOnline: true });
    const totalUsers = await User.countDocuments();
    const totalRides = await CabRide.countDocuments();
    const completedRides = await CabRide.countDocuments({ status: "paid" });
    const activeRides = await CabRide.countDocuments({
      status: { $in: ["confirmed", "assigned", "arriving", "atPickup", "started"] },
    });

    // Calculate total earnings
    const earnings = await CabRide.aggregate([
      { $match: { isPaid: true } },
      { $group: { _id: null, total: { $sum: "$pricing.totalFare" } } },
    ]);

    const totalEarnings = earnings.length > 0 ? earnings[0].total : 0;

    return res.json({
      success: true,
      stats: {
        totalDrivers,
        onlineDrivers,
        totalUsers,
        totalRides,
        completedRides,
        activeRides,
        totalEarnings,
      },
    });
  } catch (err) {
    console.error("Admin Stats Error:", err);
    return res.status(500).json({ success: false, message: "Server error" });
  }
});

/* ===================================
   DRIVER MANAGEMENT
=================================== */

// Get all drivers
router.get("/drivers", authMiddleware, adminAuth, async (req, res) => {
  try {
    const { status, online, page = 1, limit = 20 } = req.query;
    
    const filter = {};
    if (status) filter.documentStatus = status;
    if (online !== undefined) filter.isOnline = online === "true";

    const drivers = await Driver.find(filter)
      .sort({ createdAt: -1 })
      .limit(limit * 1)
      .skip((page - 1) * limit)
      .select("-password");

    const total = await Driver.countDocuments(filter);

    return res.json({
      success: true,
      drivers,
      pagination: {
        total,
        page: parseInt(page),
        pages: Math.ceil(total / limit),
      },
    });
  } catch (err) {
    console.error("Get Drivers Error:", err);
    return res.status(500).json({ success: false, message: "Server error" });
  }
});

// Add new driver
router.post("/drivers", authMiddleware, adminAuth, async (req, res) => {
  try {
    const {
      name,
      email,
      phone,
      password,
      vehicleNumber,
      vehicleModel,
      vehicleType,
      licenseNumber,
      licenseExpiry,
    } = req.body;

    // Check if driver exists
    const exists = await Driver.findOne({ $or: [{ email }, { phone }] });
    if (exists) {
      return res.json({
        success: false,
        message: "Driver with this email or phone already exists",
      });
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, 12);

    const driver = await Driver.create({
      name,
      email,
      phone,
      password: hashedPassword,
      vehicleNumber,
      vehicleModel,
      vehicleType: vehicleType || "sedan",
      licenseNumber,
      licenseExpiry,
      documentStatus: "pending",
    });

    return res.json({
      success: true,
      message: "Driver added successfully",
      driver: {
        id: driver._id,
        name: driver.name,
        email: driver.email,
        phone: driver.phone,
      },
    });
  } catch (err) {
    console.error("Add Driver Error:", err);
    return res.status(500).json({ success: false, message: "Server error" });
  }
});

// Update driver status
router.patch("/drivers/:id/status", authMiddleware, adminAuth, async (req, res) => {
  try {
    const { id } = req.params;
    const { documentStatus, isBlocked } = req.body;

    const update = {};
    if (documentStatus) update.documentStatus = documentStatus;
    if (isBlocked !== undefined) update.isBlocked = isBlocked;

    const driver = await Driver.findByIdAndUpdate(id, update, {
      new: true,
      runValidators: true,
    }).select("-password");

    if (!driver) {
      return res.status(404).json({ success: false, message: "Driver not found" });
    }

    return res.json({
      success: true,
      message: "Driver status updated",
      driver,
    });
  } catch (err) {
    console.error("Update Driver Status Error:", err);
    return res.status(500).json({ success: false, message: "Server error" });
  }
});

// Delete driver
router.delete("/drivers/:id", authMiddleware, adminAuth, async (req, res) => {
  try {
    const { id } = req.params;

    const driver = await Driver.findByIdAndDelete(id);

    if (!driver) {
      return res.status(404).json({ success: false, message: "Driver not found" });
    }

    return res.json({
      success: true,
      message: "Driver deleted successfully",
    });
  } catch (err) {
    console.error("Delete Driver Error:", err);
    return res.status(500).json({ success: false, message: "Server error" });
  }
});

/* ===================================
   RIDE MANAGEMENT
=================================== */

// Get all rides
router.get("/rides", authMiddleware, adminAuth, async (req, res) => {
  try {
    const { status, page = 1, limit = 20 } = req.query;
    
    const filter = {};
    if (status) filter.status = status;

    const rides = await CabRide.find(filter)
      .populate("userId", "name email phone")
      .populate("driverId", "name phone vehicleNumber")
      .sort({ createdAt: -1 })
      .limit(limit * 1)
      .skip((page - 1) * limit);

    const total = await CabRide.countDocuments(filter);

    return res.json({
      success: true,
      rides,
      pagination: {
        total,
        page: parseInt(page),
        pages: Math.ceil(total / limit),
      },
    });
  } catch (err) {
    console.error("Get Rides Error:", err);
    return res.status(500).json({ success: false, message: "Server error" });
  }
});

// Manually assign driver to ride
router.patch("/rides/:id/assign", authMiddleware, adminAuth, async (req, res) => {
  try {
    const { id } = req.params;
    const { driverId } = req.body;

    const ride = await CabRide.findById(id);
    if (!ride) {
      return res.status(404).json({ success: false, message: "Ride not found" });
    }

    const driver = await Driver.findById(driverId);
    if (!driver) {
      return res.status(404).json({ success: false, message: "Driver not found" });
    }

    await ride.assignDriver({
      _id: driver._id,
      name: driver.name,
      phone: driver.phone,
      vehicleNumber: driver.vehicleNumber,
      rating: driver.rating,
    });

    return res.json({
      success: true,
      message: "Driver assigned successfully",
      ride,
    });
  } catch (err) {
    console.error("Assign Driver Error:", err);
    return res.status(500).json({ success: false, message: "Server error" });
  }
});

/* ===================================
   PAYMENT MANAGEMENT
=================================== */

// Get all payments
router.get("/payments", authMiddleware, adminAuth, async (req, res) => {
  try {
    const { page = 1, limit = 20 } = req.query;

    const payments = await CabRide.find({ isPaid: true })
      .populate("userId", "name email phone")
      .populate("driverId", "name phone")
      .sort({ paidAt: -1 })
      .limit(limit * 1)
      .skip((page - 1) * limit)
      .select("userId driverId pricing paymentId orderId paidAt");

    const total = await CabRide.countDocuments({ isPaid: true });

    return res.json({
      success: true,
      payments,
      pagination: {
        total,
        page: parseInt(page),
        pages: Math.ceil(total / limit),
      },
    });
  } catch (err) {
    console.error("Get Payments Error:", err);
    return res.status(500).json({ success: false, message: "Server error" });
  }
});

/* ===================================
   USER MANAGEMENT
=================================== */

// Get all users
router.get("/users", authMiddleware, adminAuth, async (req, res) => {
  try {
    const { page = 1, limit = 20 } = req.query;

    const users = await User.find()
      .sort({ createdAt: -1 })
      .limit(limit * 1)
      .skip((page - 1) * limit)
      .select("-password");

    const total = await User.countDocuments();

    return res.json({
      success: true,
      users,
      pagination: {
        total,
        page: parseInt(page),
        pages: Math.ceil(total / limit),
      },
    });
  } catch (err) {
    console.error("Get Users Error:", err);
    return res.status(500).json({ success: false, message: "Server error" });
  }
});

module.exports = router;