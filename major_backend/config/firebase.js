const admin = require('firebase-admin');

let serviceAccount;
try {
    // In production, paste the JSON into a FIREBASE_SERVICE_ACCOUNT environment variable
    if (process.env.FIREBASE_SERVICE_ACCOUNT) {
        serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
    } else {
        // Fallback for local development
        serviceAccount = require('../firebase-service-account.json');
    }
} catch (error) {
    console.error('Error loading Firebase configuration:', error);
}

if (!admin.apps.length) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
}

module.exports = admin;
