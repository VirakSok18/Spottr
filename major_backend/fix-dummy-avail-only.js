const { poolPromise, sql } = require('./config/db');
require('dotenv').config();

const options = ["Morning", "Afternoon", "Evening", "Night"];

async function run() {
    let pool;
    try {
        pool = await poolPromise;

        const usersRes = await pool.request().query("SELECT firebaseUid FROM Users WHERE email LIKE 'dummy%@spottr.com'");
        const users = usersRes.recordset;

        console.log(`Fixing availability for ${users.length} dummy users...`);

        for (const user of users) {
            // Shuffle and pick 1-3 random options from [Morning, Afternoon, Evening, Night]
            const shuffled = [...options].sort(() => 0.5 - Math.random());
            const selected = shuffled.slice(0, 1 + Math.floor(Math.random() * 3));

            await pool.request()
                .input('uid', sql.NVARCHAR, user.firebaseUid)
                .input('avail', sql.NVARCHAR, JSON.stringify(selected))
                .query(`
                    UPDATE Users 
                    SET availability = @avail,
                        availability_time_spans = NULL,
                        updatedAt = GETUTCDATE()
                    WHERE firebaseUid = @uid
                `);

            console.log(`Fixed availability for: ${user.firebaseUid} -> ${JSON.stringify(selected)}`);
        }

        console.log('--- DUMMY AVAILABILITY IS NOW CORRECT (Morning/Afternoon/Evening/Night) ---');

    } catch (err) {
        console.error('Error:', err);
    } finally {
        if (pool) process.exit();
    }
}

run();
