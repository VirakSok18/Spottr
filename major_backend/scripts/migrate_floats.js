const { poolPromise, sql } = require('../config/db');

async function migrate() {
    try {
        const pool = await poolPromise;
        console.log('Migrating weight and height columns to FLOAT...');

        const query = `
            ALTER TABLE Users ALTER COLUMN weight FLOAT;
            ALTER TABLE Users ALTER COLUMN height FLOAT;
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
