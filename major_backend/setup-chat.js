const { poolPromise, sql } = require('./config/db');

async function setupChat() {
    try {
        const pool = await poolPromise;
        console.log('Setting up chat tables...');

        // 1. Create ChatRequests Table (For "Message Requests" feature)
        await pool.request().query(`
            IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='ChatRequests' AND xtype='U')
            BEGIN
                CREATE TABLE ChatRequests (
                    id INT PRIMARY KEY IDENTITY(1,1),
                    senderUid NVARCHAR(128) NOT NULL,
                    receiverUid NVARCHAR(128) NOT NULL,
                    status NVARCHAR(20) DEFAULT 'pending', -- pending, accepted, rejected, blocked
                    createdAt DATETIME DEFAULT GETUTCDATE(),
                    updatedAt DATETIME DEFAULT GETUTCDATE(),
                    CONSTRAINT UK_ChatRequests_Pair UNIQUE(senderUid, receiverUid)
                )
                PRINT 'Created ChatRequests table';
            END
        `);

        // 2. Create Messages Table
        await pool.request().query(`
            IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='Messages' AND xtype='U')
            BEGIN
                CREATE TABLE Messages (
                    id INT PRIMARY KEY IDENTITY(1,1),
                    senderUid NVARCHAR(128) NOT NULL,
                    receiverUid NVARCHAR(128) NOT NULL,
                    content NVARCHAR(MAX),
                    isRead BIT DEFAULT 0,
                    createdAt DATETIME DEFAULT GETUTCDATE()
                )
                PRINT 'Created Messages table';
            END
        `);

        // 3. Add Indexes for Performance
        await pool.request().query(`
            IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name='IX_Messages_SenderReceiver')
            BEGIN
                CREATE INDEX IX_Messages_SenderReceiver ON Messages(senderUid, receiverUid, createdAt);
                PRINT 'Created Index IX_Messages_SenderReceiver';
            END
        `);

        console.log('Chat setup completed successfully');
        process.exit(0);
    } catch (err) {
        console.error('Chat setup failed:', err);
        process.exit(1);
    }
}

setupChat();
