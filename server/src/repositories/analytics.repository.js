const supabase = require('../config/supabase');
const profileRepository = require('./profile.repository');

class AnalyticsRepository {
  /**
   * Get comprehensive spending analytics for a user
   * @param {string} userId
   * @param {string} [period='month']
   * @returns {Promise<Object>}
   */
  async getOverview(userId, period = 'month') {
    if (!userId) {
      const user = await profileRepository.getOrCreateUser();
      userId = user.id;
    }

    // 1. Fetch all transactions and categories
    const { data: allTxs, error: tErr } = await supabase
      .from('transactions')
      .select('*, categories(id, name, icon, category_type)')
      .eq('user_id', userId)
      .order('transaction_date', { ascending: false });

    // Retrieve tracking_start from auth user_metadata
    let trackingStart = null;
    try {
      const { data: userData } = await supabase.auth.admin.getUserById(userId);
      trackingStart = userData?.user?.user_metadata?.tracking_start || null;
    } catch (_) {}

    const trackingStartIso = trackingStart ? new Date(trackingStart).toISOString() : null;
    const transactions = (allTxs || []).filter((tx) => {
      if (!trackingStartIso) return true;
      return new Date(tx.transaction_date).toISOString() >= trackingStartIso;
    });

    // Date ranges
    const now = new Date();

    // Current month window
    const startOfCurrentMonth = new Date(now.getFullYear(), now.getMonth(), 1, 0, 0, 0);
    const endOfCurrentMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59, 999);

    // Last month window
    const startOfLastMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1, 0, 0, 0);
    const endOfLastMonth = new Date(now.getFullYear(), now.getMonth(), 0, 23, 59, 59, 999);

    let currentMonthExpense = 0;
    let currentMonthIncome = 0;
    let lastMonthExpense = 0;

    const categoryMap = {};

    // 7 Days of current week (Mon-Sun)
    const dayOfWeek = (now.getDay() + 6) % 7;
    const startOfWeek = new Date(now.getFullYear(), now.getMonth(), now.getDate() - dayOfWeek, 0, 0, 0);
    const weeklyData = [
      { day: 'Mon', amount: 0, date: '' },
      { day: 'Tue', amount: 0, date: '' },
      { day: 'Wed', amount: 0, date: '' },
      { day: 'Thu', amount: 0, date: '' },
      { day: 'Fri', amount: 0, date: '' },
      { day: 'Sat', amount: 0, date: '' },
      { day: 'Sun', amount: 0, date: '' },
    ];

    // Last 6 months trend
    const monthlyTrendMap = {};
    for (let i = 5; i >= 0; i--) {
      const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
      const key = d.toLocaleString('en-US', { month: 'short' });
      monthlyTrendMap[key] = { month: key, year: d.getFullYear(), expense: 0, income: 0 };
    }

    for (const tx of transactions) {
      const txDate = new Date(tx.transaction_date);
      const amount = Number(tx.amount || 0);
      const isExpense = tx.transaction_type === 'expense';

      // Current Month vs Last Month
      if (txDate >= startOfCurrentMonth && txDate <= endOfCurrentMonth) {
        if (isExpense) {
          currentMonthExpense += amount;

          // Category aggregation (for current month)
          const categoryName = tx.categories?.name || (tx.category_id ? 'Categorized' : 'Other');
          const categoryIcon = tx.categories?.icon || 'category';

          if (!categoryMap[categoryName]) {
            categoryMap[categoryName] = {
              name: categoryName,
              icon: categoryIcon,
              total_amount: 0,
              count: 0,
            };
          }
          categoryMap[categoryName].total_amount += amount;
          categoryMap[categoryName].count += 1;
        } else {
          currentMonthIncome += amount;
        }
      } else if (txDate >= startOfLastMonth && txDate <= endOfLastMonth) {
        if (isExpense) {
          lastMonthExpense += amount;
        }
      }

      // Weekly trend
      if (txDate >= startOfWeek && txDate <= now && isExpense) {
        const dIndex = (txDate.getDay() + 6) % 7;
        if (dIndex >= 0 && dIndex < 7) {
          weeklyData[dIndex].amount += amount;
        }
      }

      // Monthly trend (last 6 months)
      const monthKey = txDate.toLocaleString('en-US', { month: 'short' });
      if (monthlyTrendMap[monthKey]) {
        if (isExpense) {
          monthlyTrendMap[monthKey].expense += amount;
        } else {
          monthlyTrendMap[monthKey].income += amount;
        }
      }
    }

    // Format category breakdown with percentages
    const categoryBreakdown = Object.values(categoryMap).map((cat) => ({
      ...cat,
      percentage: currentMonthExpense > 0 ? Number(((cat.total_amount / currentMonthExpense) * 100).toFixed(1)) : 0,
    })).sort((a, b) => b.total_amount - a.total_amount);

    // Percentage change vs last month
    let momChangePercentage = 0;
    if (lastMonthExpense > 0) {
      momChangePercentage = Number((((currentMonthExpense - lastMonthExpense) / lastMonthExpense) * 100).toFixed(1));
    }

    return {
      period,
      summary: {
        total_expense: currentMonthExpense,
        total_income: currentMonthIncome,
        net_savings: Math.max(0, currentMonthIncome - currentMonthExpense),
        last_month_expense: lastMonthExpense,
        mom_change_percentage: momChangePercentage,
      },
      category_breakdown: categoryBreakdown,
      weekly_trends: weeklyData,
      monthly_trends: Object.values(monthlyTrendMap),
    };
  }
}

module.exports = new AnalyticsRepository();
