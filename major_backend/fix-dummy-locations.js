const { poolPromise, sql } = require('./config/db');
require('dotenv').config();

async function run() {
    let pool;
    try {
        pool = await poolPromise;
        
        // Base coordinates for Phnom Penh
        const baseLat = 11.5621;
        const baseLng = 104.9160;

        // Fetch dummy users
        const usersRes = await pool.request().query("SELECT firebaseUid FROM Users WHERE email LIKE 'dummy%@spottr.com'");
        const users = usersRes.recordset;

        console.log(`Updating ${users.length} dummy users with random locations around Phnom Penh...`);

        for (const user of users) {
            // Generate random offset (approx -5km to +5km)
            // 0.01 degree is approx 1.1km
            const latOffset = (Math.random() - 0.5) * 0.1; 
            const lngOffset = (Math.random() - 0.5) * 0.1;

            const finalLat = baseLat + latOffset;
            const finalLng = baseLng + lngOffset;

            await pool.request()
                .input('uid', sql.NVARCHAR, user.firebaseUid)
                .input('lat', sql.FLOAT, finalLat)
                .input('lng', sql.FLOAT, finalLng)
                .query(`
                    UPDATE Users 
                    SET latitude = @lat, 
                        longitude = @lng,
                        location_label = 'Phnom Penh, Cambodia',
                        location_privacy = 'full',
                        is_setup_completed = 1
                    WHERE firebaseUid = @uid
                `);
        }

        console.log('--- Successfully updated dummy user locations ---');

    } catch (err) {
        console.error('Error:', err);
    } finally {
        if (pool) process.exit();
    }
}

run();
