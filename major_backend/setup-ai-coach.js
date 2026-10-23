const { poolPromise, sql } = require('./config/db');

async function setupAICoach() {
    try {
        const pool = await poolPromise;
        console.log('Setting up AI Coach tables...');

        // 1. Create WorkoutLogs Table
        await pool.request().query(`
            IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='WorkoutLogs' AND xtype='U')
            BEGIN
                CREATE TABLE WorkoutLogs (
                    id INT PRIMARY KEY IDENTITY(1,1),
                    userUid NVARCHAR(128) NOT NULL,
                    workoutName NVARCHAR(255),
                    exercises NVARCHAR(MAX), -- JSON string
                    duration INT, -- in minutes
                    caloriesBurned INT,
                    createdAt DATETIME DEFAULT GETDATE(),
                    CONSTRAINT FK_WorkoutLogs_Users FOREIGN KEY (userUid) REFERENCES Users(firebaseUid) ON DELETE CASCADE
                )
                PRINT 'Created WorkoutLogs table';
            END
        `);

        // 2. Create UserPlans Table
        await pool.request().query(`
            IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='UserPlans' AND xtype='U')
            BEGIN
                CREATE TABLE UserPlans (
                    id INT PRIMARY KEY IDENTITY(1,1),
                    userUid NVARCHAR(128) NOT NULL,
                    planData NVARCHAR(MAX), -- JSON string
                    isAI BIT DEFAULT 0,
                    createdAt DATETIME DEFAULT GETDATE(),
                    CONSTRAINT FK_UserPlans_Users FOREIGN KEY (userUid) REFERENCES Users(firebaseUid) ON DELETE CASCADE
                )
                PRINT 'Created UserPlans table';
            END
        `);

        // 3. Create AICoachMessages Table
        await pool.request().query(`
            IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='AICoachMessages' AND xtype='U')
            BEGIN
                CREATE TABLE AICoachMessages (
                    id INT PRIMARY KEY IDENTITY(1,1),
                    userUid NVARCHAR(128) NOT NULL,
                    role NVARCHAR(20) NOT NULL, -- 'user' or 'assistant'
                    content NVARCHAR(MAX) NOT NULL,
                    createdAt DATETIME DEFAULT GETDATE(),
                    CONSTRAINT FK_AICoachMessages_Users FOREIGN KEY (userUid) REFERENCES Users(firebaseUid) ON DELETE CASCADE
                )
                PRINT 'Created AICoachMessages table';
            END
        `);

        console.log('AI Coach setup completed successfully');
        process.exit(0);
    } catch (err) {
        console.error('AI Coach setup failed:', err);
        process.exit(1);
    }
}

setupAICoach();
