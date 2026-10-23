const { poolPromise, sql } = require('./config/db');

async function createTable() {
    try {
        const pool = await poolPromise;
        await pool.request().query(`
            IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='Users' AND xtype='U')
            CREATE TABLE Users (
                id INT PRIMARY KEY IDENTITY(1,1),
                firebaseUid NVARCHAR(128) NOT NULL UNIQUE,
                fullName NVARCHAR(255),
                email NVARCHAR(255) UNIQUE,
                phone NVARCHAR(20),
                gender NVARCHAR(20),
                age INT,
                weight INT,
                height INT,
                createdAt DATETIME DEFAULT GETDATE(),
                updatedAt DATETIME DEFAULT GETDATE()
            )
        `);
        console.log('Users table checked/created successfully');
        process.exit(0);
    } catch (err) {
        console.error('Error creating table:', err);
        process.exit(1);
    }
}

createTable();
