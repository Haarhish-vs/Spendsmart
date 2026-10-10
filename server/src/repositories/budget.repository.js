const supabase = require('../config/supabase');
const profileRepository = require('./profile.repository');

class BudgetRepository {
  /**
   * Get all active budgets with live spending calculations and threshold alert checks
   * @param {string} userId
   * @returns {Promise<Array>}
   */
  async getUserBudgets(userId) {
    if (!userId) {
      const user = await profileRepository.getOrCreateUser();
      userId = user.id;
    }

    // 1. Fetch active budgets for user
    const { data: budgets, error: bErr } = await supabase
      .from('budgets')
      .select('*, categories(id, name, icon, category_type)')
      .eq('user_id', userId)
      .eq('is_active', true)
      .order('created_at', { ascending: true });

    if (bErr) throw bErr;

    // 2. Fetch all user transactions
    const { data: transactions, error: tErr } = await supabase
      .from('transactions')
      .select('*')
      .eq('user_id', userId)
      .eq('transaction_type', 'expense');

    if (tErr) throw tErr;

    const allTx = transactions || [];
    const now = new Date();

    const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0).toISOString();
    const endOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59, 999).toISOString();

    const dayOfWeek = (now.getDay() + 6) % 7;
    const startOfWeek = new Date(now.getFullYear(), now.getMonth(), now.getDate() - dayOfWeek, 0, 0, 0).toISOString();
    const endOfWeek = new Date(now.getFullYear(), now.getMonth(), now.getDate() + (6 - dayOfWeek), 23, 59, 59, 999).toISOString();

    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1, 0, 0, 0).toISOString();
    const endOfMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59, 999).toISOString();

    const results = [];

    for (const b of (budgets || [])) {
      let spent = 0;

      for (const tx of allTx) {
        // If category budget, check category match
        if (b.category_id && tx.category_id !== b.category_id) {
          continue;
        }

        const txIso = new Date(tx.transaction_date).toISOString();

        if (b.period === 'daily' && txIso >= startOfToday && txIso <= endOfToday) {
          spent += Number(tx.amount || 0);
        } else if (b.period === 'weekly' && txIso >= startOfWeek && txIso <= endOfWeek) {
          spent += Number(tx.amount || 0);
        } else if ((b.period === 'monthly' || !b.period) && txIso >= startOfMonth && txIso <= endOfMonth) {
          spent += Number(tx.amount || 0);
        }
      }

      const budgetAmount = Number(b.amount || 0);
      const percentageUsed = budgetAmount > 0 ? (spent / budgetAmount) * 100 : 0;
      const remainingAmount = Math.max(0, budgetAmount - spent);

      let status = 'safe';
      let alertType = null;
      if (percentageUsed >= 100) {
        status = 'exceeded';
        alertType = 'exceeded';
      } else if (percentageUsed >= 80) {
        status = 'warning';
        alertType = 'warning';
      }

      // Check and record alert if needed
      if (alertType) {
        const thresholdPercent = alertType === 'exceeded' ? 100 : 80;
        const msg = `${b.name || 'Budget'} ${alertType === 'exceeded' ? 'exceeded' : 'reached 80%'}: ₹${spent.toFixed(0)} of ₹${budgetAmount.toFixed(0)}`;
        
        // Trigger alert recording (non-blocking)
        this._recordAlertIfNew(userId, b.id, thresholdPercent, alertType, spent, budgetAmount, msg).catch(() => {});
      }

      results.push({
        id: b.id,
        user_id: b.user_id,
        category_id: b.category_id,
        category: b.categories,
        name: b.name,
        amount: budgetAmount,
        period: b.period,
        spent_amount: spent,
        remaining_amount: remainingAmount,
        percentage_used: Number(percentageUsed.toFixed(1)),
        status,
        start_date: b.start_date,
        is_active: b.is_active,
        created_at: b.created_at,
      });
    }

    return results;
  }

  /**
   * Helper to insert alert into budget_alerts table without creating spam
   */
  async _recordAlertIfNew(userId, budgetId, thresholdPercent, alertType, spentAmount, budgetAmount, message) {
    const today = new Date().toISOString().split('T')[0];
    
    // Check if alert already logged today
    const { data: existing } = await supabase
      .from('budget_alerts')
      .select('id')
      .eq('user_id', userId)
      .eq('budget_id', budgetId)
      .eq('threshold_percent', thresholdPercent)
      .gte('created_at', `${today}T00:00:00.000Z`)
      .maybeSingle();

    if (!existing) {
      await supabase.from('budget_alerts').insert([{
        budget_id: budgetId,
        user_id: userId,
        threshold_percent: thresholdPercent,
        alert_type: alertType,
        spent_amount: spentAmount,
        budget_amount: budgetAmount,
        message: message,
      }]);
    }
  }

  /**
   * Create or update a budget
   * @param {Object} data
   * @returns {Promise<Object>}
   */
  async saveBudget(data) {
    let userId = data.user_id;
    if (!userId) {
      const user = await profileRepository.getOrCreateUser();
      userId = user.id;
    }

    const {
      id,
      name,
      amount,
      period = 'monthly',
      category_id = null,
      start_date = new Date().toISOString().split('T')[0],
      is_active = true,
    } = data;

    if (id) {
      // Update existing
      const { data: updated, error } = await supabase
        .from('budgets')
        .update({
          name,
          amount: Number(amount),
          period,
          category_id: category_id || null,
          start_date,
          is_active,
          updated_at: new Date().toISOString(),
        })
        .eq('id', id)
        .eq('user_id', userId)
        .select('*, categories(id, name, icon)')
        .single();

      if (error) throw error;
      return updated;
    } else {
      // Insert new
      const { data: created, error } = await supabase
        .from('budgets')
        .insert([{
          user_id: userId,
          name: name || `${period.charAt(0).toUpperCase() + period.slice(1)} Budget`,
          amount: Number(amount),
          period,
          category_id: category_id || null,
          start_date,
          is_active,
        }])
        .select('*, categories(id, name, icon)')
        .single();

      if (error) throw error;
      return created;
    }
  }

  /**
   * Delete a budget
   * @param {string} id
   * @param {string} userId
   * @returns {Promise<boolean>}
   */
  async deleteBudget(id, userId) {
    const { error } = await supabase
      .from('budgets')
      .delete()
      .eq('id', id);

    if (error) throw error;
    return true;
  }

  /**
   * Fetch recent budget alerts for user
   * @param {string} userId
   * @returns {Promise<Array>}
   */
  async getBudgetAlerts(userId) {
    if (!userId) {
      const user = await profileRepository.getOrCreateUser();
      userId = user.id;
    }

    const { data, error } = await supabase
      .from('budget_alerts')
      .select('*')
      .eq('user_id', userId)
      .order('created_at', { ascending: false })
      .limit(20);

    if (error) throw error;
    return data || [];
  }
}

module.exports = new BudgetRepository();
