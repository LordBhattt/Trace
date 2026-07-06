// models/MenuCategory.js
const mongoose = require('mongoose');

const menuCategorySchema = new mongoose.Schema(
  {
    restaurantId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Restaurant',
      required: true,
    },
    name: {
      type: String,
      required: true,
    },
    description: {
      type: String,
    },

    // Controls ordering in the menu (0,1,2,...)
    displayOrder: {
      type: Number,
      default: 0,
    },

    isAvailable: {
      type: Boolean,
      default: true,
    },

    // Optional: time-based availability (eg. breakfast)
    availableFrom: {
      type: String, // "09:00"
    },
    availableTo: {
      type: String, // "12:00"
    },
  },
  {
    timestamps: true,
  }
);

menuCategorySchema.index({ restaurantId: 1, displayOrder: 1 });

const MenuCategory = mongoose.model('MenuCategory', menuCategorySchema);

module.exports = MenuCategory;
