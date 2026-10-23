const sql = require('mssql');
require('dotenv').config();

const config = {
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    server: process.env.DB_SERVER,
    database: process.env.DB_DATABASE,
    options: {
        encrypt: true,
        trustServerCertificate: true
    }
};

async function diagnose() {
    try {
        let pool = await sql.connect(config);
        console.log('Connected to database');

        console.log('Listing tables:');
        const tables = await pool.request().query("SELECT name FROM sysobjects WHERE xtype='U'");
        console.log(tables.recordset);

        for (let table of tables.recordset) {
            console.log(`\nColumns for ${table.name}:`);
            const columns = await pool.request().query(`
                SELECT COLUMN_NAME, DATA_TYPE 
                FROM INFORMATION_SCHEMA.COLUMNS 
                WHERE TABLE_NAME = '${table.name}'
            `);
            console.table(columns.recordset);
        }

        await pool.close();
    } catch (err) {
        console.error('Error diagnosing:', err);
    }
}

diagnose();
