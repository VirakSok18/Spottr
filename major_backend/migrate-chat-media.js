const { poolPromise, sql } = require('./config/db');

async function migrate() {
    try {
        const pool = await poolPromise;
        console.log('Starting migration...');

        // 1. Add media columns to Messages
        await pool.request().query(`
            IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('Messages') AND name = 'mediaUrl')
            BEGIN
                ALTER TABLE Messages ADD mediaUrl NVARCHAR(MAX), mediaType NVARCHAR(20);
                PRINT 'Added mediaUrl and mediaType to Messages';
            END
        `);

        // 2. Create Blocks Table
        await pool.request().query(`
            IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='Blocks' AND xtype='U')
            BEGIN
                CREATE TABLE Blocks (
                    id INT PRIMARY KEY IDENTITY(1,1),
                    blockerUid NVARCHAR(128) NOT NULL,
                    blockedUid NVARCHAR(128) NOT NULL,
                    createdAt DATETIME DEFAULT GETDATE(),
                    CONSTRAINT UK_Blocks UNIQUE(blockerUid, blockedUid)
                );
                PRINT 'Created Blocks table';
            END
        `);

        console.log('Migration completed successfully');
        process.exit(0);
    } catch (err) {
        console.error('Migration failed:', err);
        process.exit(1);
    }
}

migrate();
