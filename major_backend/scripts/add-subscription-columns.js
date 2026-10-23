const { poolPromise, sql } = require('../config/db');
require('dotenv').config();

async function migrate() {
    try {
        console.log('--- Starting Subscription Columns Migration ---');
        const pool = await poolPromise;

        // Add columns if they don't exist
        await pool.request().query(`
            IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('Users') AND name = 'planType')
            ALTER TABLE Users ADD planType NVARCHAR(50) NULL;

            IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('Users') AND name = 'stripeCustomerId')
            ALTER TABLE Users ADD stripeCustomerId NVARCHAR(100) NULL;

            IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('Users') AND name = 'stripeSubscriptionId')
            ALTER TABLE Users ADD stripeSubscriptionId NVARCHAR(100) NULL;

            IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('Users') AND name = 'premiumUntil')
            ALTER TABLE Users ADD premiumUntil DATETIME NULL;
        `);

        console.log('Migration successful: Subscription columns added/verified.');
    } catch (err) {
        console.error('Migration failed:', err.message);
    } finally {
        process.exit();
    }
}

migrate();
