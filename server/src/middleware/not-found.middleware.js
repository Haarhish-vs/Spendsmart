const ApiResponse = require('../utils/api-response');

/**
 * 404 Not Found route handler middleware
 */
const notFoundMiddleware = (req, res, next) => {
  ApiResponse.error(res, `Route ${req.method} ${req.originalUrl} not found`, 404);
};

module.exports = notFoundMiddleware;
