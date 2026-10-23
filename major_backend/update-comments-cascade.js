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

async function updateCascadeDelete() {
    try {
        let pool = await sql.connect(config);
        console.log('Connected to database');

        console.log('Updating FK constraint for cascade deletion...');
        await pool.request().query(`
            -- Drop existing constraint if it exists
            IF EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_Comments_Parent')
            BEGIN
                ALTER TABLE Comments DROP CONSTRAINT FK_Comments_Parent;
            END

            -- Add constraint with ON DELETE CASCADE
            ALTER TABLE Comments 
            ADD CONSTRAINT FK_Comments_Parent 
            FOREIGN KEY (parentCommentId) 
            REFERENCES Comments(id) 
            ON DELETE CASCADE;
            
            SELECT 'Constraint Updated successfully' as Status;
        `);

        console.log('Constraint updated successfully');
        await pool.close();
    } catch (err) {
        console.error('Error updating constraint:', err);
    }
}

updateCascadeDelete();
