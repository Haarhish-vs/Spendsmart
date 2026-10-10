const supabase = require('../config/supabase');

class NotificationRepository {
  /**
   * Upsert a user device token for FCM notifications
   */
  async upsertDeviceToken(userId, token, platform = 'android') {
    if (!userId || !token) throw new Error('userId and token are required');

    // Check if token exists
    const { data: existing } = await supabase
      .from('device_tokens')
      .select('id, user_id, is_active')
      .eq('token', token)
      .maybeSingle();

    if (existing) {
      const { data, error } = await supabase
        .from('device_tokens')
        .update({
          user_id: userId,
          platform: platform || 'android',
          is_active: true,
          updated_at: new Date().toISOString(),
        })
        .eq('id', existing.id)
        .select()
        .single();

      if (error) throw error;
      return data;
    } else {
      const { data, error } = await supabase
        .from('device_tokens')
        .insert([{
          user_id: userId,
          token,
          platform: platform || 'android',
          is_active: true,
        }])
        .select()
        .single();

      if (error) throw error;
      return data;
    }
  }

  /**
   * Get all active FCM tokens for a user
   */
  async getActiveTokensForUser(userId) {
    if (!userId) return [];

    const { data, error } = await supabase
      .from('device_tokens')
      .select('token')
      .eq('user_id', userId)
      .eq('is_active', true);

    if (error) throw error;
    return (data || []).map((row) => row.token);
  }

  /**
   * Deactivate invalid/stale device tokens
   */
  async deactivateTokens(tokens = []) {
    if (!tokens || tokens.length === 0) return;

    await supabase
      .from('device_tokens')
      .update({ is_active: false, updated_at: new Date().toISOString() })
      .in('token', tokens);
  }

  /**
   * Create an in-app notification entry in the notifications table
   */
  async createNotification({ userId, notificationType = 'budget_threshold', title, message, relatedBudgetId = null }) {
    if (!userId || !title || !message) return null;

    const payload = {
      user_id: userId,
      notification_type: notificationType,
      title,
      message,
      is_read: false,
      related_budget_id: relatedBudgetId,
    };

    const { data, error } = await supabase
      .from('notifications')
      .insert([payload])
      .select()
      .single();

    if (error) {
      console.warn('Failed to insert into notifications table (non-fatal):', error.message);
      return null;
    }

    return data;
  }

  /**
   * Fetch all user notifications
   */
  async getUserNotifications(userId) {
    if (!userId) return [];

    const { data, error } = await supabase
      .from('notifications')
      .select('*')
      .eq('user_id', userId)
      .order('created_at', { ascending: false })
      .limit(50);

    if (error) throw error;
    return data || [];
  }

  /**
   * Mark a notification as read
   */
  async markAsRead(id, userId) {
    const { data, error } = await supabase
      .from('notifications')
      .update({ is_read: true })
      .eq('id', id)
      .eq('user_id', userId)
      .select()
      .maybeSingle();

    if (error) throw error;
    return data;
  }
}

module.exports = new NotificationRepository();
