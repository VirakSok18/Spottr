const { poolPromise, sql } = require('./config/db');

async function checkSchema() {
    try {
        const pool = await poolPromise;
        console.log('Checking Users table schema...');

        const result = await pool.request().query(`
            SELECT COLUMN_NAME, DATA_TYPE 
            FROM INFORMATION_SCHEMA.COLUMNS 
            WHERE TABLE_NAME = 'Users'
        `);

        console.log('Columns found:', result.recordset);
        process.exit(0);
    } catch (err) {
        console.error('Schema check failed:', err);
        process.exit(1);
    }
}

checkSchema();
