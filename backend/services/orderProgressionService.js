// backend/services/orderProgressionService.js
// This service automatically progresses orders through statuses

const FoodOrder = require('../models/mongodb/FoodOrder');

class OrderProgressionService {
  constructor() {
    this.intervals = new Map();
  }

  // Start auto-progression for an order
  startAutoProgression(orderId) {
    if (this.intervals.has(orderId)) {
      return; // Already running
    }

    console.log(`🚀 Starting auto-progression for order: ${orderId}`);

    const progressOrder = async () => {
      try {
        const order = await FoodOrder.findById(orderId);
        
        if (!order) {
          this.stopAutoProgression(orderId);
          return;
        }

        // Status progression with realistic timings
        const statusProgression = {
          'placed': { next: 'accepted', delay: 10000 },           // 10 seconds - restaurant accepts
          'accepted': { next: 'preparing', delay: 15000 },        // 15 seconds - start cooking
          'preparing': { next: 'ready_for_pickup', delay: 120000 }, // 2 minutes - food ready
          'ready_for_pickup': { next: 'picked_up', delay: 30000 }, // 30 seconds - driver picks up
          'picked_up': { next: 'on_the_way', delay: 10000 },      // 10 seconds - start delivery
          'on_the_way': { next: 'delivered', delay: 180000 },     // 3 minutes - deliver
        };

        const currentStatus = order.status;
        const progression = statusProgression[currentStatus];

        if (!progression) {
          // Order is complete, cancelled, or in unknown state
          this.stopAutoProgression(orderId);
          return;
        }

        console.log(`📦 Order ${orderId}: ${currentStatus} → ${progression.next} (in ${progression.delay/1000}s)`);

        // Schedule next status update
        setTimeout(async () => {
          try {
            const updatedOrder = await FoodOrder.findById(orderId);
            
            // Only progress if order is still in expected status (not cancelled)
            if (updatedOrder && updatedOrder.status === currentStatus && !updatedOrder.isCancelled) {
              updatedOrder.status = progression.next;
              
              // Set timestamp fields based on status
              if (progression.next === 'accepted') {
                updatedOrder.acceptedAt = new Date();
              } else if (progression.next === 'preparing') {
                updatedOrder.preparingAt = new Date();
              } else if (progression.next === 'ready_for_pickup') {
                updatedOrder.readyAt = new Date();
              } else if (progression.next === 'picked_up') {
                updatedOrder.pickedUpAt = new Date();
              } else if (progression.next === 'delivered') {
                updatedOrder.deliveredAt = new Date();
              }
              
              await updatedOrder.save();
              console.log(`✅ Order ${orderId} updated to: ${progression.next}`);
              
              // Continue progression
              progressOrder();
            } else {
              console.log(`⏹️  Order ${orderId} was modified or cancelled, stopping progression`);
              this.stopAutoProgression(orderId);
            }
          } catch (error) {
            console.error(`❌ Error updating order ${orderId}:`, error);
            this.stopAutoProgression(orderId);
          }
        }, progression.delay);

      } catch (error) {
        console.error(`❌ Error in progression for ${orderId}:`, error);
        this.stopAutoProgression(orderId);
      }
    };

    progressOrder();
    this.intervals.set(orderId, true);
  }

  stopAutoProgression(orderId) {
    if (this.intervals.has(orderId)) {
      this.intervals.delete(orderId);
      console.log(`⏹️  Stopped auto-progression for order: ${orderId}`);
    }
  }

  // Start progression for all pending orders (useful on server restart)
  async startAllPendingOrders() {
    try {
      const pendingOrders = await FoodOrder.find({
        status: { 
          $in: ['placed', 'accepted', 'preparing', 'ready_for_pickup', 'picked_up', 'on_the_way'] 
        },
        isCancelled: false,
      });

      console.log(`🔄 Found ${pendingOrders.length} pending orders to auto-progress`);

      for (const order of pendingOrders) {
        this.startAutoProgression(order._id.toString());
      }
    } catch (error) {
      console.error('❌ Error starting pending orders:', error);
    }
  }
}

// Singleton instance
const orderProgressionService = new OrderProgressionService();

module.exports = orderProgressionService;