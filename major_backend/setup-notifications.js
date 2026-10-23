const { poolPromise } = require('./config/db');

async function setupNotifications() {
    try {
        const pool = await poolPromise;
        console.log('Setting up Notifications table...');

        await pool.request().query(`
            IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='Notifications' AND xtype='U')
            BEGIN
                CREATE TABLE Notifications (
                    id INT PRIMARY KEY IDENTITY(1,1),
                    recipientUid NVARCHAR(128) NOT NULL,
                    senderUid NVARCHAR(128) NULL, -- NULL for system notifications
                    type NVARCHAR(50) NOT NULL, -- 'like', 'comment', 'reminder', 'system'
                    title NVARCHAR(255),
                    message NVARCHAR(MAX),
                    referenceId NVARCHAR(255), -- ID of post, comment, or route
                    isRead BIT DEFAULT 0,
                    createdAt DATETIME DEFAULT GETDATE()
                )
                PRINT 'Created Notifications table';
            END
        `);

        console.log('Notifications setup completed successfully');
        process.exit(0);
    } catch (err) {
        console.error('Notifications setup failed:', err);
        process.exit(1);
    }
}

setupNotifications();
