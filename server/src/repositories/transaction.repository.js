const supabase = require('../config/supabase');
const profileRepository = require('./profile.repository');
const dateUtils = require('../utils/date');

class TransactionRepository {
  /**
   * Helper to match merchant / description to category
   */
  async _findMatchingCategoryId(merchant, description) {
    const text = `${merchant || ''} ${description || ''}`.toLowerCase();
    const { data: categories } = await supabase.from('categories').select('id, name');

    if (!categories || categories.length === 0) return null;

    const findCat = (names) => {
      const match = categories.find((c) => names.some((n) => c.name.toLowerCase().includes(n)));
      return match ? match.id : null;
    };

    if (text.includes('swiggy') || text.includes('zomato') || text.includes('food') || text.includes('restaurant') || text.includes('mcdonald') || text.includes('starbucks') || text.includes('kfc') || text.includes('domino')) {
      return findCat(['food', 'dining']);
    }
    if (text.includes('uber') || text.includes('ola') || text.includes('fuel') || text.includes('petrol') || text.includes('metro') || text.includes('irctc') || text.includes('rapido') || text.includes('cab')) {
      return findCat(['transport', 'travel']);
    }
    if (text.includes('amazon') || text.includes('flipkart') || text.includes('myntra') || text.includes('ajio') || text.includes('shopping') || text.includes('zara') || text.includes('h&m')) {
      return findCat(['shopping']);
    }
    if (text.includes('airtel') || text.includes('jio') || text.includes('bill') || text.includes('electricity') || text.includes('bescom') || text.includes('water') || text.includes('gas') || text.includes('recharge')) {
      return findCat(['bill', 'utilities']);
    }
    if (text.includes('netflix') || text.includes('spotify') || text.includes('pvr') || text.includes('inox') || text.includes('movie') || text.includes('prime') || text.includes('hotstar')) {
      return findCat(['entertainment']);
    }
    if (text.includes('blinkit') || text.includes('zepto') || text.includes('instamart') || text.includes('bigbasket') || text.includes('grocery') || text.includes('supermarket')) {
      return findCat(['grocer']);
    }
    if (text.includes('gym') || text.includes('cult') || text.includes('pharmacy') || text.includes('hospital') || text.includes('apollo') || text.includes('1mg')) {
      return findCat(['health', 'fitness']);
    }

    const otherCat = categories.find((c) => c.name.toLowerCase() === 'other');
    return otherCat ? otherCat.id : null;
  }

  /**
   * Insert a new transaction into the Supabase transactions table with duplicate check
   * @param {Object} data
   * @returns {Promise<Object>}
   */
  async createTransaction(data) {
    let userId = data.user_id;
    if (!userId) {
      const user = await profileRepository.getOrCreateUser();
      userId = user.id;
    }

    const {
      amount,
      merchant,
      transaction_type = 'expense',
      transaction_date = new Date().toISOString(),
      source = 'manual',
      sms_body = null,
      description = null,
    } = data;

    let category_id = data.category_id;
    if (!category_id) {
      category_id = await this._findMatchingCategoryId(merchant, description || sms_body);
    }

    // 1. Duplicate check: check if identical transaction exists for this user
    if (sms_body) {
      const { data: existingSmsTx } = await supabase
        .from('transactions')
        .select('*, categories(id, name, icon)')
        .eq('user_id', userId)
        .eq('sms_body', sms_body)
        .maybeSingle();

      if (existingSmsTx) {
        return {
          ...existingSmsTx,
          is_duplicate: true,
        };
      }
    }

    // Check for same amount, merchant, and same day
    if (merchant && amount) {
      const txDateObj = new Date(transaction_date);
      const { start: startOfDay, end: endOfDay } = dateUtils.getDailyBoundaries(txDateObj);

      const { data: existingSimilarTx } = await supabase
        .from('transactions')
        .select('*, categories(id, name, icon)')
        .eq('user_id', userId)
        .eq('amount', Number(amount))
        .eq('merchant', merchant)
        .gte('transaction_date', startOfDay)
        .lte('transaction_date', endOfDay)
        .maybeSingle();

      if (existingSimilarTx) {
        return {
          ...existingSimilarTx,
          is_duplicate: true,
        };
      }
    }

    // 2. Insert new transaction
    const payload = {
      user_id: userId,
      amount: Number(amount),
      transaction_type,
      transaction_date: new Date(transaction_date).toISOString(),
      source,
      merchant: merchant || null,
      sms_body: sms_body || null,
      description: description || null,
      category_id: category_id || null,
    };

    const { data: transaction, error } = await supabase
      .from('transactions')
      .insert(payload)
      .select('*, categories(id, name, icon)')
      .single();

    if (error) {
      throw error;
    }

    return transaction;
  }

  /**
   * Retrieve all transactions for a specific user ordered by transaction_date descending
   * @param {string} userId
   * @returns {Promise<Array>}
   */
  async getTransactions(userId) {
    if (!userId) {
      const user = await profileRepository.getOrCreateUser();
      userId = user.id;
    }

    const { data, error } = await supabase
      .from('transactions')
      .select('*, categories(id, name, icon, category_type)')
      .eq('user_id', userId)
      .order('transaction_date', { ascending: false });

    if (error) {
      throw error;
    }

    return data || [];
  }

  /**
   * Delete a transaction
   * @param {string} id
   * @param {string} userId
   * @returns {Promise<boolean>}
   */
  async deleteTransaction(id, userId) {
    const { error } = await supabase
      .from('transactions')
      .delete()
      .eq('id', id);

    if (error) throw error;
    return true;
  }

  /**
   * Calculate dashboard metrics for daily, weekly, monthly spending vs budgets
   * @param {string} userId
   * @returns {Promise<Object>}
   */
  async getDashboardSummary(userId) {
    if (!userId) {
      const user = await profileRepository.getOrCreateUser();
      userId = user.id;
    }

    const now = new Date();
    // Daily boundary in Asia/Kolkata
    const { start: startOfToday, end: endOfToday } = dateUtils.getDailyBoundaries(now);
    // Weekly boundary (Monday to Sunday) in Asia/Kolkata
    const { start: startOfWeek, end: endOfWeek } = dateUtils.getWeeklyBoundaries(now);
    // Monthly boundary (1st to last day) in Asia/Kolkata
    const { start: startOfMonth, end: endOfMonth } = dateUtils.getMonthlyBoundaries(now);

    // Fetch user expense transactions
    const { data: allTxs, error: txErr } = await supabase
      .from('transactions')
      .select('*, categories(id, name, icon)')
      .eq('user_id', userId)
      .eq('transaction_type', 'expense')
      .order('transaction_date', { ascending: false });

    if (txErr) throw txErr;

    // Fetch user selected bank & tracking_start from profiles (fallback to auth.users)
    let selectedBank = null;
    let trackingStart = null;
    try {
      const { data: profile } = await supabase
        .from('profiles')
        .select('selected_bank, tracking_start')
        .eq('id', userId)
        .maybeSingle();

      selectedBank = profile?.selected_bank || null;
      trackingStart = profile?.tracking_start || null;

      if (!selectedBank || !trackingStart) {
        const { data: userData } = await supabase.auth.admin.getUserById(userId);
        selectedBank = selectedBank || userData?.user?.user_metadata?.selected_bank || null;
        trackingStart = trackingStart || userData?.user?.user_metadata?.tracking_start || null;
      }
    } catch (_) {}

    // Normalize tracking_start to start of that calendar day in Asia/Kolkata
    const trackingDayStart = trackingStart
      ? dateUtils.getDailyBoundaries(new Date(trackingStart)).start
      : null;

    const eligibleTransactions = (allTxs || []).filter((tx) => {
      if (!trackingDayStart) return true;
      return new Date(tx.transaction_date).toISOString() >= trackingDayStart;
    });

    // Compute spent sums from eligible expense transactions only
    let todaySpent = 0;
    let weekSpent = 0;
    let monthSpent = 0;

    for (const tx of eligibleTransactions) {
      const txIso = new Date(tx.transaction_date).toISOString();

      if (txIso >= startOfToday && txIso <= endOfToday) {
        todaySpent += Number(tx.amount || 0);
      }
      if (txIso >= startOfWeek && txIso <= endOfWeek) {
        weekSpent += Number(tx.amount || 0);
      }
      if (txIso >= startOfMonth && txIso <= endOfMonth) {
        monthSpent += Number(tx.amount || 0);
      }
    }

    // Fetch user budgets
    const { data: budgets, error: bErr } = await supabase
      .from('budgets')
      .select('*')
      .eq('user_id', userId)
      .eq('is_active', true);

    if (bErr) throw bErr;

    const dailyBudget = budgets?.find((b) => b.period === 'daily')?.amount ?? 0;
    const weeklyBudget = budgets?.find((b) => b.period === 'weekly')?.amount ?? 0;
    const monthlyBudget = budgets?.find((b) => b.period === 'monthly')?.amount ?? 0;

    const todayRemaining = Math.max(0, dailyBudget - todaySpent);
    const weekRemaining = Math.max(0, weeklyBudget - weekSpent);
    const monthRemaining = Math.max(0, monthlyBudget - monthSpent);

    const todayPercent = dailyBudget > 0 ? Number(((todaySpent / dailyBudget) * 100).toFixed(1)) : 0;
    const weekPercent = weeklyBudget > 0 ? Number(((weekSpent / weeklyBudget) * 100).toFixed(1)) : 0;
    const monthPercent = monthlyBudget > 0 ? Number(((monthSpent / monthlyBudget) * 100).toFixed(1)) : 0;

    return {
      user_id: userId,
      selected_bank: selectedBank,
      today_spent: todaySpent,
      week_spent: weekSpent,
      month_spent: monthSpent,
      daily_budget: dailyBudget,
      weekly_budget: weeklyBudget,
      monthly_budget: monthlyBudget,
      today_remaining: todayRemaining,
      week_remaining: weekRemaining,
      month_remaining: monthRemaining,
      today_percent: todayPercent,
      week_percent: weekPercent,
      month_percent: monthPercent,
      recent_transactions: eligibleTransactions.slice(0, 10),
    };
  }
}

module.exports = new TransactionRepository();
