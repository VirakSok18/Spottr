const { poolPromise, sql } = require('./config/db');

async function migrate() {
    try {
        const pool = await poolPromise;
        console.log('Adding weight_unit column to Users table...');

        await pool.request().query(`
            IF NOT EXISTS (
                SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
                WHERE TABLE_NAME = 'Users' AND COLUMN_NAME = 'weight_unit'
            )
            BEGIN
                ALTER TABLE Users ADD weight_unit NVARCHAR(10) DEFAULT 'kg';
                EXEC('UPDATE Users SET weight_unit = ''kg'' WHERE weight_unit IS NULL');
            END
        `);

        console.log('Migration successful: weight_unit column added.');
        process.exit(0);
    } catch (err) {
        console.error('Migration failed:', err);
        process.exit(1);
    }
}

migrate();
