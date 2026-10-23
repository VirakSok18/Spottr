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

async function fixSchema() {
    try {
        let pool = await sql.connect(config);
        console.log('Connected to database');

        console.log('Checking for parentCommentId in Comments table...');
        const checkResult = await pool.request().query(`
            IF NOT EXISTS (
                SELECT * FROM sys.columns 
                WHERE object_id = OBJECT_ID('Comments') AND name = 'parentCommentId'
            )
            BEGIN
                ALTER TABLE Comments ADD parentCommentId INT NULL;
                ALTER TABLE Comments ADD CONSTRAINT FK_Comments_Parent FOREIGN KEY (parentCommentId) REFERENCES Comments(id);
                SELECT 'Column Added' as Status;
            END
            ELSE
            BEGIN
                SELECT 'Column Already Exists' as Status;
            END
        `);

        console.log('Result:', checkResult.recordset[0].Status);

        await pool.close();
    } catch (err) {
        console.error('Error fixing schema:', err);
    }
}

fixSchema();
