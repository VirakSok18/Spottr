const { poolPromise, sql } = require('./config/db');

async function migrate() {
    try {
        const pool = await poolPromise;
        console.log('Connected to MSSQL for migration...');

        const query = `
            IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('Users') AND name = 'latitude')
            ALTER TABLE Users ADD latitude FLOAT NULL;

            IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('Users') AND name = 'longitude')
            ALTER TABLE Users ADD longitude FLOAT NULL;

            IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('Users') AND name = 'location_label')
            ALTER TABLE Users ADD location_label NVARCHAR(MAX) NULL;

            IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('Users') AND name = 'location_privacy')
            ALTER TABLE Users ADD location_privacy NVARCHAR(50) DEFAULT 'city';

            IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('Users') AND name = 'is_location_paused')
            ALTER TABLE Users ADD is_location_paused BIT DEFAULT 0;
        `;

        await pool.request().query(query);
        console.log('Database schema updated successfully for Location feature.');
    } catch (err) {
        console.error('Migration failed:', err);
    } finally {
        process.exit();
    }
}

migrate();
