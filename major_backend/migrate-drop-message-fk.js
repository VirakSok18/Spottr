const { poolPromise } = require('./config/db');

async function migrate() {
    try {
        const pool = await poolPromise;
        console.log('Dropping Foreign Key constraint on Messages.parentId...');

        // Find the constraint name dynamically and drop it
        await pool.request().query(`
            DECLARE @constraintName NVARCHAR(200);
            
            SELECT @constraintName = name 
            FROM sys.foreign_keys 
            WHERE parent_object_id = OBJECT_ID('Messages') 
            AND referenced_object_id = OBJECT_ID('Messages');

            IF @constraintName IS NOT NULL
            BEGIN
                DECLARE @sql NVARCHAR(MAX);
                SET @sql = 'ALTER TABLE Messages DROP CONSTRAINT ' + @constraintName;
                EXEC(@sql);
                PRINT 'Dropped constraint: ' + @constraintName;
            END
            ELSE
            BEGIN
                PRINT 'No self-referencing foreign key found on Messages table.';
            END
        `);

        console.log('Migration completed successfully.');
        process.exit(0);
    } catch (err) {
        console.error('Migration failed:', err);
        process.exit(1);
    }
}

migrate();
