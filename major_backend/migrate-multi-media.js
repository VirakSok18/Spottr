const { poolPromise, sql } = require('./config/db');

async function migrateMultiMedia() {
    try {
        const pool = await poolPromise;
        console.log('Starting multi-media migration...');

        // 1. Create PostMedia Table
        await pool.request().query(`
            IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='PostMedia' AND xtype='U')
            BEGIN
                CREATE TABLE PostMedia (
                    id INT PRIMARY KEY IDENTITY(1,1),
                    postId INT NOT NULL,
                    mediaUrl NVARCHAR(MAX) NOT NULL,
                    mediaType NVARCHAR(50) NOT NULL,
                    createdAt DATETIME DEFAULT GETDATE(),
                    CONSTRAINT FK_PostMedia_Posts FOREIGN KEY (postId) REFERENCES Posts(id) ON DELETE CASCADE
                )
                PRINT 'Created PostMedia table';
            END
        `);

        // 2. Migrate existing media if any
        console.log('Migrating existing media from Posts table...');
        await pool.request().query(`
            INSERT INTO PostMedia (postId, mediaUrl, mediaType, createdAt)
            SELECT id, mediaUrl, mediaType, createdAt
            FROM Posts
            WHERE mediaUrl IS NOT NULL 
            AND id NOT IN (SELECT DISTINCT postId FROM PostMedia)
        `);
        console.log('Migration completed successfully');
        process.exit(0);
    } catch (err) {
        console.error('Migration failed:', err);
        process.exit(1);
    }
}

migrateMultiMedia();
