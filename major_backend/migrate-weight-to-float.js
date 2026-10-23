const { poolPromise, sql } = require('./config/db');

async function migrate() {
    try {
        const pool = await poolPromise;
        console.log('Changing weight column type to FLOAT...');

        await pool.request().query(`
            ALTER TABLE Users ALTER COLUMN weight FLOAT;
            ALTER TABLE Users ALTER COLUMN height FLOAT;
        `);

        console.log('Migration completed successfully');
        process.exit(0);
    } catch (err) {
        console.error('Migration failed:', err);
        process.exit(1);
    }
}

migrate();
