const admin = require('./config/firebase');
const { poolPromise, sql } = require('./config/db');
require('dotenv').config();

const users = [
    {
        email: 'test1@spottr.com',
        password: 'Password123!',
        fullName: 'Alex Johnson',
        profilePictureUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?q=80&w=1000&auto=format&fit=crop',
        fitness_goal: 'Weight Loss',
        training_level: 'Beginner',
        posts: [
            {
                content: 'Just started my fitness journey with Spottr! 🚀',
                media: [{ url: 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?q=80&w=1000&auto=format&fit=crop', type: 'image' }]
            },
            {
                content: 'Feeling great after my first workout session.',
                media: []
            }
        ]
    },
    {
        email: 'test2@spottr.com',
        password: 'Password123!',
        fullName: 'Jordan Smith',
        profilePictureUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?q=80&w=1000&auto=format&fit=crop',
        fitness_goal: 'Muscle Gain',
        training_level: 'Intermediate',
        posts: [
            {
                content: 'Progress is slow but steady. Never give up! 💪',
                media: [{ url: 'https://images.unsplash.com/photo-1542291026-7eec264c27ff?q=80&w=1000&auto=format&fit=crop', type: 'image' }]
            }
        ]
    },
    {
        email: 'test3@spottr.com',
        password: 'Password123!',
        fullName: 'Casey Avery',
        profilePictureUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=1000&auto=format&fit=crop',
        fitness_goal: 'Endurance',
        training_level: 'Advanced',
        posts: [
            {
                content: 'Early morning run completed. The best way to start the day.',
                media: [{ url: 'https://images.unsplash.com/photo-1490645935967-10de6ba17061?q=80&w=1000&auto=format&fit=crop', type: 'image' }]
            },
            {
                content: 'Check out this quick workout summary video!',
                media: [{ url: 'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4', type: 'video' }]
            }
        ]
    }
];

async function seedTestData() {
    let pool;
    try {
        pool = await poolPromise;
        console.log('--- Seeding Test Data Started ---');

        for (const userData of users) {
            let user;
            try {
                // 1. Create User in Firebase Auth
                user = await admin.auth().getUserByEmail(userData.email);
                console.log(`User ${userData.email} already exists in Firebase.`);
            } catch (error) {
                if (error.code === 'auth/user-not-found') {
                    user = await admin.auth().createUser({
                        email: userData.email,
                        password: userData.password,
                        displayName: userData.fullName,
                        photoURL: userData.profilePictureUrl
                    });
                    console.log(`Created user ${userData.email} in Firebase.`);
                } else {
                    throw error;
                }
            }

            const uid = user.uid;

            // 2. Create/Update User in SQL Database
            await pool.request()
                .input('firebaseUid', sql.NVARCHAR, uid)
                .input('fullName', sql.NVARCHAR, userData.fullName)
                .input('email', sql.NVARCHAR, userData.email)
                .input('profilePictureUrl', sql.NVARCHAR, userData.profilePictureUrl)
                .input('fitness_goal', sql.NVARCHAR, userData.fitness_goal)
                .input('training_level', sql.NVARCHAR, userData.training_level)
                .query(`
                    IF EXISTS (SELECT 1 FROM Users WHERE firebaseUid = @firebaseUid)
                    BEGIN
                        UPDATE Users SET 
                            fullName = @fullName, 
                            email = @email,
                            profilePictureUrl = @profilePictureUrl,
                            fitness_goal = @fitness_goal,
                            training_level = @training_level,
                            is_setup_completed = 1
                        WHERE firebaseUid = @firebaseUid
                    END
                    ELSE
                    BEGIN
                        INSERT INTO Users (firebaseUid, fullName, email, profilePictureUrl, fitness_goal, training_level, is_setup_completed)
                        VALUES (@firebaseUid, @fullName, @email, @profilePictureUrl, @fitness_goal, @training_level, 1)
                    END
                `);
            console.log(`Ensured user ${userData.fullName} in SQL Database.`);

            // 3. Create Posts for User
            for (const postData of userData.posts) {
                const postResult = await pool.request()
                    .input('userUid', sql.NVARCHAR, uid)
                    .input('content', sql.NVARCHAR, postData.content)
                    .query(`
                        INSERT INTO Posts (userUid, content)
                        OUTPUT INSERTED.id
                        VALUES (@userUid, @content)
                    `);

                const postId = postResult.recordset[0].id;

                // 4. Add Media to PostMedia Table
                for (const m of postData.media) {
                    await pool.request()
                        .input('postId', sql.INT, postId)
                        .input('mediaUrl', sql.NVARCHAR, m.url)
                        .input('mediaType', sql.NVARCHAR, m.type)
                        .query(`
                            INSERT INTO PostMedia (postId, mediaUrl, mediaType)
                            VALUES (@postId, @mediaUrl, @mediaType)
                        `);
                }
            }
            console.log(`Created ${userData.posts.length} posts for ${userData.fullName}.`);
        }

        console.log('--- Seeding Completed Successfully ---');
    } catch (err) {
        console.error('Seeding Failed:', err);
    } finally {
        if (pool) {
            process.exit(0);
        }
    }
}

seedTestData();
