const supabase = require('../config/supabase');
const dateUtils = require('../utils/date');
const fcmService = require('../integrations/firebase/fcm.service');
const notificationRepository = require('../repositories/notification.repository');

class BudgetAlertService {
  /**
   * Threshold configuration definitions
   */
  static THRESHOLDS = [
    {
      percentage: 50,
      alertType: 'halfway',
      title: 'Budget Update',
      getBody: (period) =>
        `You've used 50% of your ${period} budget. Keep tracking your spending.`,
    },
    {
      percentage: 80,
      alertType: 'warning',
      title: 'Budget Warning',
      getBody: (period) =>
        `You've used 80% of your ${period} budget. Watch your remaining budget.`,
    },
    {
      percentage: 100,
      alertType: 'limit_reached',
      title: 'Budget Limit Reached',
      getBody: (period) =>
        `You've used your entire ${period} budget.`,
    },
    {
      percentage: 101, // Represents > 100%
      alertType: 'exceeded',
      title: 'Budget Exceeded',
      getBody: (period) =>
        `You've exceeded your ${period} spending budget. Review your recent expenses.`,
    },
  ];

  /**
   * Evaluate user budgets after a valid expense transaction has been saved
   * @param {Object} params
   * @param {string} params.userId
   * @param {Object} params.transaction - The newly saved transaction
   * @returns {Promise<Array>} Array of triggered alert evaluation results
   */
  async evaluateBudgetsForTransaction({ userId, transaction }) {
    if (!userId || !transaction) return [];

    // Only expense transactions evaluate against spending budgets
    if (transaction.transaction_type !== 'expense') {
      return [];
    }

    const currentTxAmount = Number(transaction.amount || 0);
    if (currentTxAmount <= 0) return [];

    const txDate = transaction.transaction_date ? new Date(transaction.transaction_date) : new Date();

    // 1. Fetch user's active budgets
    const { data: budgets, error: bErr } = await supabase
      .from('budgets')
      .select('*, categories(id, name)')
      .eq('user_id', userId)
      .eq('is_active', true);

    if (bErr || !budgets || budgets.length === 0) {
      return [];
    }

    const results = [];

    // 2. Evaluate each applicable budget
    for (const budget of budgets) {
      // If category budget, check if this transaction matches
      if (budget.category_id && transaction.category_id !== budget.category_id) {
        continue;
      }

      const budgetAmount = Number(budget.amount || 0);
      if (budgetAmount <= 0) continue;

      const period = (budget.period || 'monthly').toLowerCase();
      const { start, end } = dateUtils.getBoundariesForPeriod(period, txDate);

      // 3. Query all eligible expense transactions within the calendar boundary
      let query = supabase
        .from('transactions')
        .select('id, amount, category_id, transaction_date')
        .eq('user_id', userId)
        .eq('transaction_type', 'expense')
        .gte('transaction_date', start)
        .lte('transaction_date', end);

      if (budget.category_id) {
        query = query.eq('category_id', budget.category_id);
      }

      const { data: txsInPeriod, error: tErr } = await query;
      if (tErr) {
        console.error(`Error querying transactions for budget ${budget.id}:`, tErr.message);
        continue;
      }

      // Retrieve user's tracking_start date from profile (fallback to auth.users)
      let trackingStart = null;
      try {
        const { data: profile } = await supabase
          .from('profiles')
          .select('tracking_start')
          .eq('id', userId)
          .maybeSingle();

        trackingStart = profile?.tracking_start || null;

        if (!trackingStart) {
          const { data: userData } = await supabase.auth.admin.getUserById(userId);
          trackingStart = userData?.user?.user_metadata?.tracking_start || null;
        }
      } catch (_) {}

      const trackingDayStart = trackingStart
        ? dateUtils.getDailyBoundaries(new Date(trackingStart)).start
        : null;

      const eligibleTxs = (txsInPeriod || []).filter((tx) => {
        if (!trackingDayStart) return true;
        return new Date(tx.transaction_date).toISOString() >= trackingDayStart;
      });

      const totalSpent = eligibleTxs.reduce((sum, tx) => sum + Number(tx.amount || 0), 0);
      const prevSpent = Math.max(0, totalSpent - currentTxAmount);

      const prevPercent = (prevSpent / budgetAmount) * 100;
      const newPercent = (totalSpent / budgetAmount) * 100;

      // 4. Find newly crossed thresholds
      const crossedThresholds = [];
      for (const t of BudgetAlertService.THRESHOLDS) {
        let isCrossed = false;
        if (t.percentage === 101) {
          isCrossed = prevPercent <= 100 && newPercent > 100;
        } else {
          isCrossed = prevPercent < t.percentage && newPercent >= t.percentage;
        }

        if (isCrossed) {
          crossedThresholds.push(t);
        }
      }

      if (crossedThresholds.length === 0) {
        continue;
      }

      for (const t of crossedThresholds) {
        // 5. Prevent Duplicate Notifications in this period
        const { data: existingAlert } = await supabase
          .from('budget_alerts')
          .select('id')
          .eq('budget_id', budget.id)
          .eq('user_id', userId)
          .eq('threshold_percent', t.percentage)
          .gte('created_at', start)
          .lte('created_at', end)
          .maybeSingle();

        if (existingAlert) {
          // Already notified for this exact calendar period and threshold
          continue;
        }

        const periodLabel = budget.category_id && budget.categories
          ? `${budget.categories.name} (${period})`
          : period;

        const title = t.title;
        const body = t.getBody(periodLabel, totalSpent, budgetAmount);

        // 6. Record in budget_alerts table
        const { data: alertRecord, error: aErr } = await supabase
          .from('budget_alerts')
          .insert([{
            budget_id: budget.id,
            user_id: userId,
            threshold_percent: t.percentage,
            alert_type: t.alertType,
            spent_amount: totalSpent,
            budget_amount: budgetAmount,
            message: body,
          }])
          .select()
          .single();

        if (aErr) {
          console.error(`Error saving budget_alert for budget ${budget.id}:`, aErr.message);
          continue;
        }

        // 7. Record in notifications history table
        await notificationRepository.createNotification({
          userId,
          notificationType: 'budget_threshold',
          title,
          message: body,
          relatedBudgetId: budget.id,
        });

        // 8. Deliver FCM Push Notification for this crossed threshold
        let pushResult = null;
        const tokens = await notificationRepository.getActiveTokensForUser(userId);
        if (tokens && tokens.length > 0) {
          pushResult = await fcmService.sendPushNotification({
            tokens,
            title,
            body,
            data: {
              notification_type: 'budget_threshold',
              budget_id: budget.id,
              period: budget.period,
              threshold: String(t.percentage),
              route: '/budgets',
            },
          });

          // Cleanup invalid tokens if any detected
          if (pushResult && pushResult.invalidTokens && pushResult.invalidTokens.length > 0) {
            await notificationRepository.deactivateTokens(pushResult.invalidTokens);
          }
        }

        results.push({
          budgetId: budget.id,
          budgetName: budget.name,
          period: budget.period,
          threshold: t.percentage,
          alertType: t.alertType,
          totalSpent,
          budgetAmount,
          percentUsed: Number(newPercent.toFixed(1)),
          pushDelivered: pushResult ? pushResult.success : false,
        });
      }

    }

    return results;
  }
}

module.exports = new BudgetAlertService();
