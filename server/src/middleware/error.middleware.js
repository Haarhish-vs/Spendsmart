const ApiResponse = require('../utils/api-response');
const logger = require('../utils/logger');

/**
 * Centralized Express error-handling middleware
 */
const errorMiddleware = (err, req, res, next) => {
  logger.error(err.message || 'Unhandled Server Error', {
    stack: err.stack,
    path: req.originalUrl,
    method: req.method,
  });

  const statusCode = err.statusCode || 500;
  const message = err.message || 'Internal Server Error';
  const errors = err.errors || null;

  ApiResponse.error(res, message, statusCode, errors);
};

module.exports = errorMiddleware;
