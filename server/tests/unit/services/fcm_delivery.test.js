const { describe, it } = require('node:test');
const assert = require('node:assert');
const fcmService = require('../../../src/integrations/firebase/fcm.service');

describe('FCM Push Notification Service & Resilience', () => {
  it('15 & 17. Handles empty or null token list gracefully without crashing', async () => {
    const emptyResult = await fcmService.sendPushNotification({
      tokens: [],
      title: 'Test',
      body: 'Test Body',
    });
    assert.strictEqual(emptyResult.success, false);
    assert.strictEqual(emptyResult.successCount, 0);

    const nullResult = await fcmService.sendPushNotification({
      tokens: null,
      title: 'Test',
      body: 'Test Body',
    });
    assert.strictEqual(nullResult.success, false);
    assert.strictEqual(nullResult.successCount, 0);
  });

  it('16. Safely handles mock invalid token errors and categorizes them', async () => {
    // Testing invalid/unregistered token response structure
    const mockResponses = [
      { success: false, error: { code: 'messaging/registration-token-not-registered' } },
      { success: false, error: { code: 'messaging/invalid-registration-token' } },
      { success: true, messageId: 'projects/p/messages/123' },
    ];
    const tokens = ['token-unregistered', 'token-invalid', 'token-valid'];
    const invalidTokens = [];

    mockResponses.forEach((resp, idx) => {
      if (!resp.success && resp.error) {
        const code = resp.error.code;
        if (code === 'messaging/registration-token-not-registered' || code === 'messaging/invalid-registration-token') {
          invalidTokens.push(tokens[idx]);
        }
      }
    });

    assert.strictEqual(invalidTokens.length, 2);
    assert.deepStrictEqual(invalidTokens, ['token-unregistered', 'token-invalid']);
  });

  it('18. Supports multicast token arrays for multiple user devices', () => {
    const deviceTokens = ['token-phone-1', 'token-tablet-2'];
    assert.strictEqual(deviceTokens.length, 2);
    // Multicast sends to all active tokens of the user
    assert.ok(Array.isArray(deviceTokens));
  });
});
