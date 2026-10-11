const supabase = require('../config/supabase');
const profileRepository = require('./profile.repository');

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
      const startOfDay = new Date(txDateObj.getFullYear(), txDateObj.getMonth(), txDateObj.getDate()).toISOString();
      const endOfDay = new Date(txDateObj.getFullYear(), txDateObj.getMonth(), txDateObj.getDate(), 23, 59, 59).toISOString();

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
    // Start and end of today in local calendar
    const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0).toISOString();
    const endOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59, 999).toISOString();

    // Start and end of current week (Monday to Sunday)
    const dayOfWeek = (now.getDay() + 6) % 7; // 0 for Monday, 6 for Sunday
    const startOfWeek = new Date(now.getFullYear(), now.getMonth(), now.getDate() - dayOfWeek, 0, 0, 0).toISOString();
    const endOfWeek = new Date(now.getFullYear(), now.getMonth(), now.getDate() + (6 - dayOfWeek), 23, 59, 59, 999).toISOString();

    // Start and end of current month
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1, 0, 0, 0).toISOString();
    const endOfMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59, 999).toISOString();

    // Fetch transactions
    const { data: allTxs, error: txErr } = await supabase
      .from('transactions')
      .select('*, categories(id, name, icon)')
      .eq('user_id', userId)
      .eq('transaction_type', 'expense')
      .order('transaction_date', { ascending: false });

    if (txErr) throw txErr;

    // Fetch user metadata for selected bank & tracking_start
    let selectedBank = null;
    let trackingStart = null;
    try {
      const { data: userData } = await supabase.auth.admin.getUserById(userId);
      selectedBank = userData?.user?.user_metadata?.selected_bank || null;
      trackingStart = userData?.user?.user_metadata?.tracking_start || null;
    } catch (_) {}

    const trackingStartIso = trackingStart ? new Date(trackingStart).toISOString() : null;
    const eligibleTransactions = (allTxs || []).filter((tx) => {
      if (!trackingStartIso) return true;
      return new Date(tx.transaction_date).toISOString() >= trackingStartIso;
    });

    // Compute spent sums from eligible transactions only
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

    return {
      user_id: userId,
      selected_bank: selectedBank,
      today_spent: todaySpent,
      week_spent: weekSpent,
      month_spent: monthSpent,
      daily_budget: dailyBudget,
      weekly_budget: weeklyBudget,
      monthly_budget: monthlyBudget,
      recent_transactions: eligibleTransactions.slice(0, 10),
    };
  }
}

module.exports = new TransactionRepository();
