const ApiResponse = require('../utils/api-response');
const asyncHandler = require('../utils/async-handler');

/**
 * Auth controller placeholder
 */
const authController = {
  login: asyncHandler(async (req, res) => {
    return ApiResponse.success(res, null, 'Login endpoint placeholder');
  }),
  register: asyncHandler(async (req, res) => {
    return ApiResponse.success(res, null, 'Register endpoint placeholder');
  }),
};

module.exports = authController;
