const jwt = require('jsonwebtoken');
const env = require('../config/env');
const ApiResponse = require('../utils/api-response');

/**
 * Reusable JWT Authentication Middleware
 * Validates Bearer token, sets authenticated user context,
 * and enforces strict cross-user ownership isolation.
 */
const authMiddleware = (req, res, next) => {
  const authHeader = req.headers.authorization;

  if (!authHeader) {
    return ApiResponse.error(res, 'No authorization token provided', 401);
  }

  const parts = authHeader.split(' ');
  if (parts.length !== 2 || parts[0].toLowerCase() !== 'bearer') {
    return ApiResponse.error(res, 'Malformed authorization header. Expected format: Bearer <token>', 401);
  }

  const token = parts[1];

  try {
    const decoded = jwt.verify(token, env.jwtSecret);
    const userId = decoded.sub || decoded.id;

    if (!userId) {
      return ApiResponse.error(res, 'Invalid token: missing subject identity', 401);
    }

    req.user = {
      id: userId,
      email: decoded.email,
      fullName: decoded.full_name || decoded.name,
    };
    req.userId = userId;

    // Reject cross-user resource access if target userId in URL param doesn't match token identity
    if (req.params.userId && req.params.userId !== req.userId) {
      return ApiResponse.error(res, 'Access denied: You cannot access or modify records of another user', 403);
    }

    // Never trust client-supplied userId in body - enforce token identity
    if (req.body && typeof req.body === 'object') {
      if (req.body.user_id !== undefined) {
        req.body.user_id = req.userId;
      }
      if (req.body.userId !== undefined) {
        req.body.userId = req.userId;
      }
    }

    next();
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return ApiResponse.error(res, 'Authorization token has expired', 401);
    }
    return ApiResponse.error(res, 'Invalid or malformed authorization token', 401);
  }
};

module.exports = authMiddleware;
