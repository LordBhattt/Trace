const express = require('express');
const router = express.Router();
const FoodOrder = require('../models/mongodb/FoodOrder');
const driverAuthMiddleware = require('../middleware/driverAuthMiddleware'); // Assuming this exists

// ========== GET ASSIGNED FOOD ORDERS ==========

router.get('/orders', driverAuthMiddleware, async (req, res) => {
  try {
    const orders = await FoodOrder.find({
      assignedDriverId: req.driver.id,
      status: { $in: ['accepted', 'preparing', 'ready_for_pickup', 'picked_up', 'on_the_way'] }
    })
      .populate('restaurantId', 'name location address')
      .populate('userId', 'name phone')
      .sort({ createdAt: -1 });
    
    res.json(orders);
  } catch (error) {
    console.error('Error fetching driver orders:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// ========== GET SINGLE ORDER DETAILS ==========

router.get('/orders/:id', driverAuthMiddleware, async (req, res) => {
  try {
    const order = await FoodOrder.findById(req.params.id)
      .populate('restaurantId')
      .populate('userId', 'name phone');
    
    if (!order) {
      return res.status(404).json({ message: 'Order not found' });
    }
    
    if (order.assignedDriverId.toString() !== req.driver.id) {
      return res.status(403).json({ message: 'Not assigned to you' });
    }
    
    res.json(order);
  } catch (error) {
    console.error('Error fetching order:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// ========== UPDATE ORDER STATUS ==========

router.patch('/orders/:id/status', driverAuthMiddleware, async (req, res) => {
  try {
    const { status } = req.body;
    const order = await FoodOrder.findById(req.params.id);
    
    if (!order) {
      return res.status(404).json({ message: 'Order not found' });
    }
    
    if (order.assignedDriverId.toString() !== req.driver.id) {
      return res.status(403).json({ message: 'Not assigned to you' });
    }
    
    // Validate state transitions
    const validTransitions = {
      'accepted': ['preparing'],
      'preparing': ['ready_for_pickup'],
      'ready_for_pickup': ['picked_up'],
      'picked_up': ['on_the_way'],
      'on_the_way': ['delivered']
    };
    
    if (!validTransitions[order.status] || !validTransitions[order.status].includes(status)) {
      return res.status(400).json({ message: 'Invalid status transition' });
    }
    
    order.status = status;
    
    // Update timestamps
    switch (status) {
      case 'preparing':
        order.preparingAt = new Date();
        break;
      case 'ready_for_pickup':
        order.readyForPickupAt = new Date();
        break;
      case 'on_the_way':
        order.onTheWayAt = new Date();
        break;
    }
    
    await order.save();
    
    res.json({ message: 'Status updated', order });
  } catch (error) {
    console.error('Error updating status:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// ========== CONFIRM PICKUP (WITH OTP) ==========

router.post('/orders/:id/pickup', driverAuthMiddleware, async (req, res) => {
  try {
    const { otp } = req.body;
    const order = await FoodOrder.findById(req.params.id);
    
    if (!order) {
      return res.status(404).json({ message: 'Order not found' });
    }
    
    if (order.assignedDriverId.toString() !== req.driver.id) {
      return res.status(403).json({ message: 'Not assigned to you' });
    }
    
    if (order.status !== 'ready_for_pickup') {
      return res.status(400).json({ message: 'Order not ready for pickup' });
    }
    
    // Verify OTP
    if (order.otpPickup !== otp) {
      return res.status(400).json({ message: 'Invalid OTP' });
    }
    
    order.status = 'picked_up';
    order.pickedUpAt = new Date();
    await order.save();
    
    res.json({ message: 'Pickup confirmed', order });
  } catch (error) {
    console.error('Error confirming pickup:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// ========== CONFIRM DELIVERY (WITH OTP) ==========

router.post('/orders/:id/deliver', driverAuthMiddleware, async (req, res) => {
  try {
    const { otp } = req.body;
    const order = await FoodOrder.findById(req.params.id);
    
    if (!order) {
      return res.status(404).json({ message: 'Order not found' });
    }
    
    if (order.assignedDriverId.toString() !== req.driver.id) {
      return res.status(403).json({ message: 'Not assigned to you' });
    }
    
    if (order.status !== 'on_the_way') {
      return res.status(400).json({ message: 'Order not on the way' });
    }
    
    // Verify OTP
    if (order.otpDrop !== otp) {
      return res.status(400).json({ message: 'Invalid OTP' });
    }
    
    order.status = 'delivered';
    order.deliveredAt = new Date();
    await order.save();
    
    res.json({ message: 'Delivery confirmed', order });
  } catch (error) {
    console.error('Error confirming delivery:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;