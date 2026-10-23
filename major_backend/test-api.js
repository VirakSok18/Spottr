const { poolPromise, sql } = require('./config/db');
const path = require('path');

// Mock request and response
const req = {
    user: { uid: 'some-test-uid' } // Replace with a real UID if you want to test DB
};

const res = {
    status: (code) => ({
        json: (data) => console.log(`Status ${code}:`, JSON.stringify(data, null, 2))
    })
};

// Import and run the logic directly
const workoutRoutes = require('./routes/workoutRoutes');

async function test() {
    console.log('Testing Suggested Plans logic...');
    // We need to fetch a real user UID to test the full flow
    const pool = await poolPromise;
    const user = await pool.request().query('SELECT TOP 1 firebaseUid FROM Users');

    if (user.recordset.length === 0) {
        console.log('No users found in DB to test with.');
        process.exit(0);
    }

    req.user.uid = user.recordset[0].firebaseUid;
    console.log(`Using UID: ${req.user.uid}`);

    // Since it's a router.get, we'll just extract the logic for a quick test
    // Or we can mock the entire flow.
    // Let's just run the route handler manually.

    const handler = workoutRoutes.stack.find(s => s.route && s.route.path === '/suggested-plans').route.stack[1].handle;

    await handler(req, res);
    process.exit(0);
}

test();
