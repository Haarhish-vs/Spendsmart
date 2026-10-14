const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const env = require('../config/env');
const authRepository = require('../repositories/auth.repository');

const BCRYPT_SALT_ROUNDS = 10;

class AuthService {
  /**
   * Register a new user with custom email, password and profile
   * @param {Object} params
   * @param {string} params.fullName
   * @param {string} params.email
   * @param {string} params.password
   * @returns {Promise<{ user: Object, token: string }>}
   */
  async register({ fullName, email, password }) {
    if (!fullName || !email || !password) {
      const error = new Error('Full name, email, and password are required');
      error.statusCode = 400;
      throw error;
    }

    const normalizedEmail = email.trim().toLowerCase();

    // Check if user already exists
    const existingUser = await authRepository.findByEmail(normalizedEmail);
    if (existingUser) {
      const error = new Error('An account with this email already exists');
      error.statusCode = 409;
      throw error;
    }

    // Hash password with bcrypt
    const passwordHash = await bcrypt.hash(password, BCRYPT_SALT_ROUNDS);

    // Create user in public.app_users
    const user = await authRepository.createUser({
      full_name: fullName.trim(),
      email: normalizedEmail,
      password_hash: passwordHash,
      is_active: true,
      email_verified: false,
    });

    // Generate JWT token with sub set to user id
    const token = this.generateToken(user);

    return {
      user,
      token,
    };
  }

  /**
   * Authenticate a user with email and password
   * @param {Object} params
   * @param {string} params.email
   * @param {string} params.password
   * @returns {Promise<{ user: Object, token: string }>}
   */
  async login({ email, password }) {
    if (!email || !password) {
      const error = new Error('Email and password are required');
      error.statusCode = 400;
      throw error;
    }

    const normalizedEmail = email.trim().toLowerCase();

    // Find user by normalized email
    const user = await authRepository.findByEmail(normalizedEmail);
    if (!user) {
      const error = new Error('Invalid email or password');
      error.statusCode = 401;
      throw error;
    }

    // Reject inactive accounts
    if (!user.is_active) {
      const error = new Error('Account is inactive. Please contact support.');
      error.statusCode = 403;
      throw error;
    }

    // Verify password hash
    const isPasswordValid = await bcrypt.compare(password, user.password_hash);
    if (!isPasswordValid) {
      const error = new Error('Invalid email or password');
      error.statusCode = 401;
      throw error;
    }

    // Exclude password_hash from returned user payload
    const { password_hash, ...safeUser } = user;

    // Generate JWT token
    const token = this.generateToken(safeUser);

    return {
      user: safeUser,
      token,
    };
  }

  /**
   * Retrieve current authenticated user record
   * @param {string} userId
   * @returns {Promise<Object>}
   */
  async getCurrentUser(userId) {
    if (!userId) {
      const error = new Error('User ID is required');
      error.statusCode = 400;
      throw error;
    }

    const user = await authRepository.findById(userId);
    if (!user) {
      const error = new Error('User not found');
      error.statusCode = 404;
      throw error;
    }

    return user;
  }

  /**
   * Helper method to sign a JWT token
   * @param {Object} user
   * @returns {string}
   */
  generateToken(user) {
    return jwt.sign(
      {
        sub: user.id,
        email: user.email,
        full_name: user.full_name,
      },
      env.jwtSecret,
      {
        expiresIn: env.jwtExpiresIn,
      }
    );
  }
}

module.exports = new AuthService();
