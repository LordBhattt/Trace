// routes/user.js
const express = require('express');
const User = require('../models/mongodb/User');
const CabRide = require('../models/mongodb/CabRide');
const authMiddleware = require('../middleware/auth');

const router = express.Router();

/* ---------------------------------------------------
   GET USER PROFILE
---------------------------------------------------- */
router.get('/profile', authMiddleware, async (req, res) => {
  try {
    const user = await User.findById(req.user.id).select('-password');
    
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found',
      });
    }

    return res.json({
      success: true,
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        phone: user.phone,
        profilePicture: user.profilePicture,
        totalRides: user.totalRides,
        rating: user.rating,
        createdAt: user.createdAt,
      },
    });
  } catch (err) {
    console.error('Get Profile Error:', err);
    return res.status(500).json({
      success: false,
      message: 'Failed to fetch profile',
    });
  }
});

/* ---------------------------------------------------
   GET USER STATS
   Returns:
   - Total rides
   - Total spent
   - Total distance
   - Average fare
---------------------------------------------------- */
router.get('/stats', authMiddleware, async (req, res) => {
  try {
    const rides = await CabRide.find({
      userId: req.user.id,
      status: { $in: ['completed', 'paid'] },
    });

    const totalRides = rides.length;
    const totalSpent = rides.reduce((sum, ride) => {
      return sum + (ride.pricing?.totalFare || 0);
    }, 0);

    const totalDistance = rides.reduce((sum, ride) => {
      return sum + (ride.distanceKm || 0);
    }, 0);

    return res.json({
      success: true,
      stats: {
        totalRides,
        totalSpent: Math.round(totalSpent),
        totalDistance: parseFloat(totalDistance.toFixed(1)),
        avgFare: totalRides > 0 ? Math.round(totalSpent / totalRides) : 0,
      },
    });
  } catch (err) {
    console.error('Get Stats Error:', err);
    return res.status(500).json({
      success: false,
      message: 'Failed to fetch stats',
    });
  }
});

/* ---------------------------------------------------
   UPDATE FCM TOKEN
---------------------------------------------------- */
router.post('/fcm-token', authMiddleware, async (req, res) => {
  try {
    const { token } = req.body;

    if (!token) {
      return res.status(400).json({
        success: false,
        message: 'FCM token is required',
      });
    }

    await User.findByIdAndUpdate(req.user.id, { fcmToken: token });

    return res.json({
      success: true,
      message: 'FCM token updated',
    });
  } catch (err) {
    console.error('Update FCM Token Error:', err);
    return res.status(500).json({
      success: false,
      message: 'Failed to update FCM token',
    });
  }
});

module.exports = router;