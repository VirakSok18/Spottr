const { poolPromise, sql } = require('./config/db');
const fs = require('fs');

async function exportTable() {
    try {
        const pool = await poolPromise;
        const tableName = '[Copy of Workout_Program_LibraryCSV]';

        console.log(`Exporting table: ${tableName}`);
        const result = await pool.request().query(`
            SELECT * FROM ${tableName}
        `);

        fs.writeFileSync('library_data.json', JSON.stringify(result.recordset, null, 2));
        console.log('Data exported to library_data.json');

    } catch (err) {
        console.error('Error:', err);
    } finally {
        process.exit();
    }
}

exportTable();
