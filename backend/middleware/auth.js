// middleware/authMiddleware.js
const jwt = require("jsonwebtoken");

function authMiddleware(req, res, next) {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return res
      .status(401)
      .json({ success: false, message: "No token provided" });
  }

  const token = authHeader.split(" ")[1];

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    /*
      🔑 NORMALIZE USER DATA FOR ALL MODULES (CAB + FOOD + RESELL)
      auth.js signs: { id: user._id }
    */
    req.user = decoded;
    req.userId = decoded.id; // ✅ THIS WAS MISSING

    if (!req.userId) {
      return res
        .status(401)
        .json({ success: false, message: "Invalid token payload" });
    }

    next();
  } catch (error) {
    return res
      .status(401)
      .json({ success: false, message: "Invalid token" });
  }
}

module.exports = authMiddleware;
