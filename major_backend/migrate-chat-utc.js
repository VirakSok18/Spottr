const { poolPromise, sql } = require('./config/db');

async function migrate() {
    try {
        const pool = await poolPromise;
        console.log('Migrating chat timestamps to UTC...');

        // 1. Update existing messages (subtract 7 hours because they were stored as local +7)
        // Adjust this if your local offset is different, but based on current info it's +7
        await pool.request().query(`
            UPDATE Messages SET createdAt = DATEADD(hour, -7, createdAt);
            UPDATE ChatRequests SET createdAt = DATEADD(hour, -7, createdAt), updatedAt = DATEADD(hour, -7, updatedAt);
        `);
        console.log('Updated existing record timestamps.');

        // 2. Change column defaults to GETUTCDATE()
        // We need to find and drop existing default constraints first
        const queries = [
            `
            DECLARE @ConstraintName nvarchar(200)
            SELECT @ConstraintName = Name FROM SYS.DEFAULT_CONSTRAINTS
            WHERE PARENT_OBJECT_ID = OBJECT_ID('Messages') AND PARENT_COLUMN_ID = (SELECT column_id FROM sys.columns WHERE name = 'createdAt' AND object_id = OBJECT_ID('Messages'))
            IF @ConstraintName IS NOT NULL
                EXEC('ALTER TABLE Messages DROP CONSTRAINT ' + @ConstraintName)
            ALTER TABLE Messages ADD DEFAULT GETUTCDATE() FOR createdAt
            `,
            `
            DECLARE @ConstraintName nvarchar(200)
            SELECT @ConstraintName = Name FROM SYS.DEFAULT_CONSTRAINTS
            WHERE PARENT_OBJECT_ID = OBJECT_ID('ChatRequests') AND PARENT_COLUMN_ID = (SELECT column_id FROM sys.columns WHERE name = 'createdAt' AND object_id = OBJECT_ID('ChatRequests'))
            IF @ConstraintName IS NOT NULL
                EXEC('ALTER TABLE ChatRequests DROP CONSTRAINT ' + @ConstraintName)
            ALTER TABLE ChatRequests ADD DEFAULT GETUTCDATE() FOR createdAt
            `,
            `
            DECLARE @ConstraintName nvarchar(200)
            SELECT @ConstraintName = Name FROM SYS.DEFAULT_CONSTRAINTS
            WHERE PARENT_OBJECT_ID = OBJECT_ID('ChatRequests') AND PARENT_COLUMN_ID = (SELECT column_id FROM sys.columns WHERE name = 'updatedAt' AND object_id = OBJECT_ID('ChatRequests'))
            IF @ConstraintName IS NOT NULL
                EXEC('ALTER TABLE ChatRequests DROP CONSTRAINT ' + @ConstraintName)
            ALTER TABLE ChatRequests ADD DEFAULT GETUTCDATE() FOR updatedAt
            `
        ];

        for (const q of queries) {
            await pool.request().query(q);
        }

        console.log('Migration completed successfully.');
        process.exit(0);
    } catch (err) {
        console.error('Migration failed:', err);
        process.exit(1);
    }
}

migrate();
