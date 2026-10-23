const { poolPromise, sql } = require('./config/db');

async function check() {
    try {
        const pool = await poolPromise;
        const columns = await pool.request().query("SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Users'");
        console.log('--- Users Table Columns ---');
        columns.recordset.forEach(row => console.log(row.COLUMN_NAME));
        process.exit(0);
    } catch (err) {
        console.error(err);
        process.exit(1);
    }
}

check();
