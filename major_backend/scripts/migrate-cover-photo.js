const { poolPromise, sql } = require('../config/db');

async function migrate() {
    try {
        const pool = await poolPromise;
        console.log('Checking for coverPhotoUrl column...');

        const checkColumn = await pool.request().query(`
            IF NOT EXISTS (
                SELECT * FROM sys.columns 
                WHERE object_id = OBJECT_ID('Users') AND name = 'coverPhotoUrl'
            )
            BEGIN
                ALTER TABLE Users ADD coverPhotoUrl NVARCHAR(MAX);
                PRINT 'Added column coverPhotoUrl to Users';
            END
            ELSE
            BEGIN
                PRINT 'Column coverPhotoUrl already exists';
            END
        `);

        console.log('Migration completed successfully');
        process.exit(0);
    } catch (err) {
        console.error('Migration failed:', err);
        process.exit(1);
    }
}

migrate();
