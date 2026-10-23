const { poolPromise, sql } = require('../config/db');
require('dotenv').config();

async function clearSocialData() {
    let pool;
    try {
        pool = await poolPromise;
        console.log('--- Database Cleanup Started ---');

        // The order matters due to foreign key constraints if they aren't ON DELETE CASCADE
        // Likes, Comments, and SavedPosts have FK to Posts with ON DELETE CASCADE in setup-social.js
        // Notifications might have referenceId but no hard FK usually if it stores post IDs as strings

        // 1. Clear Notifications
        const notifResult = await pool.request().query('DELETE FROM Notifications');
        console.log(`Cleared Notifications: ${notifResult.rowsAffected[0]} rows`);

        // 2. Clear PostMedia
        const mediaResult = await pool.request().query('DELETE FROM PostMedia');
        console.log(`Cleared PostMedia: ${mediaResult.rowsAffected[0]} rows`);

        // 3. Clear Posts (This will cascade if configured, but we clear explicitly just in case)
        const postResult = await pool.request().query('DELETE FROM Posts');
        console.log(`Cleared Posts: ${postResult.rowsAffected[0]} rows`);

        // Double check tables that might not have CASCADE or have different constraints
        const likesResult = await pool.request().query('DELETE FROM Likes');
        if (likesResult.rowsAffected[0] > 0) console.log(`Cleared remaining Likes: ${likesResult.rowsAffected[0]} rows`);

        const commentsResult = await pool.request().query('DELETE FROM Comments');
        if (commentsResult.rowsAffected[0] > 0) console.log(`Cleared remaining Comments: ${commentsResult.rowsAffected[0]} rows`);

        const savedResult = await pool.request().query('DELETE FROM SavedPosts');
        if (savedResult.rowsAffected[0] > 0) console.log(`Cleared remaining SavedPosts: ${savedResult.rowsAffected[0]} rows`);

        console.log('--- Cleanup Completed Successfully ---');
    } catch (err) {
        console.error('Cleanup Failed:', err);
    } finally {
        if (pool) {
            // We don't necessarily want to close it if we were in a larger process, 
            // but for a standalone script we should.
            process.exit(0);
        }
    }
}

clearSocialData();
