// models/Admin.js
const mongoose = require("mongoose");

const AdminSchema = new mongoose.Schema(
  {
    username: { type: String, required: true },
    password: { type: String, required: true }, // hashed later if needed
  },
  { timestamps: true }
);

module.exports = mongoose.model("Admin", AdminSchema);
