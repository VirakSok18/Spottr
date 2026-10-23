const { poolPromise, sql } = require('../config/db');
require('dotenv').config();

async function selectiveClearSocial() {
    let pool;
    try {
        pool = await poolPromise;
        console.log('--- Selective Social Data Cleanup Started ---');

        // 1. Get UIDs of dummy accounts
        const dummyUsersRes = await pool.request().query("SELECT firebaseUid FROM Users WHERE email LIKE 'dummy%@spottr.com'");
        const dummyUids = dummyUsersRes.recordset.map(u => u.firebaseUid);
        
        console.log(`Found ${dummyUids.length} dummy accounts.`);
        
        if (dummyUids.length === 0) {
            console.warn('No dummy accounts found! Check email pattern dummy%@spottr.com');
            return;
        }

        // We will build a comma-separated list of dummy UIDs for the SQL queries
        // Note: For large lists we should use a temp table, but for 21 it's fine.
        const dummyList = dummyUids.map(uid => `'${uid}'`).join(',');

        // 2. Clear Social Data for non-dummy users
        
        // A. Clear Likes from non-dummy users
        const deleteLikes = await pool.request().query(`
            DELETE FROM Likes WHERE userUid NOT IN (${dummyList})
        `);
        console.log(`Cleared Likes from non-dummy users: ${deleteLikes.rowsAffected[0]} rows`);

        // B. Clear Comments from non-dummy users
        const deleteComments = await pool.request().query(`
            DELETE FROM Comments WHERE userUid NOT IN (${dummyList})
        `);
        console.log(`Cleared Comments from non-dummy users: ${deleteComments.rowsAffected[0]} rows`);

        // C. Clear Notifications related to non-dummy users or deleted posts
        const deleteNotifs = await pool.request().query(`
            DELETE FROM Notifications 
            WHERE recipientUid NOT IN (${dummyList}) 
               OR senderUid NOT IN (${dummyList})
        `);
        console.log(`Cleared Notifications related to non-dummy users: ${deleteNotifs.rowsAffected[0]} rows`);

        // D. Clear Posts from non-dummy users
        // For Posts, Comments, and Likes, I'll use userUid (verified column name)
        
        // First delete PostMedia for these posts
        const deleteMedia = await pool.request().query(`
            DELETE FROM PostMedia WHERE postId IN (SELECT id FROM Posts WHERE userUid NOT IN (${dummyList}))
        `);
        console.log(`Cleared PostMedia for non-dummy posts: ${deleteMedia.rowsAffected[0]} rows`);

        const deletePosts = await pool.request().query(`
            DELETE FROM Posts WHERE userUid NOT IN (${dummyList})
        `);
        console.log(`Cleared Posts from non-dummy users: ${deletePosts.rowsAffected[0]} rows`);

        // E. Clear SavedPosts from non-dummy users
        const deleteSaved = await pool.request().query(`
            DELETE FROM SavedPosts WHERE userUid NOT IN (${dummyList})
        `);
        console.log(`Cleared SavedPosts for non-dummy users: ${deleteSaved.rowsAffected[0]} rows`);

        console.log('--- Selective Cleanup Completed Successfully ---');
    } catch (err) {
        console.error('Cleanup Failed:', err);
    } finally {
        if (pool) {
            process.exit(0);
        }
    }
}

selectiveClearSocial();
