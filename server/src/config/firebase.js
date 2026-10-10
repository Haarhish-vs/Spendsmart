const { initializeApp, cert, getApps } = require('firebase-admin/app');
const { getMessaging } = require('firebase-admin/messaging');
const fs = require('fs');
const path = require('path');
const env = require('./env');

let firebaseApp = null;
let messaging = null;

try {
  const apps = getApps();
  if (apps.length > 0) {
    firebaseApp = apps[0];
    messaging = getMessaging(firebaseApp);
  } else {
    // 1. Try Environment variables (Render production setup)
    if (env.firebaseProjectId && env.firebaseClientEmail && env.firebasePrivateKey) {
      const privateKey = env.firebasePrivateKey.includes('\\n')
        ? env.firebasePrivateKey.replace(/\\n/g, '\n')
        : env.firebasePrivateKey;

      firebaseApp = initializeApp({
        credential: cert({
          projectId: env.firebaseProjectId,
          clientEmail: env.firebaseClientEmail,
          privateKey: privateKey,
        }),
      });
      messaging = getMessaging(firebaseApp);
      console.log('Firebase Admin initialized from environment variables');
    } else {
      // 2. Try local serviceAccountKey file
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
          console.log(`Firebase Admin initialized from local key file: ${path.basename(p)}`);
          break;
        }
      }
    }
  }

  if (!firebaseApp) {
    console.warn('Firebase Admin: No credentials found (environment variables or serviceAccountKey.json). Push notifications will be skipped.');
  }
} catch (error) {
  console.error('Firebase Admin initialization error (non-fatal):', error.message);
  firebaseApp = null;
  messaging = null;
}

module.exports = {
  firebaseApp,
  messaging,
};
