const { poolPromise } = require('./config/db');

async function createOTPTable() {
    try {
        const pool = await poolPromise;
        await pool.request().query(`
            IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'PasswordResetOTPs')
            BEGIN
                CREATE TABLE PasswordResetOTPs (
                    id INT IDENTITY(1,1) PRIMARY KEY,
                    email NVARCHAR(255) NOT NULL,
                    code NVARCHAR(10) NOT NULL,
                    expiresAt DATETIME NOT NULL,
                    createdAt DATETIME DEFAULT GETDATE(),
                    isUsed BIT DEFAULT 0
                );
                CREATE INDEX IX_OTP_Email ON PasswordResetOTPs(email);
            END
        `);
        console.log('PasswordResetOTPs table ensured.');
        process.exit(0);
    } catch (err) {
        console.error('Error creating table:', err);
        process.exit(1);
    }
}

createOTPTable();
