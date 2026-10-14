const ApiResponse = require('../utils/api-response');

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

/**
 * Request validation middleware for authentication routes
 */
const authValidator = {
  /**
   * Validate user registration payload
   */
  validateRegister: (req, res, next) => {
    const { fullName, email, password } = req.body || {};
    const errors = {};

    if (!fullName || typeof fullName !== 'string' || fullName.trim().length < 2) {
      errors.fullName = 'Full name is required and must be at least 2 characters';
    }

    if (!email || typeof email !== 'string' || !EMAIL_REGEX.test(email.trim())) {
      errors.email = 'A valid email address is required';
    }

    if (!password || typeof password !== 'string' || password.length < 6) {
      errors.password = 'Password is required and must be at least 6 characters';
    }

    if (Object.keys(errors).length > 0) {
      return ApiResponse.error(res, 'Validation failed: Please check your input fields', 400, errors);
    }

    next();
  },

  /**
   * Validate user login payload
   */
  validateLogin: (req, res, next) => {
    const { email, password } = req.body || {};
    const errors = {};

    if (!email || typeof email !== 'string' || !EMAIL_REGEX.test(email.trim())) {
      errors.email = 'A valid email address is required';
    }

    if (!password || typeof password !== 'string' || password.length === 0) {
      errors.password = 'Password is required';
    }

    if (Object.keys(errors).length > 0) {
      return ApiResponse.error(res, 'Validation failed: Please check your input fields', 400, errors);
    }

    next();
  },
};

module.exports = authValidator;
