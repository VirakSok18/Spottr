const { poolPromise, sql } = require('./config/db');

async function migrate() {
    try {
        const pool = await poolPromise;
        console.log('Starting fitness_goal column migration...');

        await pool.request().query(`
            IF NOT EXISTS (
                SELECT * FROM sys.columns 
                WHERE object_id = OBJECT_ID('Users') AND name = 'fitness_goal'
            )
            BEGIN
                ALTER TABLE Users ADD fitness_goal NVARCHAR(255);
                PRINT 'Added column fitness_goal';
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
