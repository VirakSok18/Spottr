const { poolPromise, sql } = require('../config/db');

async function migrate() {
    try {
        const pool = await poolPromise;
        console.log('Migrating database schema for availability time spans...');

        const query = `
            IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('Users') AND name = 'availability_time_spans')
            BEGIN
                ALTER TABLE Users ADD availability_time_spans NVARCHAR(MAX) NULL;
                PRINT 'Added availability_time_spans column to Users table.';
            END
            ELSE
            BEGIN
                PRINT 'availability_time_spans column already exists.';
            END
        `;

        await pool.request().query(query);
        console.log('Database migration completed successfully.');
        process.exit(0);
    } catch (err) {
        console.error('Migration failed:', err);
        process.exit(1);
    }
}

migrate();
