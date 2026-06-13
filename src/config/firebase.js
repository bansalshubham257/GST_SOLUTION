// backend/src/config/firebase.js

const admin = require('firebase-admin');
const logger = require('../utils/logger');

let firebaseApp;

const initFirebase = () => {
  try {
    if (admin.apps.length > 0) {
      firebaseApp = admin.app();
      return;
    }

    const serviceAccount = process.env.FIREBASE_SERVICE_ACCOUNT_JSON
      ? JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON)
      : {
          type: 'service_account',
          project_id: process.env.FIREBASE_PROJECT_ID,
          private_key_id: process.env.FIREBASE_PRIVATE_KEY_ID,
          private_key: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
          client_email: process.env.FIREBASE_CLIENT_EMAIL,
          client_id: process.env.FIREBASE_CLIENT_ID,
        };

    firebaseApp = admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      storageBucket: process.env.FIREBASE_STORAGE_BUCKET,
    });

    logger.info('Firebase Admin initialized');
  } catch (error) {
    logger.error('Firebase initialization failed:', error.message);
    throw error;
  }
};

const isFirebaseAvailable = () => {
  try {
    return admin.apps.length > 0;
  } catch {
    return false;
  }
};

const verifyFirebaseToken = async (token) => {
  if (!isFirebaseAvailable()) {
    throw new Error('Firebase not configured');
  }
  try {
    const decoded = await admin.auth().verifyIdToken(token);
    return decoded;
  } catch (error) {
    throw new Error('Invalid Firebase token');
  }
};

const getFirebaseUser = async (uid) => {
  if (!isFirebaseAvailable()) {
    throw new Error('Firebase not configured');
  }
  return await admin.auth().getUser(uid);
};

module.exports = { initFirebase, verifyFirebaseToken, getFirebaseUser, admin, isFirebaseAvailable };

