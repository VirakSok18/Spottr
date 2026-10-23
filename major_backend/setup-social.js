const { poolPromise, sql } = require('./config/db');

async function setupSocial() {
    try {
        const pool = await poolPromise;
        console.log('Setting up social tables...');

        // 1. Ensure Users table has all necessary columns
        const userColumns = [
            { name: 'profilePictureUrl', type: 'NVARCHAR(MAX)' },
            { name: 'weight_unit', type: 'NVARCHAR(20)' },
            { name: 'fitness_goal', type: 'NVARCHAR(255)' },
            { name: 'workout_location', type: 'NVARCHAR(255)' },
            { name: 'equipment_list', type: 'NVARCHAR(MAX)' },
            { name: 'focus_areas', type: 'NVARCHAR(MAX)' },
            { name: 'workout_frequency', type: 'INT' },
            { name: 'training_level', type: 'NVARCHAR(50)' },
            { name: 'is_setup_completed', type: 'BIT' }
        ];

        for (const col of userColumns) {
            await pool.request().query(`
                IF NOT EXISTS (
                    SELECT * FROM sys.columns 
                    WHERE object_id = OBJECT_ID('Users') AND name = '${col.name}'
                )
                BEGIN
                    ALTER TABLE Users ADD ${col.name} ${col.type};
                    PRINT 'Added column ${col.name} to Users';
                END
            `);
        }

        // 2. Create Posts Table
        await pool.request().query(`
            IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='Posts' AND xtype='U')
            BEGIN
                CREATE TABLE Posts (
                    id INT PRIMARY KEY IDENTITY(1,1),
                    userUid NVARCHAR(128) NOT NULL,
                    content NVARCHAR(MAX),
                    mediaUrl NVARCHAR(MAX),
                    mediaType NVARCHAR(50),
                    createdAt DATETIME DEFAULT GETDATE()
                )
                PRINT 'Created Posts table';
            END
        `);

        // 3. Create Likes Table
        await pool.request().query(`
            IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='Likes' AND xtype='U')
            BEGIN
                CREATE TABLE Likes (
                    id INT PRIMARY KEY IDENTITY(1,1),
                    postId INT NOT NULL,
                    userUid NVARCHAR(128) NOT NULL,
                    createdAt DATETIME DEFAULT GETDATE(),
                    CONSTRAINT FK_Likes_Posts FOREIGN KEY (postId) REFERENCES Posts(id) ON DELETE CASCADE
                )
                PRINT 'Created Likes table';
            END
        `);

        // 4. Create Comments Table
        await pool.request().query(`
            IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='Comments' AND xtype='U')
            BEGIN
                CREATE TABLE Comments (
                    id INT PRIMARY KEY IDENTITY(1,1),
                    postId INT NOT NULL,
                    userUid NVARCHAR(128) NOT NULL,
                    content NVARCHAR(MAX),
                    parentCommentId INT NULL,
                    createdAt DATETIME DEFAULT GETDATE(),
                    CONSTRAINT FK_Comments_Posts FOREIGN KEY (postId) REFERENCES Posts(id) ON DELETE CASCADE,
                    CONSTRAINT FK_Comments_Parent FOREIGN KEY (parentCommentId) REFERENCES Comments(id)
                )
                PRINT 'Created Comments table';
            END
            ELSE
            BEGIN
                IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('Comments') AND name = 'parentCommentId')
                BEGIN
                    ALTER TABLE Comments ADD parentCommentId INT NULL;
                    ALTER TABLE Comments ADD CONSTRAINT FK_Comments_Parent FOREIGN KEY (parentCommentId) REFERENCES Comments(id);
                    PRINT 'Added parentCommentId to Comments';
                END
            END
        `);

        // 5. Create SavedPosts Table
        await pool.request().query(`
            IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='SavedPosts' AND xtype='U')
            BEGIN
                CREATE TABLE SavedPosts (
                    id INT PRIMARY KEY IDENTITY(1,1),
                    postId INT NOT NULL,
                    userUid NVARCHAR(128) NOT NULL,
                    createdAt DATETIME DEFAULT GETDATE(),
                    CONSTRAINT FK_SavedPosts_Posts FOREIGN KEY (postId) REFERENCES Posts(id) ON DELETE CASCADE
                )
                PRINT 'Created SavedPosts table';
            END
        `);

        console.log('Social setup completed successfully');
        process.exit(0);
    } catch (err) {
        console.error('Social setup failed:', err);
        process.exit(1);
    }
}

setupSocial();
