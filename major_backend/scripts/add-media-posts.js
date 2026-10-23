const cloudinary = require('cloudinary').v2;
const { poolPromise, sql } = require('../config/db');
require('dotenv').config();

// Cloudinary Configuration
cloudinary.config({
    cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
    api_key: process.env.CLOUDINARY_API_KEY,
    api_secret: process.env.CLOUDINARY_API_SECRET
});

const IMAGE_PATH = 'C:/Users/holme/.gemini/antigravity/brain/9a51f07b-b39e-4d62-97d3-cc5b94924d00/media__1771993863466.jpg';

const postsToCreate = [
    {
        userEmail: 'test1@spottr.com',
        uid: 'BlJph660RecT8I35MkQGsQMusmD2', // Alex
        content: 'Heavy squats today! Form is feeling better every session. 🏋️‍♂️',
        gravity: 'north_west' // Top-left
    },
    {
        userEmail: 'test2@spottr.com',
        uid: 'wZpm8xWqdhON6UzwIZY26c9Mbav1', // Jordan
        content: 'Working on that back definition with wide-grip pull-ups. 💪',
        gravity: 'north_east' // Top-right
    },
    {
        userEmail: 'test3@spottr.com',
        uid: 'rrWzUz8v8jNeFkBQjAv3GHEzKu63', // Casey
        content: 'Kettlebell swings are a killer for endurance. Let’s go! 🔥',
        gravity: 'south_west' // Bottom-left
    },
    {
        userEmail: 'test3@spottr.com',
        uid: 'rrWzUz8v8jNeFkBQjAv3GHEzKu63', // Casey
        content: 'Don’t forget to stretch after your run. Recovery is key! 🧘‍♂️',
        gravity: 'south_east' // Bottom-right
    }
];

async function addMediaPosts() {
    let pool;
    try {
        pool = await poolPromise;
        console.log('--- Adding Media Posts Started ---');

        // 1. Upload the base image for posts
        console.log('Uploading workout grid image to Cloudinary...');
        const uploadResult = await cloudinary.uploader.upload(IMAGE_PATH, {
            folder: 'test_posts',
            public_id: 'workout_grid',
            overwrite: true
        });

        const baseUrl = uploadResult.secure_url;
        console.log('Base Image URL:', baseUrl);

        // 2. Create each post
        for (const postData of postsToCreate) {
            console.log(`Creating post for ${postData.userEmail}...`);

            // Create Post entry
            const postResult = await pool.request()
                .input('userUid', sql.NVARCHAR, postData.uid)
                .input('content', sql.NVARCHAR, postData.content)
                .query(`
                    INSERT INTO Posts (userUid, content)
                    OUTPUT INSERTED.id
                    VALUES (@userUid, @content)
                `);

            const postId = postResult.recordset[0].id;

            // Construct crop URL
            const transformation = `c_crop,g_${postData.gravity},h_0.5,w_0.5`;
            const postMediaUrl = baseUrl.replace('/upload/', `/upload/${transformation}/`);

            // Create PostMedia entry
            await pool.request()
                .input('postId', sql.INT, postId)
                .input('mediaUrl', sql.NVARCHAR, postMediaUrl)
                .input('mediaType', sql.NVARCHAR, 'image')
                .query(`
                    INSERT INTO PostMedia (postId, mediaUrl, mediaType)
                    VALUES (@postId, @mediaUrl, @mediaType)
                `);

            console.log(`Successfully created post ID ${postId} with media.`);
        }

        console.log('--- Media Posts Added Successfully ---');
    } catch (err) {
        console.error('Operation Failed:', err);
    } finally {
        if (pool) {
            process.exit(0);
        }
    }
}

addMediaPosts();
