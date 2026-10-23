const { poolPromise, sql } = require('../config/db');

async function migrate() {
    try {
        const pool = await poolPromise;
        console.log('Connecting to database...');

        // Add saved_addresses column if it doesn't exist
        await pool.request().query(`
            IF NOT EXISTS (SELECT * FROM sys.columns 
                          WHERE object_id = OBJECT_ID('Users') 
                          AND name = 'saved_addresses')
            BEGIN
                ALTER TABLE Users ADD saved_addresses NVARCHAR(MAX);
                PRINT 'Added saved_addresses column to Users table.';
            END
            ELSE
            BEGIN
                PRINT 'saved_addresses column already exists.';
            END
        `);

        console.log('Migration completed successfully.');
        process.exit(0);
    } catch (err) {
        console.error('Migration failed:', err);
        process.exit(1);
    }
}

migrate();
