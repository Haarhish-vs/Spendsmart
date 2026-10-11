const { initializeApp, cert, getApps } = require('firebase-admin/app');
const { getMessaging } = require('firebase-admin/messaging');
const fs = require('fs');
const path = require('path');
const env = require('./env');

let firebaseApp = null;
let messaging = null;

function formatPrivateKey(rawKey) {
  if (!rawKey) return null;
  let key = rawKey.trim();
  // Strip outer quotes if wrapped
  if ((key.startsWith('"') && key.endsWith('"')) || (key.startsWith("'") && key.endsWith("'"))) {
    key = key.slice(1, -1).trim();
  }
  // Replace literal escaped \n with actual newline
  key = key.replace(/\\n/g, '\n');
  return key;
}

function parseServiceAccountJson(rawJson) {
  if (!rawJson) return null;
  let str = rawJson.trim();
  if ((str.startsWith('"') && str.endsWith('"')) || (str.startsWith("'") && str.endsWith("'"))) {
    str = str.slice(1, -1).trim();
  }
  try {
    return JSON.parse(str);
  } catch (_) {
    try {
      const decoded = Buffer.from(str, 'base64').toString('utf8');
      return JSON.parse(decoded);
    } catch (_) {
      return null;
    }
  }
}

try {
  const apps = getApps();
  if (apps.length > 0) {
    firebaseApp = apps[0];
    messaging = getMessaging(firebaseApp);
    console.log(`[Firebase Admin] Reusing existing initialized app: ${firebaseApp.name}`);
  } else {
    // 1. Try single JSON string from environment variable (ideal for Render/Cloud)
    if (env.firebaseServiceAccount) {
      const serviceAccount = parseServiceAccountJson(env.firebaseServiceAccount);
      if (serviceAccount && serviceAccount.project_id && serviceAccount.private_key) {
        serviceAccount.private_key = formatPrivateKey(serviceAccount.private_key);
        firebaseApp = initializeApp({
          credential: cert(serviceAccount),
        });
        messaging = getMessaging(firebaseApp);
        console.log(`[Firebase Admin] Initialized from FIREBASE_SERVICE_ACCOUNT (Project: ${serviceAccount.project_id})`);
      } else {
        console.warn('[Firebase Admin] FIREBASE_SERVICE_ACCOUNT was provided but could not be parsed as valid JSON.');
      }
    }

    // 2. Try individual environment variables
    if (!firebaseApp && env.firebaseProjectId && env.firebaseClientEmail && env.firebasePrivateKey) {
      const privateKey = formatPrivateKey(env.firebasePrivateKey);
      firebaseApp = initializeApp({
        credential: cert({
          projectId: env.firebaseProjectId.trim(),
          clientEmail: env.firebaseClientEmail.trim(),
          privateKey: privateKey,
        }),
      });
      messaging = getMessaging(firebaseApp);
      console.log(`[Firebase Admin] Initialized from individual environment variables (Project: ${env.firebaseProjectId.trim()})`);
    }

    // 3. Try GOOGLE_APPLICATION_CREDENTIALS file path if specified
    if (!firebaseApp && env.googleApplicationCredentials && fs.existsSync(env.googleApplicationCredentials)) {
      const serviceAccount = JSON.parse(fs.readFileSync(env.googleApplicationCredentials, 'utf8'));
      firebaseApp = initializeApp({
        credential: cert(serviceAccount),
      });
      messaging = getMessaging(firebaseApp);
      console.log(`[Firebase Admin] Initialized from GOOGLE_APPLICATION_CREDENTIALS path: ${env.googleApplicationCredentials}`);
    }

    // 4. Try local serviceAccountKey.json file (Local development fallback)
    if (!firebaseApp) {
      const candidatePaths = [
        path.join(process.cwd(), 'serviceAccountKey.json'),
        path.join(process.cwd(), 'serviceAccountKey.json.json'),
        path.join(__dirname, '..', '..', 'serviceAccountKey.json'),
        path.join(__dirname, '..', '..', 'serviceAccountKey.json.json'),
      ];

      for (const p of candidatePaths) {
        if (fs.existsSync(p)) {
          const serviceAccount = JSON.parse(fs.readFileSync(p, 'utf8'));
          firebaseApp = initializeApp({
            credential: cert(serviceAccount),
          });
          messaging = getMessaging(firebaseApp);
          console.log(`[Firebase Admin] Initialized from local key file: ${path.basename(p)} (Project: ${serviceAccount.project_id})`);
          break;
        }
      }
    }
  }

  if (!firebaseApp) {
    console.warn('[Firebase Admin] Warning: No valid credentials found (checked FIREBASE_SERVICE_ACCOUNT, individual env vars, and local serviceAccountKey.json). Push notifications will be disabled.');
  }
} catch (error) {
  console.error('[Firebase Admin] Initialization error:', error.message);
  firebaseApp = null;
  messaging = null;
}

module.exports = {
  firebaseApp,
  messaging,
};
