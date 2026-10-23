const { poolPromise, sql } = require('./config/db');
const cloudinary = require('cloudinary').v2;
const fs = require('fs');
const path = require('path');
require('dotenv').config();

// Cloudinary Configuration
cloudinary.config({
    cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
    api_key: process.env.CLOUDINARY_API_KEY,
    api_secret: process.env.CLOUDINARY_API_SECRET
});

const POST_DIR = 'd:\\Major 1\\major_frontend\\assets\\post';

async function run() {
    let pool;
    try {
        pool = await poolPromise;

        // 1. Get List of Dummy Users
        const usersRes = await pool.request().query("SELECT firebaseUid FROM Users WHERE email LIKE 'dummy%@spottr.com'");
        const users = usersRes.recordset;

        if (users.length === 0) {
            console.log("No dummy users found.");
            return;
        }

        // 2. Get List of Local Images
        const files = fs.readdirSync(POST_DIR).filter(file => {
            const ext = path.extname(file).toLowerCase();
            return ['.jpg', '.jpeg', '.png'].includes(ext);
        });

        if (files.length === 0) {
            console.log("No images found in post folder.");
            return;
        }

        console.log(`Found ${users.length} dummy users and ${files.length} images.`);

        // 3. Upload Images to Cloudinary
        // To save time/quota, we only upload what we need (one per user if possible)
        const uploadPromises = [];
        const numToUpload = Math.min(users.length, files.length);

        // Shuffle files to get random ones
        const shuffledFiles = [...files].sort(() => 0.5 - Math.random());
        const selectedFiles = shuffledFiles.slice(0, numToUpload);

        console.log(`Uploading ${numToUpload} selected images to Cloudinary...`);

        const uploadedUrls = [];
        for (const file of selectedFiles) {
            const filePath = path.join(POST_DIR, file);
            try {
                const result = await cloudinary.uploader.upload(filePath, {
                    folder: 'dummy_covers',
                    use_filename: true,
                    unique_filename: true
                });
                uploadedUrls.push(result.secure_url);
                console.log(`Uploaded: ${file} -> ${result.secure_url}`);
            } catch (err) {
                console.error(`Failed to upload ${file}:`, err.message);
            }
        }

        if (uploadedUrls.length === 0) {
            console.log("No images uploaded successfully.");
            return;
        }

        // 4. Assign URLs to Users
        console.log("Assigning cover photos to dummy users...");
        for (let i = 0; i < users.length; i++) {
            const user = users[i];
            const url = uploadedUrls[i % uploadedUrls.length]; // Cycle through if we have fewer images than users

            await pool.request()
                .input('uid', sql.NVARCHAR, user.firebaseUid)
                .input('coverUrl', sql.NVARCHAR, url)
                .query("UPDATE Users SET coverPhotoUrl = @coverUrl WHERE firebaseUid = @uid");

            console.log(`User ${user.firebaseUid} -> ${url}`);
        }

        console.log('--- Successfully updated dummy cover photos! ---');

    } catch (err) {
        console.error('Error:', err);
    } finally {
        if (pool) process.exit();
    }
}

run();
