const { poolPromise } = require('./config/db');

async function checkTokens() {
    try {
        const pool = await poolPromise;
        const result = await pool.request().query('SELECT id, fullName, firebaseUid, fcmToken FROM Users');

        console.log('--- User Tokens ---');
        result.recordset.forEach(user => {
            console.log(`User: ${user.fullName} (${user.firebaseUid})`);
            console.log(`Token: ${user.fcmToken ? user.fcmToken.substring(0, 20) + '...' : 'NULL'}`);
            console.log('---');
        });

    } catch (err) {
        console.error('Error:', err);
    } finally {
        process.exit();
    }
}

checkTokens();
