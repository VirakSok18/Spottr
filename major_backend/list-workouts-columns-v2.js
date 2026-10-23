const { poolPromise, sql } = require('./config/db');

async function check() {
    try {
        const pool = await poolPromise;
        const columns = await pool.request().query("SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Workouts'");
        const columnNames = columns.recordset.map(row => row.COLUMN_NAME);
        console.log('--- Workouts Table Columns ---');
        console.log(columnNames.join(', '));
        process.exit(0);
    } catch (err) {
        console.error(err);
        process.exit(1);
    }
}

check();
