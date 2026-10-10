const ApiResponse = require('../utils/api-response');
const asyncHandler = require('../utils/async-handler');

/**
 * Dashboard controller placeholder
 */
const dashboardController = {
  getSummary: asyncHandler(async (req, res) => {
    return ApiResponse.success(res, null, 'Dashboard summary endpoint placeholder');
  }),
};

module.exports = dashboardController;
