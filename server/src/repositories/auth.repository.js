const crypto = require('crypto');
const supabase = require('../config/supabase');

/**
 * Repository layer for custom authentication using public.app_users
 */
class AuthRepository {
  /**
   * Find an active or inactive user by normalized email
   * @param {string} email
   * @returns {Promise<Object|null>}
   */
  async findByEmail(email) {
    if (!email) return null;
    const normalizedEmail = email.trim().toLowerCase();

    const { data, error } = await supabase
      .from('app_users')
      .select('*')
      .ilike('email', normalizedEmail)
      .maybeSingle();

    if (error) {
      throw error;
    }

    return data;
  }

  /**
   * Find user by ID
   * @param {string} id
   * @returns {Promise<Object|null>}
   */
  async findById(id) {
    if (!id) return null;

    const { data, error } = await supabase
      .from('app_users')
      .select('id, full_name, email, is_active, email_verified, created_at, updated_at')
      .eq('id', id)
      .maybeSingle();

    if (error) {
      throw error;
    }

    return data;
  }

  /**
   * Insert a new user into public.app_users and initialize their profile
   * @param {Object} userData
   * @returns {Promise<Object>} Safe user record without password_hash
   */
  async createUser({ id, full_name, email, password_hash, is_active = true, email_verified = false }) {
    const userId = id || crypto.randomUUID();
    const normalizedEmail = email.trim().toLowerCase();
    const now = new Date().toISOString();

    const { data: newUser, error: insertError } = await supabase
      .from('app_users')
      .insert([{
        id: userId,
        full_name: full_name.trim(),
        email: normalizedEmail,
        password_hash,
        is_active,
        email_verified,
        created_at: now,
        updated_at: now,
      }])
      .select('id, full_name, email, is_active, email_verified, created_at, updated_at')
      .single();

    if (insertError) {
      throw insertError;
    }

    // Initialize corresponding profile in public.profiles
    try {
      const { error: profileError } = await supabase
        .from('profiles')
        .insert([{
          id: newUser.id,
          full_name: newUser.full_name,
          currency_code: 'INR',
          created_at: now,
          updated_at: now,
        }]);

      if (profileError) {
        // If foreign key constraint points to legacy auth.users before SQL migration is executed,
        // create matching entry in auth.users as bridge to prevent foreign key constraint failure.
        if (profileError.code === '23503') {
          try {
            await supabase.auth.admin.createUser({
              id: newUser.id,
              email: normalizedEmail,
              password: 'SpendSmartBridgePassword123!',
              email_confirm: true,
            });

            await supabase
              .from('profiles')
              .insert([{
                id: newUser.id,
                full_name: newUser.full_name,
                currency_code: 'INR',
                created_at: now,
                updated_at: now,
              }]);
          } catch (_) {
            // Ignore bridge errors if migration has been executed
          }
        } else {
          console.warn('Profile initialization note:', profileError.message);
        }
      }
    } catch (e) {
      console.warn('Profile sync exception:', e.message);
    }

    return newUser;
  }
}

module.exports = new AuthRepository();
