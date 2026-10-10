const { getMessagingClient } = require('./firebase.client');

/**
 * FCM Push Notification Delivery Service
 */
class FcmService {
  /**
   * Send FCM push notification to one or more device tokens
   * @param {Object} params
   * @param {string[]} params.tokens - Array of target FCM tokens
   * @param {string} params.title - Notification title
   * @param {string} params.body - Notification body text
   * @param {Object} [params.data] - Key-value string map for deep linking / routing
   * @returns {Promise<{ success: boolean, successCount: number, failureCount: number, invalidTokens: string[] }>}
   */
  async sendPushNotification({ tokens = [], title, body, data = {} }) {
    if (!tokens || tokens.length === 0) {
      return { success: false, successCount: 0, failureCount: 0, invalidTokens: [], reason: 'NO_TOKENS' };
    }

    const messaging = getMessagingClient();
    if (!messaging) {
      console.warn('FCM Service: Push skipped because Firebase Admin messaging is not configured.');
      return { success: false, successCount: 0, failureCount: 0, invalidTokens: [], reason: 'FIREBASE_NOT_CONFIGURED' };
    }

    // Ensure all data payload values are strings (required by FCM data payload)
    const stringifiedData = {};
    for (const [k, v] of Object.entries(data)) {
      stringifiedData[k] = v !== null && v !== undefined ? String(v) : '';
    }

    // Build Multicast Message
    const message = {
      tokens,
      notification: {
        title,
        body,
      },
      data: stringifiedData,
      android: {
        priority: 'high',
        notification: {
          channelId: 'budget_alerts_channel',
          sound: 'default',
          color: '#232C54',
          priority: 'high',
        },
      },
    };

    try {
      const response = await messaging.sendEachForMulticast(message);

      const invalidTokens = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success && resp.error) {
          const errorCode = resp.error.code;
          if (
            errorCode === 'messaging/invalid-registration-token' ||
            errorCode === 'messaging/registration-token-not-registered'
          ) {
            invalidTokens.push(tokens[idx]);
          }
          console.warn(`FCM delivery failed for token index ${idx}: ${resp.error.message} (${errorCode})`);
        }
      });

      return {
        success: response.successCount > 0,
        successCount: response.successCount,
        failureCount: response.failureCount,
        invalidTokens,
      };
    } catch (error) {
      console.error('FCM Multicast error (non-fatal):', error.message);
      return {
        success: false,
        successCount: 0,
        failureCount: tokens.length,
        invalidTokens: [],
        error: error.message,
      };
    }
  }
}

module.exports = new FcmService();
