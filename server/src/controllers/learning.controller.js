const ApiResponse = require('../utils/api-response');
const asyncHandler = require('../utils/async-handler');

/**
 * Learning controller placeholder
 */
const learningController = {
  getResources: asyncHandler(async (req, res) => {
    return ApiResponse.success(res, [], 'Get learning resources endpoint placeholder');
  }),
};

module.exports = learningController;
