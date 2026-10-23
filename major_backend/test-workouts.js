const { poolPromise, sql } = require('./config/db');

async function check() {
    try {
        const pool = await poolPromise;
        console.log('Querying Workouts table...');

        // Query sample data
        const res = await pool.request().query('SELECT TOP 5 * FROM Workouts');
        console.log('--- Sample Data ---');
        console.log('Rows found:', res.recordset.length);
        if (res.recordset.length > 0) {
            console.log(JSON.stringify(res.recordset[0], null, 2));
        }

        // Query schema
        const columns = await pool.request().query("SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Workouts'");
        console.log('\n--- Table Schema ---');
        console.log(JSON.stringify(columns.recordset, null, 2));

        process.exit(0);
    } catch (err) {
        console.error('Query failed:', err);
        process.exit(1);
    }
}

check();
