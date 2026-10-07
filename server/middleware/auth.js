const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || 'resqnet_jwt_secret_dev_key_2026';

/**
 * Reusable JWT Authentication Middleware
 */
const requireAuth = (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({
      success: false,
      message: 'Unauthorized: Authentication token is required'
    });
  }

  const token = authHeader.split(' ')[1];
  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = decoded; // { id, email, role, name, responder_id }
    next();
  } catch (err) {
    return res.status(401).json({
      success: false,
      message: 'Unauthorized: Invalid or expired token'
    });
  }
};

/**
 * Reusable Role Authorization Middleware
 * Example: requireRole('ADMIN'), requireRole('ADMIN', 'RESPONDER')
 */
const requireRole = (...allowedRoles) => {
  return (req, res, next) => {
    if (!req.user || !req.user.role) {
      return res.status(401).json({
        success: false,
        message: 'Unauthorized: User role not authenticated'
      });
    }

    if (!allowedRoles.includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        message: `Forbidden: Insufficient role permissions. Allowed: ${allowedRoles.join(', ')} (Your role: ${req.user.role})`
      });
    }

    next();
  };
};

module.exports = {
  requireAuth,
  requireRole,
  JWT_SECRET
};
