require('dotenv').config();

module.exports = {
  port: process.env.PORT || 5000,
  supabaseUrl: process.env.SUPABASE_URL,
  supabaseServiceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY,
  firebaseProjectId: process.env.FIREBASE_PROJECT_ID,
  firebaseClientEmail: process.env.FIREBASE_CLIENT_EMAIL,
  firebasePrivateKey: process.env.FIREBASE_PRIVATE_KEY,
  firebaseServiceAccount: process.env.FIREBASE_SERVICE_ACCOUNT || process.env.FIREBASE_SERVICE_ACCOUNT_JSON || process.env.FIREBASE_CONFIG,
  googleApplicationCredentials: process.env.GOOGLE_APPLICATION_CREDENTIALS,
};
