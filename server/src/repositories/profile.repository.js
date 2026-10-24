const supabase = require('../config/supabase');

class ProfileRepository {
  /**
   * Ensure user exists in auth.users and profiles
   * @param {string} [userId]
   * @returns {Promise<Object>}
   */
  async getOrCreateUser(userId) {
    let resolvedUserId = userId;
    let existingProfile = null;

    if (resolvedUserId) {
      const { data } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', resolvedUserId)
        .maybeSingle();
      existingProfile = data;
    }

    if (!existingProfile) {
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

      resolvedUserId = user.id;

      // Upsert into profiles
      const { data: profile, error: pErr } = await supabase
        .from('profiles')
        .upsert({
          id: resolvedUserId,
          full_name: 'SpendSmart User',
          currency_code: 'INR',
        })
        .select()
        .single();

      if (pErr) throw pErr;
      existingProfile = profile;
    } else {
      resolvedUserId = existingProfile.id;
    }

    // Retrieve selected_bank & metadata from profiles first, then fallback to auth.users
    let selected_bank = existingProfile?.selected_bank || null;
    let tracking_start = existingProfile?.tracking_start || null;
    let employment_status = existingProfile?.employment_status || null;

    let metadata = {};
    try {
      const { data: userData } = await supabase.auth.admin.getUserById(resolvedUserId);
      metadata = userData?.user?.user_metadata || {};
      selected_bank = selected_bank || metadata.selected_bank || null;
      tracking_start = tracking_start || metadata.tracking_start || null;
      employment_status = employment_status || metadata.employment_status || null;
    } catch (_) {}

    return {
      ...existingProfile,
      selected_bank,
      tracking_start,
      employment_status,
      user_metadata: metadata,
    };
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

    // 1. Update profiles table safely with existing columns
    const profileUpdate = {
      updated_at: new Date().toISOString(),
    };
    if (monthly_income !== null && monthly_income !== undefined) {
      profileUpdate.monthly_income = Number(monthly_income);
    }

    let { data: profile, error: profileErr } = await supabase
      .from('profiles')
      .update(profileUpdate)
      .eq('id', userId)
      .select('*')
      .maybeSingle();

    if (profileErr) {
      console.warn('Could not update profiles table:', profileErr.message);
    }

    // Attempt optional columns if schema migration was run, but never throw if it fails
    try {
      const extraUpdate = {};
      if (selected_bank !== undefined) extraUpdate.selected_bank = selected_bank || null;
      if (tracking_start !== undefined) extraUpdate.tracking_start = tracking_start || null;
      if (employment_status !== undefined) extraUpdate.employment_status = employment_status || null;
      if (Object.keys(extraUpdate).length > 0) {
        const { data: updatedExtra } = await supabase
          .from('profiles')
          .update(extraUpdate)
          .eq('id', userId)
          .select('*')
          .maybeSingle();
        if (updatedExtra) profile = updatedExtra;
      }
    } catch (_) {}

    // Ensure profile has an id
    const resolvedProfile = {
      ...(profile || {}),
      id: profile?.id || userId,
      selected_bank: selected_bank || null,
      tracking_start: tracking_start || null,
      employment_status: employment_status || null,
    };

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
        .select('*');

      if (budgetErr) throw budgetErr;
      insertedBudgets = budgets;
    }

    return {
      profile: resolvedProfile,
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

    let selected_bank = profile?.selected_bank || null;
    let tracking_start = profile?.tracking_start || null;
    let employment_status = profile?.employment_status || null;

    // Retrieve selected_bank & metadata from auth.users as fallback
    let metadata = {};
    try {
      const { data: userData } = await supabase.auth.admin.getUserById(userId);
      metadata = userData?.user?.user_metadata || {};
      selected_bank = selected_bank || metadata.selected_bank || null;
      tracking_start = tracking_start || metadata.tracking_start || null;
      employment_status = employment_status || metadata.employment_status || null;
    } catch (_) {}

    return {
      profile: {
        ...profile,
        selected_bank,
        tracking_start,
        employment_status,
      },
      budgets: budgets || [],
      selected_bank,
      tracking_start,
      employment_status,
    };
  }
}

module.exports = new ProfileRepository();
