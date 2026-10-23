const { poolPromise, sql } = require('./config/db');

async function migrate() {
    try {
        const pool = await poolPromise;

        // Check if column exists
        const check = await pool.request().query(`
            SELECT COLUMN_NAME 
            FROM INFORMATION_SCHEMA.COLUMNS 
            WHERE TABLE_NAME = 'Users' AND COLUMN_NAME = 'fcmToken'
        `);

        if (check.recordset.length === 0) {
            console.log('Adding fcmToken column to Users table...');
            await pool.request().query(`
                ALTER TABLE Users
                ADD fcmToken NVARCHAR(MAX) NULL
            `);
            console.log('Column fcmToken added successfully.');
        } else {
            console.log('Column fcmToken already exists.');
        }

    } catch (err) {
        console.error('Migration failed:', err);
    } finally {
        process.exit();
    }
}

migrate();
