// routes/adminFood.js
const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/auth');
const Restaurant = require('../models/mongodb/Restaurant');
const MenuItem = require('../models/mongodb/MenuItem');
const MenuCategory = require('../models/mongodb/MenuCategory');
const FoodOrder = require('../models/mongodb/FoodOrder');

/* ====================================
   RESTAURANT MANAGEMENT
==================================== */

// POST /api/admin/food/restaurants - Create restaurant
router.post('/restaurants', authMiddleware, async (req, res) => {
  try {
    const restaurant = await Restaurant.create(req.body);
    return res.json({ success: true, restaurant });
  } catch (err) {
    console.error('Create Restaurant Error:', err);
    return res.status(500).json({
      success: false,
      message: 'Failed to create restaurant',
    });
  }
});

// PUT /api/admin/food/restaurants/:id - Update restaurant
router.put('/restaurants/:id', authMiddleware, async (req, res) => {
  try {
    const restaurant = await Restaurant.findByIdAndUpdate(
      req.params.id,
      req.body,
      { new: true }
    );

    if (!restaurant) {
      return res.status(404).json({
        success: false,
        message: 'Restaurant not found',
      });
    }

    return res.json({ success: true, restaurant });
  } catch (err) {
    console.error('Update Restaurant Error:', err);
    return res.status(500).json({
      success: false,
      message: 'Failed to update restaurant',
    });
  }
});

// DELETE /api/admin/food/restaurants/:id - Delete restaurant
router.delete('/restaurants/:id', authMiddleware, async (req, res) => {
  try {
    await Restaurant.findByIdAndDelete(req.params.id);
    return res.json({ success: true });
  } catch (err) {
    console.error('Delete Restaurant Error:', err);
    return res.status(500).json({
      success: false,
      message: 'Failed to delete restaurant',
    });
  }
});

/* ====================================
   MENU CATEGORY MANAGEMENT
==================================== */

// POST /api/admin/food/restaurants/:id/categories
router.post('/restaurants/:id/categories', authMiddleware, async (req, res) => {
  try {
    const category = await MenuCategory.create({
      restaurantId: req.params.id,
      ...req.body,
    });

    return res.json({ success: true, category });
  } catch (err) {
    console.error('Create Category Error:', err);
    return res.status(500).json({
      success: false,
      message: 'Failed to create category',
    });
  }
});

// PUT /api/admin/food/categories/:id
router.put('/categories/:id', authMiddleware, async (req, res) => {
  try {
    const category = await MenuCategory.findByIdAndUpdate(
      req.params.id,
      req.body,
      { new: true }
    );

    if (!category) {
      return res.status(404).json({
        success: false,
        message: 'Category not found',
      });
    }

    return res.json({ success: true, category });
  } catch (err) {
    console.error('Update Category Error:', err);
    return res.status(500).json({
      success: false,
      message: 'Failed to update category',
    });
  }
});

/* ====================================
   MENU ITEM MANAGEMENT
==================================== */

// POST /api/admin/food/restaurants/:id/items - Add menu item
router.post('/restaurants/:id/items', authMiddleware, async (req, res) => {
  try {
    const item = await MenuItem.create({
      restaurantId: req.params.id,
      ...req.body,
    });

    return res.json({ success: true, item });
  } catch (err) {
    console.error('Create Menu Item Error:', err);
    return res.status(500).json({
      success: false,
      message: 'Failed to create menu item',
    });
  }
});

// PUT /api/admin/food/items/:id - Update menu item
router.put('/items/:id', authMiddleware, async (req, res) => {
  try {
    const item = await MenuItem.findByIdAndUpdate(req.params.id, req.body, {
      new: true,
    });

    if (!item) {
      return res.status(404).json({
        success: false,
        message: 'Menu item not found',
      });
    }

    return res.json({ success: true, item });
  } catch (err) {
    console.error('Update Menu Item Error:', err);
    return res.status(500).json({
      success: false,
      message: 'Failed to update menu item',
    });
  }
});

// DELETE /api/admin/food/items/:id - Delete menu item
router.delete('/items/:id', authMiddleware, async (req, res) => {
  try {
    await MenuItem.findByIdAndDelete(req.params.id);
    return res.json({ success: true });
  } catch (err) {
    console.error('Delete Menu Item Error:', err);
    return res.status(500).json({
      success: false,
      message: 'Failed to delete menu item',
    });
  }
});

/* ====================================
   ORDER MANAGEMENT
==================================== */

// GET /api/admin/food/orders - List all orders
router.get('/orders', authMiddleware, async (req, res) => {
  try {
    const { status, restaurantId } = req.query;

    let query = {};

    if (status) {
      query.status = status;
    }

    if (restaurantId) {
      query.restaurantId = restaurantId;
    }

    const orders = await FoodOrder.find(query)
      .populate('userId', 'name phone')
      .populate('restaurantId', 'name location')
      .populate('assignedDriverId', 'name phone')
      .sort({ createdAt: -1 })
      .lean();

    return res.json({ success: true, orders });
  } catch (err) {
    console.error('Get Orders Error:', err);
    return res.status(500).json({
      success: false,
      message: 'Failed to fetch orders',
    });
  }
});

// PATCH /api/admin/food/orders/:id/status - Update order status
router.patch('/orders/:id/status', authMiddleware, async (req, res) => {
  try {
    const { status } = req.body;

    const validStatuses = [
      'placed',
      'accepted',
      'preparing',
      'ready_for_pickup',
      'picked_up',
      'on_the_way',
      'delivered',
      'cancelled',
    ];

    if (!validStatuses.includes(status)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid status',
      });
    }

    const order = await FoodOrder.findById(req.params.id);

    if (!order) {
      return res.status(404).json({
        success: false,
        message: 'Order not found',
      });
    }

    order.status = status;

    // Set timestamps
    if (status === 'accepted' && !order.acceptedAt) {
      order.acceptedAt = new Date();
    } else if (status === 'preparing' && !order.preparingAt) {
      order.preparingAt = new Date();
    } else if (status === 'picked_up' && !order.pickedUpAt) {
      order.pickedUpAt = new Date();
    } else if (status === 'delivered' && !order.deliveredAt) {
      order.deliveredAt = new Date();
    }

    await order.save();

    return res.json({ success: true, order });
  } catch (err) {
    console.error('Update Order Status Error:', err);
    return res.status(500).json({
      success: false,
      message: 'Failed to update order status',
    });
  }
});

module.exports = router;