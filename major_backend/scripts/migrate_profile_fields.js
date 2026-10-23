const { poolPromise, sql } = require('../config/db');

async function migrate() {
    try {
        const pool = await poolPromise;
        console.log('Migrating database schema...');

        const query = `
            IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('Users') AND name = 'bio')
            BEGIN
                ALTER TABLE Users ADD bio NVARCHAR(500) NULL;
            END

            IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('Users') AND name = 'looking_for')
            BEGIN
                ALTER TABLE Users ADD looking_for NVARCHAR(100) NULL;
            END

            IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('Users') AND name = 'preferences')
            BEGIN
                ALTER TABLE Users ADD preferences NVARCHAR(MAX) NULL;
            END

            IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('Users') AND name = 'availability')
            BEGIN
                ALTER TABLE Users ADD availability NVARCHAR(100) NULL;
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
