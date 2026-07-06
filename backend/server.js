const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');

require('dotenv').config();

const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// ✅ IMPORT ORDER PROGRESSION SERVICE
const orderProgressionService = require('./services/orderProgressionService');

// Route imports
const authRoutes = require('./routes/auth');
const rideRoutes = require('./routes/cabride');
const paymentRoutes = require('./routes/payment');
const adminRoutes = require('./routes/admin');
const userRoutes = require('./routes/user');
const foodRoutes = require('./routes/food');
const driverFoodRoutes = require('./routes/driverFood');
const adminFoodRoutes = require('./routes/adminFood');

// Route mapping
app.use('/api/auth', authRoutes);
app.use('/api/cabride', rideRoutes);
app.use('/api/payment', paymentRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/user', userRoutes);
app.use('/api/food', foodRoutes);
app.use('/api/driver/food', driverFoodRoutes);
app.use('/api/admin/food', adminFoodRoutes);

// Health check
app.get('/', (req, res) => {
  res.json({ message: 'TRACE Backend API is running!' });
});

// MongoDB Connection
mongoose.connect(process.env.MONGO_URI)
  .then(async () => {
    console.log('✅ MongoDB Connected');
    
    // ✅ START AUTO-PROGRESSION FOR ANY PENDING ORDERS ON SERVER START
    console.log('🔄 Checking for pending orders to auto-progress...');
    await orderProgressionService.startAllPendingOrders();
  })
  .catch(err => console.error('❌ MongoDB Error:', err));

// Start Server
const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
});