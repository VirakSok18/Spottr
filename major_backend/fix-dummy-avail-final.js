const { poolPromise, sql } = require('./config/db');
require('dotenv').config();

const potentialOptions = ["Morning", "Afternoon", "Evening", "Night"];
const timeSpansMap = {
    "Morning": "06:00 - 09:00",
    "Afternoon": "12:00 - 15:00",
    "Evening": "17:00 - 21:00",
    "Night": "21:00 - 05:00"
};

async function run() {
    let pool;
    try {
        pool = await poolPromise;

        const usersRes = await pool.request().query("SELECT firebaseUid FROM Users WHERE email LIKE 'dummy%@spottr.com'");
        const users = usersRes.recordset;

        console.log(`Fixing Availability & Time Spans for ${users.length} dummy users to match the "Virak" style...`);

        for (const user of users) {
            // Randomly pick 1 to 3 items
            const shuffled = [...potentialOptions].sort(() => 0.5 - Math.random());
            const selected = shuffled.slice(0, 1 + Math.floor(Math.random() * 3));
            
            const selectedSpans = {};
            selected.forEach(opt => {
                selectedSpans[opt] = timeSpansMap[opt];
            });

            await pool.request()
                .input('uid', sql.NVARCHAR, user.firebaseUid)
                .input('avail', sql.NVARCHAR, JSON.stringify(selected))
                .input('spans', sql.NVARCHAR, JSON.stringify(selectedSpans))
                .query(`
                    UPDATE Users 
                    SET availability = @avail,
                        availability_time_spans = @spans,
                        updatedAt = GETUTCDATE()
                    WHERE firebaseUid = @uid
                `);

            console.log(`User ${user.firebaseUid}: ${JSON.stringify(selected)} with spans.`);
        }

        console.log('--- DUMMY SCHEDULES ARE NOW FIXED! ---');

    } catch (err) {
        console.error('Error:', err);
    } finally {
        if (pool) process.exit();
    }
}

run();
