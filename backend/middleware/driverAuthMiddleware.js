// middleware/driverAuthMiddleware.js
const jwt = require("jsonwebtoken");

module.exports = (req, res, next) => {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return res.status(401).json({ 
      success: false, 
      message: "No token provided" 
    });
  }

  const token = authHeader.split(" ")[1];

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    // Check if the user is a driver
    // Assuming your JWT payload has a 'role' field or 'isDriver' flag
    if (decoded.role !== "driver" && !decoded.isDriver) {
      return res.status(403).json({ 
        success: false, 
        message: "Access denied. Driver role required." 
      });
    }

    // Attach driver info to request
    req.driver = {
      id: decoded.id || decoded.userId,
      role: decoded.role,
    };
    
    next();
  } catch (error) {
    return res.status(401).json({ 
      success: false, 
      message: "Invalid token" 
    });
  }
};