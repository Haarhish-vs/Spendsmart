const authService = require('../services/auth.service');
const ApiResponse = require('../utils/api-response');
const asyncHandler = require('../utils/async-handler');

/**
 * Controller handling user registration, authentication, and session retrieval
 */
const authController = {
  /**
   * Handle user registration
   * POST /api/v1/auth/register
   */
  register: asyncHandler(async (req, res) => {
    const { fullName, email, password } = req.body;
    const result = await authService.register({ fullName, email, password });
    return ApiResponse.success(res, result, 'User registered successfully', 201);
  }),

  /**
   * Handle user login
   * POST /api/v1/auth/login
   */
  login: asyncHandler(async (req, res) => {
    const { email, password } = req.body;
    const result = await authService.login({ email, password });
    return ApiResponse.success(res, result, 'Login successful', 200);
  }),

  /**
   * Retrieve current authenticated user profile
   * GET /api/v1/auth/me
   */
  getCurrentUser: asyncHandler(async (req, res) => {
    const user = await authService.getCurrentUser(req.userId);
    return ApiResponse.success(res, user, 'User profile retrieved successfully', 200);
  }),
};

module.exports = authController;
