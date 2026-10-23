const { poolPromise, sql } = require('./config/db');

async function migrate() {
    try {
        const pool = await poolPromise;
        console.log('Migrating Messages table for Reply feature...');

        await pool.request().query(`
            IF NOT EXISTS (SELECT * FROM sys.columns WHERE Name = N'parentId' AND Object_ID = OBJECT_ID(N'Messages'))
            BEGIN
                ALTER TABLE Messages ADD parentId INT NULL;
                ALTER TABLE Messages ADD CONSTRAINT FK_Messages_Parent FOREIGN KEY (parentId) REFERENCES Messages(id);
            END

            IF NOT EXISTS (SELECT * FROM sys.columns WHERE Name = N'parentContent' AND Object_ID = OBJECT_ID(N'Messages'))
            BEGIN
                ALTER TABLE Messages ADD parentContent NVARCHAR(MAX) NULL;
            END

            IF NOT EXISTS (SELECT * FROM sys.columns WHERE Name = N'parentMediaType' AND Object_ID = OBJECT_ID(N'Messages'))
            BEGIN
                ALTER TABLE Messages ADD parentMediaType NVARCHAR(20) NULL;
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
