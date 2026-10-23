const { poolPromise, sql } = require('../config/db');
require('dotenv').config();

async function testRecursiveDelete() {
    let pool;
    try {
        pool = await poolPromise;

        // 1. Create a test user if needed (assuming we can use an existing one or just need a valid UID)
        // For simplicity, let's fetch an existing user or insert a dummy one locally known
        const userResult = await pool.request().query("SELECT TOP 1 firebaseUid FROM Users");
        if (userResult.recordset.length === 0) {
            console.log('No users found to test with.');
            return;
        }
        const uid = userResult.recordset[0].firebaseUid;
        console.log(`Using user UID: ${uid}`);

        // 2. Create a Post
        const postResult = await pool.request()
            .input('userUid', sql.NVARCHAR, uid)
            .input('content', sql.NVARCHAR, 'Test Post for Recursive Delete')
            .input('mediaUrl', sql.NVARCHAR, null)
            .input('mediaType', sql.NVARCHAR, null)
            .query(`
                INSERT INTO Posts (userUid, content, mediaUrl, mediaType)
                OUTPUT INSERTED.id
                VALUES (@userUid, @content, @mediaUrl, @mediaType)
            `);
        const postId = postResult.recordset[0].id;
        console.log(`Created Post ID: ${postId}`);

        // 3. Create Root Comment (A)
        const commentAResult = await pool.request()
            .input('postId', sql.INT, postId)
            .input('userUid', sql.NVARCHAR, uid)
            .input('content', sql.NVARCHAR, 'Root Comment A')
            .query(`
                INSERT INTO Comments (postId, userUid, content, parentCommentId)
                OUTPUT INSERTED.id
                VALUES (@postId, @userUid, @content, NULL)
            `);
        const commentIdA = commentAResult.recordset[0].id;
        console.log(`Created Root Comment A: ${commentIdA}`);

        // 4. Create Reply B (child of A)
        const commentBResult = await pool.request()
            .input('postId', sql.INT, postId)
            .input('userUid', sql.NVARCHAR, uid)
            .input('content', sql.NVARCHAR, 'Reply B (Child of A)')
            .input('parentId', sql.INT, commentIdA)
            .query(`
                INSERT INTO Comments (postId, userUid, content, parentCommentId)
                OUTPUT INSERTED.id
                VALUES (@postId, @userUid, @content, @parentId)
            `);
        const commentIdB = commentBResult.recordset[0].id;
        console.log(`Created Reply B: ${commentIdB}`);

        // 5. Create Reply C (child of B)
        const commentCResult = await pool.request()
            .input('postId', sql.INT, postId)
            .input('userUid', sql.NVARCHAR, uid)
            .input('content', sql.NVARCHAR, 'Reply C (Child of B)')
            .input('parentId', sql.INT, commentIdB)
            .query(`
                INSERT INTO Comments (postId, userUid, content, parentCommentId)
                OUTPUT INSERTED.id
                VALUES (@postId, @userUid, @content, @parentId)
            `);
        const commentIdC = commentCResult.recordset[0].id;
        console.log(`Created Reply C: ${commentIdC}`);

        // Verify initial count
        const initialCount = await pool.request()
            .input('postId', sql.INT, postId)
            .query('SELECT COUNT(*) as count FROM Comments WHERE postId = @postId');
        console.log(`Initial Comment Count: ${initialCount.recordset[0].count} (Should be 3)`);

        // 6. Delete Root Comment A via API Logic (Simulation)
        // We will simulate the DELETE logic exactly as implemented in the route
        console.log('Deleting Root Comment A...');
        const deleteResult = await pool.request()
            .input('id', sql.INT, commentIdA)
            .input('uid', sql.NVARCHAR, uid)
            .query(`
                WITH CommentTree AS (
                    SELECT id 
                    FROM Comments 
                    WHERE id = @id AND userUid = @uid
                    
                    UNION ALL
                    
                    SELECT c.id
                    FROM Comments c
                    INNER JOIN CommentTree ct ON c.parentCommentId = ct.id
                )
                DELETE FROM Comments 
                WHERE id IN (SELECT id FROM CommentTree);
                
                SELECT @@ROWCOUNT as rowsAffected;
            `);

        console.log(`Deleted rows: ${deleteResult.recordset[0].rowsAffected} (Should be 3)`);

        // 7. Verify all are gone
        const finalCheck = await pool.request()
            .input('postId', sql.INT, postId)
            .query('SELECT * FROM Comments WHERE postId = @postId');

        console.log(`Remaining comments for post: ${finalCheck.recordset.length} (Should be 0)`);

        if (finalCheck.recordset.length === 0) {
            console.log('SUCCESS: Recursive delete worked!');
        } else {
            console.log('FAILURE: Some comments remain.');
        }

        // Cleanup Post
        await pool.request().input('id', sql.INT, postId).query('DELETE FROM Posts WHERE id = @id');
        console.log('Cleaned up test post.');

    } catch (err) {
        console.error('Test Error:', err);
    } finally {
        if (pool) await pool.close();
    }
}

testRecursiveDelete();
