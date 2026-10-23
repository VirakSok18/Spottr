const { poolPromise, sql } = require('../config/db');

async function migrate() {
    try {
        const pool = await poolPromise;
        console.log('Migrating database schema for Premium features...');

        const query1 = `
            IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Users]') AND name = 'isPremium')
            BEGIN
                ALTER TABLE Users ADD isPremium BIT DEFAULT 0;
            END
        `;

        const query2 = `
            IF OBJECT_ID('dbo.DailyUsageLimits', 'U') IS NULL
            BEGIN
                CREATE TABLE DailyUsageLimits (
                    id INT IDENTITY(1,1) PRIMARY KEY,
                    firebaseUid NVARCHAR(255) NOT NULL,
                    limitType NVARCHAR(50) NOT NULL,
                    messageCount INT DEFAULT 0,
                    lastResetDate DATE DEFAULT GETDATE(),
                    CONSTRAINT UC_User_LimitType UNIQUE (firebaseUid, limitType)
                );
            END
        `;

        console.log('Adding isPremium column...');
        await pool.request().query(query1);

        console.log('Creating DailyUsageLimits table...');
        await pool.request().query(query2);

        console.log('Database migration completed successfully.');
        process.exit(0);
    } catch (err) {
        console.error('Migration failed:', err);
        process.exit(1);
    }
}
migrate();
