const ApiResponse = require('../utils/api-response');
const asyncHandler = require('../utils/async-handler');

/**
 * Notification controller placeholder
 */
const notificationController = {
  getAll: asyncHandler(async (req, res) => {
    return ApiResponse.success(res, [], 'Get notifications endpoint placeholder');
  }),
  markAsRead: asyncHandler(async (req, res) => {
    return ApiResponse.success(res, null, 'Mark notification as read endpoint placeholder');
  }),
};

module.exports = notificationController;
