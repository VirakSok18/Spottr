const express = require('express');
const router = express.Router();
const { poolPromise, sql } = require('../config/db');
const authMiddleware = require('../middleware/auth');
const multer = require('multer');
const cloudinary = require('cloudinary').v2;
const streamifier = require('streamifier');
const admin = require('../config/firebase');

// Cloudinary Configuration
cloudinary.config({
    cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
    api_key: process.env.CLOUDINARY_API_KEY,
    api_secret: process.env.CLOUDINARY_API_SECRET
});

const storage = multer.memoryStorage();
const upload = multer({ storage: storage });

// Create a new post
router.post('/', authMiddleware, async (req, res) => {
    const { content, media } = req.body;
    const { uid } = req.user;

    try {
        const pool = await poolPromise;
        const transaction = new sql.Transaction(pool);
        await transaction.begin();

        try {
            const postResult = await transaction.request()
                .input('userUid', sql.NVARCHAR, uid)
                .input('content', sql.NVARCHAR, content)
                .query(`
                    INSERT INTO Posts (userUid, content)
                    OUTPUT INSERTED.id, INSERTED.userUid, INSERTED.content, INSERTED.createdAt
                    VALUES (@userUid, @content)
                `);

            const postId = postResult.recordset[0].id;

            if (media && Array.isArray(media) && media.length > 0) {
                for (const item of media) {
                    await transaction.request()
                        .input('postId', sql.INT, postId)
                        .input('mediaUrl', sql.NVARCHAR, item.url)
                        .input('mediaType', sql.NVARCHAR, item.type)
                        .query(`
                            INSERT INTO PostMedia (postId, mediaUrl, mediaType)
                            VALUES (@postId, @mediaUrl, @mediaType)
                        `);
                }
            }

            await transaction.commit();

            const finalResult = await pool.request()
                .input('postId', sql.INT, postId)
                .query(`
                    SELECT p.*, 
                    (SELECT mediaUrl as url, mediaType as type FROM PostMedia WHERE postId = p.id FOR JSON PATH) as media
                    FROM Posts p WHERE id = @postId
                `);

            const post = finalResult.recordset[0];
            if (post.media) post.media = JSON.parse(post.media);
            res.status(201).json(post);
        } catch (err) {
            await transaction.rollback();
            throw err;
        }
    } catch (err) {
        console.error('Error creating post:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// Update a post (author only)
router.put('/:id', authMiddleware, async (req, res) => {
    const { id } = req.params;
    const { content } = req.body;
    const { uid } = req.user;

    try {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('id', sql.INT, id)
            .input('userUid', sql.NVARCHAR, uid)
            .input('content', sql.NVARCHAR, content)
            .query(`
                UPDATE Posts 
                SET content = @content 
                OUTPUT INSERTED.*
                WHERE id = @id AND userUid = @userUid
            `);

        if (result.recordset.length === 0) {
            return res.status(403).json({ error: 'Unauthorized or post not found' });
        }
        res.status(200).json(result.recordset[0]);
    } catch (err) {
        console.error('Error updating post:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// Delete a post (author only)
router.delete('/:id', authMiddleware, async (req, res) => {
    const { id } = req.params;
    const { uid } = req.user;

    try {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('id', sql.INT, id)
            .input('userUid', sql.NVARCHAR, uid)
            .query('DELETE FROM Posts WHERE id = @id AND userUid = @userUid');

        if (result.rowsAffected[0] === 0) {
            return res.status(403).json({ error: 'Unauthorized or post not found' });
        }
        res.status(200).json({ message: 'Post deleted successfully' });
    } catch (err) {
        console.error('Error deleting post:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// Get all posts (Feed)
router.get('/', authMiddleware, async (req, res) => {
    const { uid } = req.user;
    try {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('currentUserUid', sql.NVARCHAR, uid)
            .query(`
                SELECT 
                    p.*, 
                    u.fullName as userName, 
                    u.profilePictureUrl as userAvatar,
                    u.coverPhotoUrl as userCover,
                    (SELECT COUNT(*) FROM Likes WHERE postId = p.id) as likesCount,
                    (SELECT COUNT(*) FROM Comments WHERE postId = p.id) as commentsCount,
                    CASE WHEN EXISTS (SELECT 1 FROM Likes WHERE postId = p.id AND userUid = @currentUserUid) THEN 1 ELSE 0 END as isLiked,
                    CASE WHEN EXISTS (SELECT 1 FROM SavedPosts WHERE postId = p.id AND userUid = @currentUserUid) THEN 1 ELSE 0 END as isSaved,
                    (SELECT mediaUrl as url, mediaType as type FROM PostMedia WHERE postId = p.id FOR JSON PATH) as media
                FROM Posts p
                JOIN Users u ON p.userUid = u.firebaseUid
                ORDER BY p.createdAt DESC
            `);

        const posts = result.recordset.map(post => ({
            ...post,
            media: post.media ? JSON.parse(post.media) : []
        }));

        res.status(200).json(posts);
    } catch (err) {
        console.error('Error fetching feed:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// ... (Get Saved Posts, single post, etc. omitted for brevity if you're rewriting the whole file)
// Actually I'll rewrite the whole file to be safe.

// Get Saved Posts
router.get('/saved', authMiddleware, async (req, res) => {
    const { uid } = req.user;
    try {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('currentUserUid', sql.NVARCHAR, uid)
            .query(`
                SELECT 
                    p.*, 
                    u.fullName as userName, 
                    u.profilePictureUrl as userAvatar,
                    u.coverPhotoUrl as userCover,
                    (SELECT COUNT(*) FROM Likes WHERE postId = p.id) as likesCount,
                    (SELECT COUNT(*) FROM Comments WHERE postId = p.id) as commentsCount,
                    CASE WHEN EXISTS (SELECT 1 FROM Likes WHERE postId = p.id AND userUid = @currentUserUid) THEN 1 ELSE 0 END as isLiked,
                    1 as isSaved,
                    (SELECT mediaUrl as url, mediaType as type FROM PostMedia WHERE postId = p.id FOR JSON PATH) as media
                FROM SavedPosts sp
                JOIN Posts p ON sp.postId = p.id
                JOIN Users u ON p.userUid = u.firebaseUid
                WHERE sp.userUid = @currentUserUid
                ORDER BY sp.createdAt DESC
            `);

        const posts = result.recordset.map(post => ({
            ...post,
            media: post.media ? JSON.parse(post.media) : []
        }));

        res.status(200).json(posts);
    } catch (err) {
        console.error('Error fetching saved posts:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// Get a single post by ID
router.get('/:id', authMiddleware, async (req, res) => {
    const { id } = req.params;
    const { uid } = req.user;

    if (isNaN(id)) {
        return res.status(400).json({ error: 'Invalid Post ID' });
    }

    try {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('id', sql.INT, id)
            .input('currentUserUid', sql.NVARCHAR, uid)
            .query(`
                SELECT 
                    p.*, 
                    u.fullName as userName, 
                    u.profilePictureUrl as userAvatar,
                    u.coverPhotoUrl as userCover,
                    (SELECT COUNT(*) FROM Likes WHERE postId = p.id) as likesCount,
                    (SELECT COUNT(*) FROM Comments WHERE postId = p.id) as commentsCount,
                    CASE WHEN EXISTS (SELECT 1 FROM Likes WHERE postId = p.id AND userUid = @currentUserUid) THEN 1 ELSE 0 END as isLiked,
                    CASE WHEN EXISTS (SELECT 1 FROM SavedPosts WHERE postId = p.id AND userUid = @currentUserUid) THEN 1 ELSE 0 END as isSaved,
                    (SELECT mediaUrl as url, mediaType as type FROM PostMedia WHERE postId = p.id FOR JSON PATH) as media
                FROM Posts p
                JOIN Users u ON p.userUid = u.firebaseUid
                WHERE p.id = @id
            `);

        if (result.recordset.length === 0) {
            return res.status(404).json({ error: 'Post not found' });
        }

        const post = result.recordset[0];
        post.media = post.media ? JSON.parse(post.media) : [];

        res.status(200).json(post);
    } catch (err) {
        console.error('Error fetching single post:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// Get posts by user ID
router.get('/user/:uid', authMiddleware, async (req, res) => {
    const { uid } = req.params;
    const { uid: currentUserUid } = req.user;
    try {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('userUid', sql.NVARCHAR, uid)
            .input('currentUserUid', sql.NVARCHAR, currentUserUid)
            .query(`
                SELECT 
                    p.*, 
                    u.fullName as userName, 
                    u.profilePictureUrl as userAvatar,
                    u.coverPhotoUrl as userCover,
                    (SELECT COUNT(*) FROM Likes WHERE postId = p.id) as likesCount,
                    (SELECT COUNT(*) FROM Comments WHERE postId = p.id) as commentsCount,
                    CASE WHEN EXISTS (SELECT 1 FROM Likes WHERE postId = p.id AND userUid = @currentUserUid) THEN 1 ELSE 0 END as isLiked,
                    CASE WHEN EXISTS (SELECT 1 FROM SavedPosts WHERE postId = p.id AND userUid = @currentUserUid) THEN 1 ELSE 0 END as isSaved,
                    (SELECT mediaUrl as url, mediaType as type FROM PostMedia WHERE postId = p.id FOR JSON PATH) as media
                FROM Posts p
                JOIN Users u ON p.userUid = u.firebaseUid
                WHERE p.userUid = @userUid
                ORDER BY p.createdAt DESC
            `);

        const posts = result.recordset.map(post => ({
            ...post,
            media: post.media ? JSON.parse(post.media) : []
        }));

        res.status(200).json(posts);
    } catch (err) {
        console.error('Error fetching user posts:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// Toggle Like
router.post('/:id/like', authMiddleware, async (req, res) => {
    const { id } = req.params;
    const { uid } = req.user;

    try {
        const pool = await poolPromise;
        const checkLike = await pool.request()
            .input('postId', sql.INT, id)
            .input('userUid', sql.NVARCHAR, uid)
            .query('SELECT id FROM Likes WHERE postId = @postId AND userUid = @userUid');

        if (checkLike.recordset.length > 0) {
            await pool.request()
                .input('postId', sql.INT, id)
                .input('userUid', sql.NVARCHAR, uid)
                .query('DELETE FROM Likes WHERE postId = @postId AND userUid = @userUid');

            // --- Real-time Logic (Unlike) ---
            const io = req.app.get('io');
            if (io) {
                io.emit('post_interaction', {
                    type: 'like',
                    postId: id,
                    userUid: uid,
                    liked: false
                });
            }

            res.status(200).json({ liked: false });
        } else {
            const transaction = new sql.Transaction(pool);
            await transaction.begin();

            try {
                // 1. Insert Like
                await transaction.request()
                    .input('postId', sql.INT, id)
                    .input('userUid', sql.NVARCHAR, uid)
                    .query('INSERT INTO Likes (postId, userUid) VALUES (@postId, @userUid)');

                // 2. Get Post Author
                const postResult = await transaction.request()
                    .input('postId', sql.INT, id)
                    .query('SELECT userUid, content FROM Posts WHERE id = @postId');

                let postAuthorUid = null;
                let likerName = 'Someone';

                if (postResult.recordset.length > 0) {
                    postAuthorUid = postResult.recordset[0].userUid;

                    // 3. Create Notification if not self-like
                    if (postAuthorUid !== uid) {
                        const userResult = await transaction.request()
                            .input('uid', sql.NVARCHAR, uid)
                            .query('SELECT fullName FROM Users WHERE firebaseUid = @uid');
                        likerName = userResult.recordset[0]?.fullName || 'Someone';

                        await transaction.request()
                            .input('recipientUid', sql.NVARCHAR, postAuthorUid)
                            .input('senderUid', sql.NVARCHAR, uid)
                            .input('type', sql.NVARCHAR, 'like')
                            .input('title', sql.NVARCHAR, 'New Like')
                            .input('message', sql.NVARCHAR, `${likerName} liked your post`)
                            .input('referenceId', sql.NVARCHAR, id.toString())
                            .query(`
                                INSERT INTO Notifications (recipientUid, senderUid, type, title, message, referenceId)
                                VALUES (@recipientUid, @senderUid, @type, @title, @message, @referenceId)
                            `);
                    }
                }

                await transaction.commit();

                // --- Real-time & FCM Logic ---
                const io = req.app.get('io');
                if (io) {
                    io.emit('post_interaction', {
                        type: 'like',
                        postId: id,
                        userUid: uid,
                        liked: true
                    });
                }

                if (postAuthorUid && postAuthorUid !== uid) {
                    const userRes = await pool.request()
                        .input('uid', sql.NVARCHAR, postAuthorUid)
                        .query('SELECT fcmToken FROM Users WHERE firebaseUid = @uid');

                    const fcmToken = userRes.recordset[0]?.fcmToken;
                    if (fcmToken) {
                        const payload = {
                            notification: {
                                title: 'New Like',
                                body: `${likerName} liked your post`,
                            },
                            android: {
                                notification: {
                                    icon: 'ic_notification',
                                    color: '#B794F6',
                                    clickAction: 'FLUTTER_NOTIFICATION_CLICK',
                                }
                            },
                            data: {
                                type: 'like',
                                postId: id.toString(),
                                click_action: 'FLUTTER_NOTIFICATION_CLICK'
                            },
                            token: fcmToken
                        };
                        admin.messaging().send(payload).catch(e => console.error('FCM Error:', e));
                    }
                }

                res.status(200).json({ liked: true });
            } catch (txErr) {
                await transaction.rollback();
                throw txErr;
            }
        }
    } catch (err) {
        console.error('Error toggling like:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// Toggle Save
router.post('/:id/save', authMiddleware, async (req, res) => {
    const { id } = req.params;
    const { uid } = req.user;

    try {
        const pool = await poolPromise;
        const transaction = new sql.Transaction(pool);
        await transaction.begin();

        try {
            const checkSave = await transaction.request()
                .input('postId', sql.INT, id)
                .input('userUid', sql.NVARCHAR, uid)
                .query('SELECT id FROM SavedPosts WHERE postId = @postId AND userUid = @userUid');

            if (checkSave.recordset.length > 0) {
                // UN-SAVE CASE
                // 1. Remove from SavedPosts
                await transaction.request()
                    .input('postId', sql.INT, id)
                    .input('userUid', sql.NVARCHAR, uid)
                    .query('DELETE FROM SavedPosts WHERE postId = @postId AND userUid = @userUid');
                
                // 2. ALSO Remove from all collections for this user
                await transaction.request()
                    .input('postId', sql.INT, id)
                    .input('userUid', sql.NVARCHAR, uid)
                    .query(`
                        DELETE pci FROM PostCollectionItems pci
                        JOIN PostCollections pc ON pci.collectionId = pc.id
                        WHERE pci.postId = @postId AND pc.userUid = @userUid
                    `);

                await transaction.commit();
                res.status(200).json({ saved: false });
            } else {
                // SAVE CASE
                await transaction.request()
                    .input('postId', sql.INT, id)
                    .input('userUid', sql.NVARCHAR, uid)
                    .query('INSERT INTO SavedPosts (postId, userUid) VALUES (@postId, @userUid)');
                
                await transaction.commit();
                res.status(200).json({ saved: true });
            }
        } catch (txnErr) {
            await transaction.rollback();
            throw txnErr;
        }
    } catch (err) {
        console.error('Error toggling save:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// Upload media for post
router.post('/upload', authMiddleware, upload.single('media'), async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ error: 'No file uploaded' });
        }

        const isVideo = req.file.mimetype.startsWith('video/');
        const uploadStream = cloudinary.uploader.upload_stream(
            {
                folder: 'post_media',
                resource_type: isVideo ? 'video' : 'image',
            },
            (error, result) => {
                if (error) {
                    console.error('Cloudinary Upload Error:', error);
                    return res.status(500).json({ error: 'Upload failed' });
                }
                res.status(200).json({
                    url: result.secure_url,
                    type: isVideo ? 'video' : 'image'
                });
            }
        );

        streamifier.createReadStream(req.file.buffer).pipe(uploadStream);
    } catch (err) {
        console.error('Upload Process Error:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// Add comment or reply to post
router.post('/:id/comment', authMiddleware, async (req, res) => {
    const { id } = req.params;
    const { content, parentCommentId } = req.body;
    const { uid } = req.user;

    if (!content) return res.status(400).json({ error: 'Comment content is required' });

    try {
        const pool = await poolPromise;
        const transaction = new sql.Transaction(pool);
        await transaction.begin();

        try {
            // 1. Insert Comment
            const result = await transaction.request()
                .input('postId', sql.INT, id)
                .input('userUid', sql.NVARCHAR, uid)
                .input('content', sql.NVARCHAR, content)
                .input('parentCommentId', sql.INT, parentCommentId || null)
                .query(`
                    INSERT INTO Comments (postId, userUid, content, parentCommentId)
                    OUTPUT INSERTED.*
                    VALUES (@postId, @userUid, @content, @parentCommentId)
                `);

            // 2. Notification Logic
            if (parentCommentId) {
                // Reply to a comment
                const parentResult = await transaction.request()
                    .input('commentId', sql.INT, parentCommentId)
                    .query('SELECT userUid FROM Comments WHERE id = @commentId');

                if (parentResult.recordset.length > 0) {
                    const parentAuthorUid = parentResult.recordset[0].userUid;
                    if (parentAuthorUid !== uid) {
                        const userResult = await transaction.request()
                            .input('uid', sql.NVARCHAR, uid)
                            .query('SELECT fullName FROM Users WHERE firebaseUid = @uid');
                        const commenterName = userResult.recordset[0]?.fullName || 'Someone';

                        await transaction.request()
                            .input('recipientUid', sql.NVARCHAR, parentAuthorUid)
                            .input('senderUid', sql.NVARCHAR, uid)
                            .input('type', sql.NVARCHAR, 'comment')
                            .input('title', sql.NVARCHAR, 'New Reply')
                            .input('message', sql.NVARCHAR, `${commenterName} replied: ${content}`)
                            .input('referenceId', sql.NVARCHAR, id.toString())
                            .query(`
                                INSERT INTO Notifications (recipientUid, senderUid, type, title, message, referenceId)
                                VALUES (@recipientUid, @senderUid, @type, @title, @message, @referenceId)
                            `);
                    }
                }
            } else {
                // Top-level comment -> Notify post author
                const postResult = await transaction.request()
                    .input('postId', sql.INT, id)
                    .query('SELECT userUid FROM Posts WHERE id = @postId');

                if (postResult.recordset.length > 0) {
                    const postAuthorUid = postResult.recordset[0].userUid;
                    if (postAuthorUid !== uid) {
                        const userResult = await transaction.request()
                            .input('uid', sql.NVARCHAR, uid)
                            .query('SELECT fullName FROM Users WHERE firebaseUid = @uid');
                        const commenterName = userResult.recordset[0]?.fullName || 'Someone';

                        await transaction.request()
                            .input('recipientUid', sql.NVARCHAR, postAuthorUid)
                            .input('senderUid', sql.NVARCHAR, uid)
                            .input('type', sql.NVARCHAR, 'comment')
                            .input('title', sql.NVARCHAR, 'New Comment')
                            .input('message', sql.NVARCHAR, `${commenterName} commented: ${content}`)
                            .input('referenceId', sql.NVARCHAR, id.toString())
                            .query(`
                                INSERT INTO Notifications (recipientUid, senderUid, type, title, message, referenceId)
                                VALUES (@recipientUid, @senderUid, @type, @title, @message, @referenceId)
                            `);
                    }
                }
            }

            await transaction.commit();

            // --- Real-time & FCM Logic ---
            const io = req.app.get('io');
            if (io) {
                io.emit('post_interaction', {
                    type: 'comment',
                    postId: id,
                    userUid: uid
                });
            }

            // Determine recipient for FCM
            let recipientUid = null;
            let notificationTitle = 'New Comment';
            if (parentCommentId) {
                const parentResult = await pool.request()
                    .input('commentId', sql.INT, parentCommentId)
                    .query('SELECT userUid FROM Comments WHERE id = @commentId');
                if (parentResult.recordset.length > 0) {
                    recipientUid = parentResult.recordset[0].userUid;
                    notificationTitle = 'New Reply';
                }
            } else {
                const postResult = await pool.request()
                    .input('postId', sql.INT, id)
                    .query('SELECT userUid FROM Posts WHERE id = @postId');
                if (postResult.recordset.length > 0) {
                    recipientUid = postResult.recordset[0].userUid;
                }
            }

            if (recipientUid && recipientUid !== uid) {
                const recipientRes = await pool.request()
                    .input('uid', sql.NVARCHAR, recipientUid)
                    .query('SELECT fcmToken FROM Users WHERE firebaseUid = @uid');

                const fcmToken = recipientRes.recordset[0]?.fcmToken;

                if (fcmToken) {
                    const userResult = await pool.request()
                        .input('uid', sql.NVARCHAR, uid)
                        .query('SELECT fullName FROM Users WHERE firebaseUid = @uid');
                    const commenterName = userResult.recordset[0]?.fullName || 'Someone';

                    const payload = {
                        notification: {
                            title: notificationTitle,
                            body: `${commenterName}: ${content}`,
                        },
                        android: {
                            notification: {
                                icon: 'ic_notification',
                                color: '#B794F6',
                                clickAction: 'FLUTTER_NOTIFICATION_CLICK',
                            }
                        },
                        data: {
                            type: 'comment',
                            postId: id.toString(),
                            click_action: 'FLUTTER_NOTIFICATION_CLICK'
                        },
                        token: fcmToken
                    };
                    admin.messaging().send(payload).catch(e => console.error('FCM Error:', e));
                }
            }
            // -----------------------------

            // Fetch user info for response (outside transaction)
            const userResult = await pool.request()
                .input('uid', sql.NVARCHAR, uid)
                .query('SELECT fullName as userName, profilePictureUrl as userAvatar, coverPhotoUrl as userCover FROM Users WHERE firebaseUid = @uid');

            const comment = result.recordset[0];
            const user = userResult.recordset[0] || { userName: 'User', userAvatar: null };

            res.status(201).json({
                ...comment,
                userName: user.userName,
                userAvatar: user.userAvatar
            });
        } catch (txErr) {
            await transaction.rollback();
            throw txErr;
        }
    } catch (err) {
        console.error('Error adding comment:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// Get comments for a post
router.get('/:id/comments', authMiddleware, async (req, res) => {
    const { id } = req.params;

    try {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('postId', sql.INT, id)
            .query(`
                SELECT 
                    c.*, 
                    u.fullName as userName, 
                    u.profilePictureUrl as userAvatar,
                    u.coverPhotoUrl as userCover
                FROM Comments c
                LEFT JOIN Users u ON c.userUid = u.firebaseUid
                WHERE c.postId = @postId
                ORDER BY c.parentCommentId ASC, c.createdAt ASC
            `);

        res.status(200).json(result.recordset);
    } catch (err) {
        console.error('Error fetching comments:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// Update a comment
router.put('/comments/:commentId', authMiddleware, async (req, res) => {
    const { commentId } = req.params;
    const { content } = req.body;
    const { uid } = req.user;

    if (!content) return res.status(400).json({ error: 'Content is required' });

    try {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('id', sql.INT, commentId)
            .input('uid', sql.NVARCHAR, uid)
            .input('content', sql.NVARCHAR, content)
            .query(`
                UPDATE Comments 
                SET content = @content 
                WHERE id = @id AND userUid = @uid;
                
                SELECT @@ROWCOUNT as rowsAffected;
            `);

        if (result.recordset[0].rowsAffected === 0) {
            return res.status(404).json({ error: 'Comment not found or unauthorized' });
        }

        res.status(200).json({ message: 'Comment updated successfully' });
    } catch (err) {
        console.error('Error updating comment:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// Delete a comment
router.delete('/comments/:commentId', authMiddleware, async (req, res) => {
    const { commentId } = req.params;
    const { uid } = req.user;

    try {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('id', sql.INT, commentId)
            .input('uid', sql.NVARCHAR, uid)
            .query(`
                WITH CommentTree AS (
                    SELECT id 
                    FROM Comments 
                    WHERE id = @id AND userUid = @uid -- Ensure user owns the root comment being deleted
                    
                    UNION ALL
                    
                    SELECT c.id
                    FROM Comments c
                    INNER JOIN CommentTree ct ON c.parentCommentId = ct.id
                )
                DELETE FROM Comments 
                WHERE id IN (SELECT id FROM CommentTree);
                
                SELECT @@ROWCOUNT as rowsAffected;
            `);

        if (result.recordset[0].rowsAffected === 0) {
            return res.status(404).json({ error: 'Comment not found or unauthorized' });
        }

        res.status(200).json({ message: 'Comment and its replies deleted successfully' });
    } catch (err) {
        console.error('Error deleting comment:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// --- POST COLLECTIONS SYSTEM ---

// Ensure tables exist helper (Run once or at startup)
async function ensureCollectionTables() {
    try {
        const pool = await poolPromise;
        await pool.request().query(`
            IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'PostCollections')
            CREATE TABLE PostCollections (
                id INT IDENTITY(1,1) PRIMARY KEY,
                userUid NVARCHAR(255) NOT NULL,
                name NVARCHAR(255) NOT NULL,
                createdAt DATETIME DEFAULT GETDATE()
            );

            IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'PostCollectionItems')
            CREATE TABLE PostCollectionItems (
                id INT IDENTITY(1,1) PRIMARY KEY,
                collectionId INT NOT NULL,
                postId INT NOT NULL,
                createdAt DATETIME DEFAULT GETDATE(),
                FOREIGN KEY (collectionId) REFERENCES PostCollections(id) ON DELETE CASCADE
            );
        `);
    } catch (err) {
        console.error('Error ensuring collection tables:', err);
    }
}
ensureCollectionTables();

// Get user collections
router.get('/collections/all', authMiddleware, async (req, res) => {
    const { uid } = req.user;
    try {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('userUid', sql.NVARCHAR, uid)
            .query(`
                SELECT 
                    c.*,
                    (SELECT COUNT(*) FROM PostCollectionItems WHERE collectionId = c.id) as postCount,
                    (
                        SELECT TOP 1 pm.mediaUrl 
                        FROM PostCollectionItems pci
                        JOIN PostMedia pm ON pci.postId = pm.postId
                        WHERE pci.collectionId = c.id
                        ORDER BY pci.createdAt DESC
                    ) as coverUrl
                FROM PostCollections c
                WHERE userUid = @userUid
                ORDER BY createdAt DESC
            `);
        res.status(200).json(result.recordset);
    } catch (err) {
        console.error('Error fetching collections:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// Get user collections with post inclusion flag
router.get('/collections/post/:postId', authMiddleware, async (req, res) => {
    const { uid } = req.user;
    const { postId } = req.params;
    try {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('userUid', sql.NVARCHAR, uid)
            .input('postId', sql.INT, postId)
            .query(`
                SELECT 
                    c.*,
                    (SELECT COUNT(*) FROM PostCollectionItems WHERE collectionId = c.id) as postCount,
                    CASE WHEN EXISTS (SELECT 1 FROM PostCollectionItems WHERE collectionId = c.id AND postId = @postId) THEN 1 ELSE 0 END as isInCollection,
                    (
                        SELECT TOP 1 pm.mediaUrl 
                        FROM PostCollectionItems pci
                        JOIN PostMedia pm ON pci.postId = pm.postId
                        WHERE pci.collectionId = c.id
                        ORDER BY pci.createdAt DESC
                    ) as coverUrl
                FROM PostCollections c
                WHERE userUid = @userUid
                ORDER BY isInCollection DESC, createdAt DESC
            `);
        res.status(200).json(result.recordset);
    } catch (err) {
        console.error('Error fetching collections with post flag:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// Create collection
router.post('/collections', authMiddleware, async (req, res) => {
    const { name } = req.body;
    const { uid } = req.user;
    if (!name) return res.status(400).json({ error: 'Name is required' });

    try {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('userUid', sql.NVARCHAR, uid)
            .input('name', sql.NVARCHAR, name)
            .query(`
                INSERT INTO PostCollections (userUid, name)
                OUTPUT INSERTED.*
                VALUES (@userUid, @name)
            `);
        res.status(201).json(result.recordset[0]);
    } catch (err) {
        console.error('Error creating collection:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// Update collection
router.put('/collections/:id', authMiddleware, async (req, res) => {
    const { id } = req.params;
    const { name } = req.body;
    const { uid } = req.user;

    try {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('id', sql.INT, id)
            .input('userUid', sql.NVARCHAR, uid)
            .input('name', sql.NVARCHAR, name)
            .query(`
                UPDATE PostCollections 
                SET name = @name 
                OUTPUT INSERTED.*
                WHERE id = @id AND userUid = @userUid
            `);
        if (result.recordset.length === 0) return res.status(404).json({ error: 'Collection not found' });
        res.status(200).json(result.recordset[0]);
    } catch (err) {
        console.error('Error updating collection:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// Delete collection
router.delete('/collections/:id', authMiddleware, async (req, res) => {
    const { id } = req.params;
    const { uid } = req.user;
    try {
        const pool = await poolPromise;
        await pool.request()
            .input('id', sql.INT, id)
            .input('userUid', sql.NVARCHAR, uid)
            .query('DELETE FROM PostCollections WHERE id = @id AND userUid = @userUid');
        res.status(200).json({ message: 'Collection deleted' });
    } catch (err) {
        console.error('Error deleting collection:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// Add post to collection
router.post('/collections/:id/add', authMiddleware, async (req, res) => {
    const { id } = req.params;
    const { postId } = req.body;
    const { uid } = req.user;

    try {
        const pool = await poolPromise;
        const transaction = new sql.Transaction(pool);
        await transaction.begin();

        try {
            // 1. Verify ownership of the collection
            const collVerify = await transaction.request()
                .input('id', sql.INT, id)
                .input('userUid', sql.NVARCHAR, uid)
                .query('SELECT id FROM PostCollections WHERE id = @id AND userUid = @userUid');
            
            if (collVerify.recordset.length === 0) {
                await transaction.rollback();
                return res.status(403).json({ error: 'Forbidden' });
            }

            // 2. Ensure post is GLOBALLY SAVED (in SavedPosts table)
            const saveVerify = await transaction.request()
                .input('postId', sql.INT, postId)
                .input('userUid', sql.NVARCHAR, uid)
                .query('SELECT id FROM SavedPosts WHERE postId = @postId AND userUid = @userUid');
            
            if (saveVerify.recordset.length === 0) {
                await transaction.request()
                    .input('postId', sql.INT, postId)
                    .input('userUid', sql.NVARCHAR, uid)
                    .query('INSERT INTO SavedPosts (postId, userUid) VALUES (@postId, @userUid)');
            }

            // 3. Check if already in this specific collection
            const itemVerify = await transaction.request()
                .input('collId', sql.INT, id)
                .input('postId', sql.INT, postId)
                .query('SELECT id FROM PostCollectionItems WHERE collectionId = @collId AND postId = @postId');
            
            if (itemVerify.recordset.length > 0) {
                await transaction.commit();
                return res.status(200).json({ message: 'Already in collection' });
            }

            // 4. Insert into collection
            await transaction.request()
                .input('collId', sql.INT, id)
                .input('postId', sql.INT, postId)
                .query('INSERT INTO PostCollectionItems (collectionId, postId) VALUES (@collId, @postId)');
            
            await transaction.commit();
            res.status(201).json({ success: true });
        } catch (txnErr) {
            await transaction.rollback();
            throw txnErr;
        }
    } catch (err) {
        console.error('Error adding to collection:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// Remove post from collection
router.delete('/collections/:id/remove/:postId', authMiddleware, async (req, res) => {
    const { id, postId } = req.params;
    const { uid } = req.user;

    try {
        const pool = await poolPromise;
        // Verify ownership
        const collVerify = await pool.request()
            .input('id', sql.INT, id)
            .input('userUid', sql.NVARCHAR, uid)
            .query('SELECT id FROM PostCollections WHERE id = @id AND userUid = @userUid');
        
        if (collVerify.recordset.length === 0) return res.status(403).json({ error: 'Forbidden' });

        await pool.request()
            .input('collId', sql.INT, id)
            .input('postId', sql.INT, postId)
            .query('DELETE FROM PostCollectionItems WHERE collectionId = @collId AND postId = @postId');
        
        res.status(200).json({ success: true });
    } catch (err) {
        console.error('Error removing from collection:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// Get posts in a collection
router.get('/collections/:id/posts', authMiddleware, async (req, res) => {
    const { id } = req.params;
    const { uid } = req.user;
    try {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('id', sql.INT, id)
            .input('currentUserUid', sql.NVARCHAR, uid)
            .query(`
                SELECT 
                    p.*, 
                    u.fullName as userName, 
                    u.profilePictureUrl as userAvatar,
                    u.coverPhotoUrl as userCover,
                    (SELECT COUNT(*) FROM Likes WHERE postId = p.id) as likesCount,
                    (SELECT COUNT(*) FROM Comments WHERE postId = p.id) as commentsCount,
                    CASE WHEN EXISTS (SELECT 1 FROM Likes WHERE postId = p.id AND userUid = @currentUserUid) THEN 1 ELSE 0 END as isLiked,
                    CASE WHEN EXISTS (SELECT 1 FROM SavedPosts WHERE postId = p.id AND userUid = @currentUserUid) THEN 1 ELSE 0 END as isSaved,
                    (SELECT mediaUrl as url, mediaType as type FROM PostMedia WHERE postId = p.id FOR JSON PATH) as media
                FROM PostCollectionItems pci
                JOIN Posts p ON pci.postId = p.id
                JOIN Users u ON p.userUid = u.firebaseUid
                WHERE pci.collectionId = @id
                ORDER BY pci.createdAt DESC
            `);
        
        const posts = result.recordset.map(post => ({
            ...post,
            media: post.media ? JSON.parse(post.media) : []
        }));
        res.status(200).json(posts);
    } catch (err) {
        console.error('Error fetching collection posts:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

module.exports = router;
