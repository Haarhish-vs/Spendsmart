const notificationService = require('../services/notification.service');

const registerDeviceToken = async (req, res) => {
  try {
    const { userId, user_id, token, platform = 'android' } = req.body;
    const resolvedUserId = userId || user_id;

    if (!resolvedUserId || !token) {
      return res.status(400).json({
        success: false,
        message: 'userId and token are required',
      });
    }

    const result = await notificationService.registerDeviceToken({
      userId: resolvedUserId,
      token,
      platform,
    });

    return res.status(200).json({
      success: true,
      message: 'Device token registered successfully',
      data: result,
    });
  } catch (error) {
    return res.status(error.status || 500).json({
      success: false,
      message: error.message || 'Failed to register device token',
    });
  }
};

const getAll = async (req, res) => {
  try {
    const userId = req.params.userId || req.query.userId;
    if (!userId) {
      return res.status(400).json({
        success: false,
        message: 'userId is required',
      });
    }

    const notifications = await notificationService.getUserNotifications(userId);

    return res.status(200).json({
      success: true,
      data: notifications,
    });
  } catch (error) {
    return res.status(error.status || 500).json({
      success: false,
      message: error.message || 'Failed to fetch notifications',
    });
  }
};

const markAsRead = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.query.userId || req.body.userId;
    const notification = await notificationService.markAsRead(id, userId);

    return res.status(200).json({
      success: true,
      data: notification,
    });
  } catch (error) {
    return res.status(error.status || 500).json({
      success: false,
      message: error.message || 'Failed to update notification',
    });
  }
};

const sendTestPush = async (req, res) => {
  try {
    const { userId, user_id, title, body } = req.body;
    const resolvedUserId = userId || user_id;

    if (!resolvedUserId) {
      return res.status(400).json({
        success: false,
        message: 'userId is required',
      });
    }

    const result = await notificationService.sendTestPushNotification({
      userId: resolvedUserId,
      title,
      body,
    });

    return res.status(200).json({
      success: result.success,
      message: result.success ? 'Push notification delivered' : (result.message || 'Push delivery failed'),
      data: result,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message || 'Test push notification error',
    });
  }
};

module.exports = {
  registerDeviceToken,
  getAll,
  markAsRead,
  sendTestPush,
};
