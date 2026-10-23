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

const testUsers = [
    {
        uid: 'wZpm8xWqdhON6UzwIZY26c9Mbav1', // Jordan Smith
        name: 'Jordan Smith',
        // Top-right quadrant
        crop: { width: 0.5, height: 0.5, x: 0.5, y: 0, gravity: 'north_east' }
    },
    {
        uid: 'rrWzUz8v8jNeFkBQjAv3GHEzKu63', // Casey Avery
        name: 'Casey Avery',
        // Bottom-left quadrant
        crop: { width: 0.5, height: 0.5, x: 0, y: 0.5, gravity: 'south_west' }
    }
];

async function updateProfiles() {
    let pool;
    try {
        pool = await poolPromise;
        console.log('--- Profile Media Update Started ---');

        // 1. Upload the base image to Cloudinary
        console.log('Uploading base image to Cloudinary...');
        const uploadResult = await cloudinary.uploader.upload(IMAGE_PATH, {
            folder: 'test_profiles',
            public_id: 'test_user_grid',
            overwrite: true
        });

        const baseUrl = uploadResult.secure_url;
        console.log('Base Image URL:', baseUrl);

        // 2. Update each user with a specific crop
        for (const user of testUsers) {
            // Construct Cloudinary transformation URL for the specific quadrant
            // Using 'crop' and 'gravity' to select the quadrant
            // Cloudinary transformation format: c_crop,g_north_east,h_0.5,w_0.5,x_0.5,y_0.0
            const transformation = `c_crop,g_${user.crop.gravity},h_0.5,w_0.5`;
            const profileUrl = baseUrl.replace('/upload/', `/upload/${transformation}/`);

            console.log(`Updating ${user.name} with URL: ${profileUrl}`);

            await pool.request()
                .input('uid', sql.NVARCHAR, user.uid)
                .input('url', sql.NVARCHAR, profileUrl)
                .query('UPDATE Users SET profilePictureUrl = @url WHERE firebaseUid = @uid');

            console.log(`Successfully updated ${user.name}.`);
        }

        console.log('--- Profile Media Update Completed Successfully ---');
    } catch (err) {
        console.error('Update Failed:', err);
    } finally {
        if (pool) {
            process.exit(0);
        }
    }
}

updateProfiles();
