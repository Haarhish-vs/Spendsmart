const ApiResponse = require('../utils/api-response');
const asyncHandler = require('../utils/async-handler');

/**
 * AI Plan controller placeholder
 */
const aiPlanController = {
  getPlan: asyncHandler(async (req, res) => {
    return ApiResponse.success(res, null, 'Get AI plan endpoint placeholder');
  }),
  generatePlan: asyncHandler(async (req, res) => {
    return ApiResponse.success(res, null, 'Generate AI plan endpoint placeholder', 201);
  }),
};

module.exports = aiPlanController;
