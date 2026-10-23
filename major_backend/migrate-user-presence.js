const { poolPromise, sql } = require('./config/db');

async function migrate() {
    try {
        const pool = await poolPromise;
        console.log('Migrating Users table for Presence feature...');

        await pool.request().query(`
            IF NOT EXISTS (SELECT * FROM sys.columns WHERE Name = N'isOnline' AND Object_ID = OBJECT_ID(N'Users'))
            BEGIN
                ALTER TABLE Users ADD isOnline BIT DEFAULT 0;
            END

            IF NOT EXISTS (SELECT * FROM sys.columns WHERE Name = N'lastActive' AND Object_ID = OBJECT_ID(N'Users'))
            BEGIN
                ALTER TABLE Users ADD lastActive DATETIME NULL;
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
