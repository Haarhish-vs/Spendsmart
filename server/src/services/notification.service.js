const notificationRepository = require('../repositories/notification.repository');
const fcmService = require('../integrations/firebase/fcm.service');

class NotificationService {
  /**
   * Register or refresh a user's FCM device token
   */
  async registerDeviceToken({ userId, token, platform = 'android' }) {
    if (!userId || !token) {
      throw new Error('userId and token are required');
    }
    return await notificationRepository.upsertDeviceToken(userId, token, platform);
  }

  /**
   * Get user notifications list
   */
  async getUserNotifications(userId) {
    return await notificationRepository.getUserNotifications(userId);
  }

  /**
   * Mark notification as read
   */
  async markAsRead(id, userId) {
    return await notificationRepository.markAsRead(id, userId);
  }

  /**
   * Send a test push notification to verify device receipt
   */
  async sendTestPushNotification({ userId, title = 'SpendSmart Test', body = 'Firebase push notification test.' }) {
    const tokens = await notificationRepository.getActiveTokensForUser(userId);
    if (!tokens || tokens.length === 0) {
      return { success: false, message: 'No registered FCM device tokens found for this user.' };
    }

    const pushResult = await fcmService.sendPushNotification({
      tokens,
      title,
      body,
      data: { notification_type: 'test_notification', route: '/budgets' },
    });

    if (pushResult.invalidTokens && pushResult.invalidTokens.length > 0) {
      await notificationRepository.deactivateTokens(pushResult.invalidTokens);
    }

    return pushResult;
  }
}

module.exports = new NotificationService();
