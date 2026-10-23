const { poolPromise, sql } = require('./config/db');

async function migrate() {
    try {
        const pool = await poolPromise;
        console.log('Starting database migration...');

        const columnsToAdd = [
            { name: 'phone', type: 'NVARCHAR(20)' },
            { name: 'gender', type: 'NVARCHAR(20)' },
            { name: 'age', type: 'INT' },
            { name: 'weight', type: 'INT' },
            { name: 'height', type: 'INT' },
            { name: 'updatedAt', type: 'DATETIME DEFAULT GETDATE()' }
        ];

        for (const col of columnsToAdd) {
            await pool.request().query(`
                IF NOT EXISTS (
                    SELECT * FROM sys.columns 
                    WHERE object_id = OBJECT_ID('Users') AND name = '${col.name}'
                )
                BEGIN
                    ALTER TABLE Users ADD ${col.name} ${col.type};
                    PRINT 'Added column ${col.name}';
                END
            `);
        }

        console.log('Migration completed successfully');
        process.exit(0);
    } catch (err) {
        console.error('Migration failed:', err);
        process.exit(1);
    }
}

migrate();
