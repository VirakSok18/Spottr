const { poolPromise, sql } = require('./config/db');

async function migrate() {
    try {
        const pool = await poolPromise;
        console.log('Starting workout fields migration...');

        const columnsToAdd = [
            { name: 'workout_location', type: 'NVARCHAR(255)' },
            { name: 'equipment_list', type: 'NVARCHAR(MAX)' },
            { name: 'focus_areas', type: 'NVARCHAR(MAX)' },
            { name: 'workout_frequency', type: 'INT' },
            { name: 'training_level', type: 'NVARCHAR(255)' },
            { name: 'is_setup_completed', type: 'BIT DEFAULT 0' }
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
