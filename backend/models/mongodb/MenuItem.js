// models/MenuItem.js
const mongoose = require('mongoose');

const menuItemSchema = new mongoose.Schema(
  {
    restaurantId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Restaurant',
      required: true,
    },
    categoryId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'MenuCategory',
      required: true,
    },

    // Human-readable category label (eg. "Pizza", "Burger")
    category: {
      type: String,
      required: true,
    },

    name: {
      type: String,
      required: true,
      trim: true,
    },

    description: {
      type: String,
      default: '',
    },

    price: {
      type: Number,
      required: true,
      min: 0,
    },

    imageUrl: {
      type: String,
      default: 'https://via.placeholder.com/300?text=Food',
    },

    isVeg: {
      type: Boolean,
      default: true,
    },

    isAvailable: {
      type: Boolean,
      default: true,
    },

    // Tags for filters / badges: ["bestseller", "spicy", "pizza"]
    tags: {
      type: [String],
      default: [],
    },

    // Add-ons for the item (e.g., extra cheese)
    addOns: [
      {
        label: String,
        price: Number,
      },
    ],

    rating: {
      type: Number,
      default: 4.0,
      min: 0,
      max: 5,
    },

    ordersCount: {
      type: Number,
      default: 0,
    },
  },
  {
    timestamps: true,
  }
);

menuItemSchema.index({ restaurantId: 1, categoryId: 1 });
menuItemSchema.index({ tags: 1 });
menuItemSchema.index({ name: 'text', description: 'text' });

module.exports = mongoose.model('MenuItem', menuItemSchema);
