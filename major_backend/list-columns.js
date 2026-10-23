const { poolPromise, sql } = require('./config/db');

async function check() {
    try {
        const pool = await poolPromise;
        const columns = await pool.request().query("SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Workouts'");
        const columnNames = columns.recordset.map(row => row.COLUMN_NAME);
        console.log('COLUMN_NAMES_START');
        console.log(columnNames.join(','));
        console.log('COLUMN_NAMES_END');
        process.exit(0);
    } catch (err) {
        console.error(err);
        process.exit(1);
    }
}

check();
