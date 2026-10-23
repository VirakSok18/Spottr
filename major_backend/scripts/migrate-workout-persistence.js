const { poolPromise, sql } = require('../config/db');

async function migrate() {
    try {
        const pool = await poolPromise;
        console.log('Migrating database schema for personalized plans and progress...');

        const query1 = `
            IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[PersonalizedWorkoutPlans]') AND type in (N'U'))
            BEGIN
                CREATE TABLE [dbo].[PersonalizedWorkoutPlans] (
                    [id] INT IDENTITY(1,1) PRIMARY KEY,
                    [firebaseUid] NVARCHAR(255) NOT NULL,
                    [planType] NVARCHAR(50) NOT NULL,
                    [planTitle] NVARCHAR(255) NOT NULL,
                    [planData] NVARCHAR(MAX) NOT NULL,
                    [createdAt] DATETIME DEFAULT GETDATE(),
                    [updatedAt] DATETIME DEFAULT GETDATE()
                );
            END
        `;

        const query2 = `
            IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[WorkoutDayProgress]') AND type in (N'U'))
            BEGIN
                CREATE TABLE [dbo].[WorkoutDayProgress] (
                    [id] INT IDENTITY(1,1) PRIMARY KEY,
                    [firebaseUid] NVARCHAR(255) NOT NULL,
                    [planTitle] NVARCHAR(255) NOT NULL,
                    [dayNumber] INT NOT NULL,
                    [completedAt] DATETIME DEFAULT GETDATE(),
                    CONSTRAINT [UC_User_Plan_Day] UNIQUE ([firebaseUid], [planTitle], [dayNumber])
                );
            END
        `;

        console.log('Creating PersonalizedWorkoutPlans table...');
        await pool.request().query(query1);

        console.log('Creating WorkoutDayProgress table...');
        await pool.request().query(query2);

        console.log('Database migration completed successfully.');
        process.exit(0);
    } catch (err) {
        console.error('Migration failed:', err);
        process.exit(1);
    }
}

migrate();
