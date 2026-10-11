const supabase = require('../config/supabase');

class ProfileRepository {
  /**
   * Ensure user exists in auth.users and profiles
   * @param {string} [userId]
   * @returns {Promise<Object>}
   */
  async getOrCreateUser(userId) {
    if (userId) {
      const { data: existingProfile } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', userId)
        .maybeSingle();

      if (existingProfile) return existingProfile;
    }

    // Check if default user exists in auth
    const defaultEmail = 'user@spendsmart.app';
    const { data: usersData } = await supabase.auth.admin.listUsers();
    let user = usersData && usersData.users ? usersData.users.find((u) => u.email === defaultEmail) : null;

    if (!user) {
      const { data, error } = await supabase.auth.admin.createUser({
        email: defaultEmail,
        password: 'SpendSmartPassword123!',
        email_confirm: true,
      });
      if (error) throw error;
      user = data.user;
    }

    // Upsert into profiles
    const { data: profile, error: pErr } = await supabase
      .from('profiles')
      .upsert({
        id: user.id,
        full_name: 'SpendSmart User',
        currency_code: 'INR',
      })
      .select()
      .single();

    if (pErr) throw pErr;
    return profile;
  }

  /**
   * Save onboarding data to profile and budgets tables
   * @param {string} userId
   * @param {Object} data
   * @returns {Promise<Object>}
   */
  async saveOnboarding(userId, data) {
    const {
      monthly_income,
      daily_budget,
      weekly_budget,
      monthly_budget,
      selected_bank,
      employment_status,
      tracking_start,
    } = data;

    // 1. Update profiles table
    const { data: profile, error: profileErr } = await supabase
      .from('profiles')
      .update({
        monthly_income: monthly_income !== null && monthly_income !== undefined ? Number(monthly_income) : null,
        updated_at: new Date().toISOString(),
      })
      .eq('id', userId)
      .select()
      .single();

    if (profileErr) throw profileErr;

    // 2. Persist selected_bank, tracking_start, and employment_status in Supabase Auth user_metadata
    try {
      const { data: userData } = await supabase.auth.admin.getUserById(userId);
      const existingMeta = userData?.user?.user_metadata || {};
      await supabase.auth.admin.updateUserById(userId, {
        user_metadata: {
          ...existingMeta,
          selected_bank: selected_bank || null,
          tracking_start: tracking_start || null,
          employment_status: employment_status || null,
        },
      });
    } catch (metaErr) {
      console.warn('Could not update user_metadata in auth:', metaErr.message);
    }

    // 3. Insert or update budgets for daily, weekly, monthly
    const today = new Date().toISOString().split('T')[0];

    // Deactivate or remove existing budgets for this user
    await supabase.from('budgets').delete().eq('user_id', userId);

    const budgetsToInsert = [];
    if (daily_budget !== undefined && daily_budget !== null) {
      budgetsToInsert.push({
        user_id: userId,
        name: 'Daily Budget',
        amount: Number(daily_budget),
        period: 'daily',
        start_date: today,
        is_active: true,
      });
    }
    if (weekly_budget !== undefined && weekly_budget !== null) {
      budgetsToInsert.push({
        user_id: userId,
        name: 'Weekly Budget',
        amount: Number(weekly_budget),
        period: 'weekly',
        start_date: today,
        is_active: true,
      });
    }
    if (monthly_budget !== undefined && monthly_budget !== null) {
      budgetsToInsert.push({
        user_id: userId,
        name: 'Monthly Budget',
        amount: Number(monthly_budget),
        period: 'monthly',
        start_date: today,
        is_active: true,
      });
    }

    let insertedBudgets = [];
    if (budgetsToInsert.length > 0) {
      const { data: budgets, error: budgetErr } = await supabase
        .from('budgets')
        .insert(budgetsToInsert)
        .select();

      if (budgetErr) throw budgetErr;
      insertedBudgets = budgets;
    }

    return {
      profile: {
        ...profile,
        selected_bank: selected_bank || null,
        tracking_start: tracking_start || null,
        employment_status: employment_status || null,
      },
      budgets: insertedBudgets,
      selected_bank: selected_bank || null,
      employment_status: employment_status || null,
      tracking_start: tracking_start || null,
    };
  }

  /**
   * Get user profile and active budgets
   * @param {string} userId
   * @returns {Promise<Object>}
   */
  async getProfile(userId) {
    const { data: profile, error: pErr } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', userId)
      .maybeSingle();

    if (pErr) throw pErr;

    const { data: budgets, error: bErr } = await supabase
      .from('budgets')
      .select('*')
      .eq('user_id', userId)
      .eq('is_active', true);

    if (bErr) throw bErr;

    // Retrieve selected_bank & metadata from auth.users
    let metadata = {};
    try {
      const { data: userData } = await supabase.auth.admin.getUserById(userId);
      metadata = userData?.user?.user_metadata || {};
    } catch (_) {}

    return {
      profile: {
        ...profile,
        selected_bank: metadata.selected_bank || null,
        tracking_start: metadata.tracking_start || null,
        employment_status: metadata.employment_status || null,
      },
      budgets: budgets || [],
      selected_bank: metadata.selected_bank || null,
      tracking_start: metadata.tracking_start || null,
      employment_status: metadata.employment_status || null,
    };
  }
}

module.exports = new ProfileRepository();
