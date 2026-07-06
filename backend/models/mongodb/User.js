// models/User.js
const mongoose = require("mongoose");
const bcrypt = require("bcryptjs");

const userSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: [true, "Name is required"],
      trim: true,
    },

    email: {
      type: String,
      required: [true, "Email is required"],
      unique: true,
      lowercase: true,
      trim: true,
      match: [/^\S+@\S+\.\S+$/, "Please provide a valid email"],
    },

    phone: {
      type: String,
      required: [true, "Phone number is required"],
      unique: true,
      match: [/^[0-9]{10}$/, "Please provide a valid 10-digit phone number"],
    },

    password: {
      type: String,
      required: [true, "Password is required"],
      minlength: 6,
      select: false,
    },

    profilePicture: {
      type: String,
      default: "https://ui-avatars.com/api/?background=random&name=",
    },

    isVerified: { type: Boolean, default: false },

    otp: { type: String, select: false },
    otpExpiry: { type: Date, select: false },

    totalRides: { type: Number, default: 0 },

    rating: {
      type: Number,
      default: 5.0,
      min: 1,
      max: 5,
    },

    // ⭐ ADDED → FCM Token for push notifications
    fcmToken: {
      type: String,
      default: null,
    },

    createdAt: { type: Date, default: Date.now },
  },
  {
    timestamps: true,
  }
);

// Hash password if modified
userSchema.pre("save", async function (next) {
  if (!this.isModified("password")) return next();
  this.password = await bcrypt.hash(this.password, 12);
  next();
});

// Compare password
userSchema.methods.comparePassword = async function (candidatePassword) {
  return await bcrypt.compare(candidatePassword, this.password);
};

// Auto-generate profile pic URL
userSchema.pre("save", function (next) {
  if (!this.profilePicture.includes("ui-avatars")) {
    this.profilePicture = `https://ui-avatars.com/api/?background=random&name=${this.name}`;
  }
  next();
});

module.exports = mongoose.model("User", userSchema);
