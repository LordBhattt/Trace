// routes/food.js - Updated with auto-progression
const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/auth');
const Restaurant = require('../models/mongodb/Restaurant');
const MenuItem = require('../models/mongodb/MenuItem');
const MenuCategory = require('../models/mongodb/MenuCategory');
const FoodOrder = require('../models/mongodb/FoodOrder');
const Razorpay = require('razorpay');
const crypto = require('crypto');

// ✅ IMPORT AUTO-PROGRESSION SERVICE
const orderProgressionService = require('../services/orderProgressionService');

/* ====================================
   HELPER FUNCTIONS
==================================== */

// Calculate distance between two points (Haversine formula)
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371; // Earth's radius in km
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

// Generate 4-digit OTP
function generateOTP() {
  return Math.floor(1000 + Math.random() * 9000).toString();
}

// Calculate food order pricing
function calculateFoodPricing(itemsTotal, distanceKm, deliveryMode) {
  const PLATFORM_FEE = 5;
  const BASE_DELIVERY_FEE = 20;
  const PER_KM_FEE = 8;
  const GST_RATE = 0.05; // 5%

  let deliveryFee = 0;
  let discounts = 0;

  if (deliveryMode === 'dedicated_delivery') {
    deliveryFee = BASE_DELIVERY_FEE + distanceKm * PER_KM_FEE;
  } else if (deliveryMode === 'detour_cab') {
    // Shared cab delivery - 50% discount
    const normalDeliveryFee = BASE_DELIVERY_FEE + distanceKm * PER_KM_FEE;
    deliveryFee = normalDeliveryFee * 0.5;
    discounts = normalDeliveryFee * 0.5;
  }

  const subtotal = itemsTotal + PLATFORM_FEE + deliveryFee;
  const gstAmount = Math.round(subtotal * GST_RATE);
  const finalPayableAmount = Math.round(subtotal + gstAmount - discounts);

  return {
    itemsTotal,
    platformFee: PLATFORM_FEE,
    deliveryFee: Math.round(deliveryFee),
    distanceFee: Math.round(distanceKm * PER_KM_FEE),
    discounts: Math.round(discounts),
    gstAmount,
    finalPayableAmount,
  };
}

/* ====================================
   RESTAURANT ENDPOINTS
==================================== */

// GET /api/food/restaurants - List all restaurants
router.get('/restaurants', async (req, res) => {
  try {
    const { lat, lon, cuisine, vegOnly, search, sortBy } = req.query;

    let query = { isActive: true };

    if (cuisine) {
      query.cuisines = { $in: [cuisine] };
    }

    if (vegOnly === 'true') {
      query.isVegOnly = true;
    }

    if (search) {
      query.name = { $regex: search, $options: 'i' };
    }

    let restaurants = await Restaurant.find(query).lean();

    if (lat && lon) {
      const userLat = parseFloat(lat);
      const userLon = parseFloat(lon);

      restaurants = restaurants.map((r) => {
        const distance = calculateDistance(
          userLat,
          userLon,
          r.location.lat,
          r.location.lon
        );
        return { ...r, distance: Math.round(distance * 10) / 10 };
      });

      restaurants = restaurants.filter(
        (r) => r.distance <= r.deliveryRadiusKm
      );
    }

    if (sortBy === 'rating') {
      restaurants.sort((a, b) => b.avgRating - a.avgRating);
    } else if (sortBy === 'distance' && lat && lon) {
      restaurants.sort((a, b) => a.distance - b.distance);
    }

    return res.json(restaurants);
  } catch (err) {
    console.error('Get Restaurants Error:', err);
    return res.status(500).json({
      success: false,
      message: 'Failed to fetch restaurants',
    });
  }
});

// GET /api/food/restaurants/:id - Get restaurant details with menu
router.get('/restaurants/:id', async (req, res) => {
  try {
    const { id } = req.params;

    const restaurant = await Restaurant.findById(id).lean();
    if (!restaurant) {
      return res.status(404).json({
        success: false,
        message: 'Restaurant not found',
      });
    }

    const categories = await MenuCategory.find({
      restaurantId: id,
    })
      .sort({ displayOrder: 1 })
      .lean();

    const menuItemsPromises = categories.map(async (cat) => {
      const items = await MenuItem.find({
        restaurantId: id,
        categoryId: cat._id,
        isAvailable: true,
      }).lean();

      return {
        ...cat,
        items,
      };
    });

    const menu = await Promise.all(menuItemsPromises);

    return res.json({
      success: true,
      restaurant: {
        ...restaurant,
        menu,
      },
    });
  } catch (err) {
    console.error('Get Restaurant Details Error:', err);
    return res.status(500).json({
      success: false,
      message: 'Failed to fetch restaurant details',
    });
  }
});

// GET /api/food/items - Search menu items globally
router.get('/items', async (req, res) => {
  try {
    const { keyword, tag } = req.query;

    let query = { isAvailable: true };

    if (keyword) {
      query.$text = { $search: keyword };
    }

    if (tag) {
      query.tags = { $in: [tag] };
    }

    const items = await MenuItem.find(query)
      .populate('restaurantId', 'name location cuisines avgRating')
      .limit(50)
      .lean();

    return res.json({ success: true, items });
  } catch (err) {
    console.error('Search Items Error:', err);
    return res.status(500).json({
      success: false,
      message: 'Failed to search items',
    });
  }
});

router.get('/items/search', async (req, res) => {
  return router.handle(
    { ...req, url: '/items', originalUrl: '/items' },
    res
  );
});

/* ====================================
   ORDER ENDPOINTS
==================================== */

// POST /api/food/orders/price-preview
router.post('/orders/price-preview', authMiddleware, async (req, res) => {
  try {
    const { items, restaurantId, deliveryLat, deliveryLon, deliveryMode } =
      req.body;

    let itemsTotal = 0;
    for (const item of items) {
      const menuItem = await MenuItem.findById(item.menuItemId);
      if (!menuItem) continue;

      let itemPrice = menuItem.price * item.quantity;

      if (item.addOns && item.addOns.length > 0) {
        for (const addOn of item.addOns) {
          itemPrice += addOn.price * item.quantity;
        }
      }

      itemsTotal += itemPrice;
    }

    const restaurant = await Restaurant.findById(restaurantId);
    if (!restaurant) {
      return res.status(404).json({
        success: false,
        message: 'Restaurant not found',
      });
    }

    const distance = calculateDistance(
      restaurant.location.lat,
      restaurant.location.lon,
      deliveryLat,
      deliveryLon
    );

    const pricing = calculateFoodPricing(itemsTotal, distance, deliveryMode);

    const eta = Math.round(restaurant.preparationTimeMin + distance * 3);

    return res.json({
      success: true,
      itemsTotal: pricing.itemsTotal,
      platformFee: pricing.platformFee,
      deliveryFee: pricing.deliveryFee,
      distanceFee: pricing.distanceFee,
      discounts: pricing.discounts,
      gstAmount: pricing.gstAmount,
      finalPayableAmount: pricing.finalPayableAmount,
      distance: Math.round(distance * 10) / 10,
      eta
    });

  } catch (err) {
    console.error('Price Preview Error:', err);
    return res.status(500).json({
      success: false,
      message: 'Failed to calculate pricing',
    });
  }
});

// POST /api/food/orders - Create new order
router.post('/orders', authMiddleware, async (req, res) => {
  try {
    const {
      items,
      restaurantId,
      deliveryLat,
      deliveryLon,
      deliveryAddress,
      deliveryMode,
      linkedRideId,
      amounts: clientAmounts,
    } = req.body;

    const clientPaymentMode =
      clientAmounts && clientAmounts.paymentMode === 'cod' ? 'cod' : 'online';

    let itemsTotal = 0;
    const orderItems = [];

    for (const item of items) {
      const menuItem = await MenuItem.findById(item.menuItemId);
      if (!menuItem || !menuItem.isAvailable) {
        return res.status(400).json({
          success: false,
          message: `Item ${menuItem?.name || 'unknown'} is not available`,
        });
      }

      let itemPrice = menuItem.price * item.quantity;
      const addOns = item.addOns || [];

      if (addOns.length > 0) {
        for (const addOn of addOns) {
          itemPrice += addOn.price * item.quantity;
        }
      }

      orderItems.push({
        menuItemId: menuItem._id,
        name: menuItem.name,
        quantity: item.quantity,
        unitPrice: menuItem.price,
        addOns,
        itemTotal: itemPrice,
      });

      itemsTotal += itemPrice;
    }

    const restaurant = await Restaurant.findById(restaurantId);
    if (!restaurant) {
      return res.status(404).json({
        success: false,
        message: 'Restaurant not found',
      });
    }

    const distance = calculateDistance(
      restaurant.location.lat,
      restaurant.location.lon,
      deliveryLat,
      deliveryLon
    );

    if (distance > restaurant.deliveryRadiusKm) {
      return res.status(400).json({
        success: false,
        message: 'Delivery location outside restaurant radius',
      });
    }

    const amounts = calculateFoodPricing(itemsTotal, distance, deliveryMode);

    const otpPickup = generateOTP();
    const otpDrop = generateOTP();

    const etaMinutes = Math.round(
      restaurant.preparationTimeMin + distance * 3
    );

    const order = await FoodOrder.create({
      userId: req.user.id,
      linkedRideId: linkedRideId || null,
      deliveryMode,
      paymentMode: clientPaymentMode,
      restaurantId,
      items: orderItems,
      amounts,
      locationDelivery: {
        lat: deliveryLat,
        lon: deliveryLon,
        address: deliveryAddress,
      },
      otpPickup,
      otpDrop,
      status: clientPaymentMode === 'cod' ? 'placed' : 'placed',
      placedAt: new Date(),
      etaMinutes,
    });

    // ✅ START AUTO-PROGRESSION FOR THIS ORDER
    orderProgressionService.startAutoProgression(order._id.toString());
    console.log(`🚀 Auto-progression started for order: ${order._id}`);

    return res.json({ success: true, order });
  } catch (err) {
    console.error('Create Order Error:', err);
    return res.status(500).json({
      success: false,
      message: 'Failed to create order',
    });
  }
});

/* ====================================
   PAYMENT INTEGRATION
==================================== */

router.post(
  '/orders/:id/create-razorpay-order',
  authMiddleware,
  async (req, res) => {
    try {
      const razorpay = new Razorpay({
        key_id: process.env.RAZORPAY_KEY_ID,
        key_secret: process.env.RAZORPAY_KEY_SECRET,
      });

      const order = await FoodOrder.findOne({
        _id: req.params.id,
        userId: req.user.id,
      });

      if (!order) {
        return res.status(404).json({
          success: false,
          message: 'Order not found',
        });
      }

      const amount = order.amounts.finalPayableAmount;

      const razorpayOrder = await razorpay.orders.create({
        amount: Math.round(amount * 100),
        currency: 'INR',
        receipt: `food_${order._id
          .toString()
          .slice(-8)}_${Date.now().toString(36).slice(-6)}`,
      });

      order.razorpayOrderId = razorpayOrder.id;
      await order.save();

      return res.json({
        success: true,
        razorpayOrderId: razorpayOrder.id,
        amount,
      });
    } catch (err) {
      console.error('Create Razorpay Order Error:', err);
      return res.status(500).json({
        success: false,
        message: 'Failed to create Razorpay order',
      });
    }
  }
);

router.post(
  '/orders/:id/verify-payment',
  authMiddleware,
  async (req, res) => {
    try {
      const { razorpayPaymentId, razorpaySignature } = req.body;

      const order = await FoodOrder.findOne({
        _id: req.params.id,
        userId: req.user.id,
      });

      if (!order) {
        return res.status(404).json({
          success: false,
          message: 'Order not found',
        });
      }

      if (order.isPaid && order.razorpayPaymentId === razorpayPaymentId) {
        return res.json({
          success: true,
          message: 'Payment already verified',
          order,
        });
      }

      const expectedSig = crypto
        .createHmac('sha256', process.env.RAZORPAY_KEY_SECRET)
        .update(order.razorpayOrderId + '|' + razorpayPaymentId)
        .digest('hex');

      if (expectedSig !== razorpaySignature) {
        return res.status(400).json({
          success: false,
          message: 'Invalid payment signature',
        });
      }

      order.razorpayPaymentId = razorpayPaymentId;
      order.razorpaySignature = razorpaySignature;
      order.isPaid = true;
      order.status = 'accepted';
      order.acceptedAt = new Date();

      await order.save();

      return res.json({
        success: true,
        message: 'Payment verified successfully',
        order,
      });
    } catch (err) {
      console.error('Verify Payment Error:', err);
      return res.status(500).json({
        success: false,
        message: 'Payment verification failed',
      });
    }
  }
);

/* ====================================
   ORDER READ / HISTORY / CANCEL
==================================== */

router.get('/orders/:id', authMiddleware, async (req, res) => {
  try {
    const order = await FoodOrder.findOne({
      _id: req.params.id,
      userId: req.user.id,
    })
      .populate('restaurantId', 'name location coverImageUrl')
      .lean();

    if (!order) {
      return res.status(404).json({
        success: false,
        message: 'Order not found',
      });
    }

    return res.json({ success: true, order });
  } catch (err) {
    console.error('Get Order Error:', err);
    return res.status(500).json({
      success: false,
      message: 'Failed to fetch order',
    });
  }
});

router.get('/orders', authMiddleware, async (req, res) => {
  try {
    const orders = await FoodOrder.find({ userId: req.user.id })
      .populate('restaurantId', 'name location coverImageUrl')
      .sort({ createdAt: -1 })
      .lean();

    return res.json({ success: true, orders });
  } catch (err) {
    console.error('Get Order History Error:', err);
    return res.status(500).json({
      success: false,
      message: 'Failed to fetch order history',
    });
  }
});

// ✅ UPDATED CANCEL ENDPOINT - Only allow cancellation before "preparing"
router.post('/orders/:id/cancel', authMiddleware, async (req, res) => {
  try {
    const { reason } = req.body;

    const order = await FoodOrder.findOne({
      _id: req.params.id,
      userId: req.user.id,
    });

    if (!order) {
      return res.status(404).json({
        success: false,
        message: 'Order not found',
      });
    }

    if (order.status === 'cancelled' || order.status === 'delivered') {
      return res.status(400).json({
        success: false,
        message: `Cannot cancel order with status: ${order.status}`,
      });
    }

    // ✅ CANCELLATION RULES:
    // - Can cancel: 'placed', 'accepted'
    // - Cannot cancel: 'preparing', 'ready_for_pickup', 'picked_up', 'on_the_way'
    const cancellableStatuses = ['placed', 'accepted'];

    if (!cancellableStatuses.includes(order.status)) {
      return res.status(400).json({
        success: false,
        message: `Cannot cancel order. Food is already being prepared (status: ${order.status})`,
      });
    }

    // ✅ STOP AUTO-PROGRESSION
    orderProgressionService.stopAutoProgression(order._id.toString());

    order.status = 'cancelled';
    order.isCancelled = true;
    order.cancellationReason = reason || 'User cancelled';
    order.cancelledAt = new Date();

    await order.save();

    return res.json({ 
      success: true, 
      message: 'Order cancelled successfully',
      order 
    });
  } catch (err) {
    console.error('Cancel Order Error:', err);
    return res.status(500).json({
      success: false,
      message: 'Failed to cancel order',
    });
  }
});

/* ====================================
   RESALE ENDPOINTS (UNCHANGED)
==================================== */

router.get('/resell/nearby', authMiddleware, async (req, res) => {
  try {
    const { lat, lon, radius = 5 } = req.query;

    if (!lat || !lon) {
      return res.status(400).json({
        success: false,
        message: 'Location required',
      });
    }

    const userLat = parseFloat(lat);
    const userLon = parseFloat(lon);

    const orders = await FoodOrder.find({
      isResellable: true,
      resellStatus: 'listed',
    })
      .populate('restaurantId', 'name location coverImageUrl')
      .lean();

    const nearbyOrders = [];
    const now = new Date();

    for (const order of orders) {
      const listTime = new Date(order.resellListedAt);
      const minsSinceListed = (now - listTime) / 60000;

      if (minsSinceListed > 45) {
        await FoodOrder.findByIdAndUpdate(order._id, {
          resellStatus: 'expired',
        });
        continue;
      }

      const distance = calculateDistance(
        userLat,
        userLon,
        order.locationDelivery.lat,
        order.locationDelivery.lon
      );

      if (distance <= radius) {
        nearbyOrders.push({
          ...order,
          distance: Math.round(distance * 10) / 10,
          minutesLeft: Math.round(45 - minsSinceListed),
        });
      }
    }

    nearbyOrders.sort((a, b) => a.distance - b.distance);

    return res.json({ success: true, orders: nearbyOrders });
  } catch (err) {
    console.error('Get Nearby Resale Error:', err);
    return res.status(500).json({
      success: false,
      message: 'Failed to fetch resale orders',
    });
  }
});

router.post('/resell/:orderId/claim', authMiddleware, async (req, res) => {
  try {
    const { orderId } = req.params;
    const { newDeliveryLat, newDeliveryLon, newDeliveryAddress } = req.body;

    const order = await FoodOrder.findById(orderId);

    if (!order) {
      return res.status(404).json({
        success: false,
        message: 'Order not found',
      });
    }

    if (order.resellStatus !== 'listed') {
      return res.status(400).json({
        success: false,
        message: 'Order no longer available for resale',
      });
    }

    const now = new Date();
    const listTime = new Date(order.resellListedAt);
    const minsSinceListed = (now - listTime) / 60000;

    if (minsSinceListed > 45) {
      order.resellStatus = 'expired';
      await order.save();

      return res.status(400).json({
        success: false,
        message: 'Order expired',
      });
    }

    order.resellStatus = 'claimed';
    order.resellBuyerId = req.user.id;
    order.resellClaimedAt = new Date();

    if (newDeliveryLat && newDeliveryLon && newDeliveryAddress) {
      order.locationDelivery = {
        lat: newDeliveryLat,
        lon: newDeliveryLon,
        address: newDeliveryAddress,
      };
    }

    await order.save();

    return res.json({
      success: true,
      order,
      paymentAmount: order.resellPrice,
    });
  } catch (err) {
    console.error('Claim Resale Error:', err);
    return res.status(500).json({
      success: false,
      message: 'Failed to claim order',
    });
  }
});

router.post(
  '/resell/:orderId/verify-payment',
  authMiddleware,
  async (req, res) => {
    try {
      const razorpay = new Razorpay({
        key_id: process.env.RAZORPAY_KEY_ID,
        key_secret: process.env.RAZORPAY_KEY_SECRET,
      });

      const { razorpayPaymentId, razorpayOrderId, razorpaySignature } =
        req.body;

      const order = await FoodOrder.findById(req.params.orderId);

      if (!order) {
        return res.status(404).json({
          success: false,
          message: 'Order not found',
        });
      }

      if (order.resellBuyerId.toString() !== req.user.id) {
        return res.status(403).json({
          success: false,
          message: 'Unauthorized',
        });
      }

      let razorpayResaleOrderId = razorpayOrderId;

      if (!razorpayResaleOrderId) {
        const razorpayOrder = await razorpay.orders.create({
          amount: Math.round(order.resellPrice * 100),
          currency: 'INR',
          receipt: `resale_${order._id
            .toString()
            .slice(-8)}_${Date.now().toString(36).slice(-6)}`,
        });
        razorpayResaleOrderId = razorpayOrder.id;
      }

      const expectedSig = crypto
        .createHmac('sha256', process.env.RAZORPAY_KEY_SECRET)
        .update(razorpayResaleOrderId + '|' + razorpayPaymentId)
        .digest('hex');

      if (expectedSig !== razorpaySignature) {
        order.resellStatus = 'listed';
        order.resellBuyerId = null;
        order.resellClaimedAt = null;
        await order.save();

        return res.status(400).json({
          success: false,
          message: 'Invalid payment signature',
        });
      }

      order.resellStatus = 'sold';
      order.isPaid = true;
      order.status = 'accepted';
      order.acceptedAt = new Date();

      order.resalePaymentInfo = {
        razorpayPaymentId,
        razorpayOrderId: razorpayResaleOrderId,
        razorpaySignature,
        paidAt: new Date(),
      };

      await order.save();

      // ✅ START AUTO-PROGRESSION FOR RESOLD ORDER
      orderProgressionService.startAutoProgression(order._id.toString());

      return res.json({
        success: true,
        message: 'Resale payment verified successfully',
        order,
      });
    } catch (err) {
      console.error('Verify Resale Payment Error:', err);
      return res.status(500).json({
        success: false,
        message: 'Payment verification failed',
      });
    }
  }
);

router.post('/resell/expire-pending', async (req, res) => {
  try {
    const now = new Date();
    const fiveMinutesAgo = new Date(now.getTime() - 5 * 60 * 1000);

    const expiredClaims = await FoodOrder.find({
      resellStatus: 'claimed',
      resellClaimedAt: { $lt: fiveMinutesAgo },
      isPaid: false,
    });

    for (const order of expiredClaims) {
      order.resellStatus = 'listed';
      order.resellBuyerId = null;
      order.resellClaimedAt = null;
      await order.save();
    }

    return res.json({
      success: true,
      message: `Expired ${expiredClaims.length} pending claims`,
    });
  } catch (err) {
    console.error('Expire Pending Error:', err);
    return res.status(500).json({
      success: false,
      message: 'Failed to expire pending claims',
    });
  }
});

module.exports = router;