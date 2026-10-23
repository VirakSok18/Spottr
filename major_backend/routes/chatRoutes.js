const express = require('express');
const router = express.Router();
const { poolPromise, sql } = require('../config/db');
const authMiddleware = require('../middleware/auth');
const multer = require('multer');
const cloudinary = require('cloudinary').v2;
const streamifier = require('streamifier');

// Cloudinary Configuration
cloudinary.config({
    cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
    api_key: process.env.CLOUDINARY_API_KEY,
    api_secret: process.env.CLOUDINARY_API_SECRET
});

const storage = multer.memoryStorage();
const upload = multer({ storage: storage });

// Get all "Active" conversations (status = accepted)
router.get('/conversations', authMiddleware, async (req, res) => {
    const { uid } = req.user;
    try {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('uid', sql.NVARCHAR, uid)
            .query(`
                SELECT 
                    U.firebaseUid, U.fullName, U.profilePictureUrl, U.coverPhotoUrl,
                    CR.status, CR.updatedAt as acceptedAt,
                    (SELECT TOP 1 content FROM Messages 
                     WHERE (senderUid = U.firebaseUid AND receiverUid = @uid) 
                        OR (senderUid = @uid AND receiverUid = U.firebaseUid)
                     ORDER BY createdAt DESC) as lastMessage,
                    (SELECT TOP 1 createdAt FROM Messages 
                     WHERE (senderUid = U.firebaseUid AND receiverUid = @uid) 
                        OR (senderUid = @uid AND receiverUid = U.firebaseUid)
                     ORDER BY createdAt DESC) as lastMessageTime,
                    (SELECT COUNT(*) FROM Messages 
                     WHERE senderUid = U.firebaseUid AND receiverUid = @uid AND isRead = 0) as unreadCount,
                    (SELECT TOP 1 mediaType FROM Messages 
                     WHERE (senderUid = U.firebaseUid AND receiverUid = @uid) 
                        OR (senderUid = @uid AND receiverUid = U.firebaseUid)
                     ORDER BY createdAt DESC) as lastMediaType
                FROM ChatRequests CR
                JOIN Users U ON (CR.senderUid = U.firebaseUid OR CR.receiverUid = U.firebaseUid)
                WHERE (CR.senderUid = @uid OR CR.receiverUid = @uid)
                  AND (CR.status = 'accepted' OR (CR.status = 'pending' AND CR.senderUid = @uid))
                  AND NOT EXISTS (SELECT 1 FROM Blocks WHERE blockerUid = @uid AND blockedUid = U.firebaseUid)
                  AND U.firebaseUid != @uid
                ORDER BY COALESCE(
                    (SELECT TOP 1 createdAt FROM Messages 
                     WHERE (senderUid = U.firebaseUid AND receiverUid = @uid) 
                        OR (senderUid = @uid AND receiverUid = U.firebaseUid)
                     ORDER BY createdAt DESC), 
                    CR.updatedAt
                ) DESC
            `);
        res.json(result.recordset);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Server error' });
    }
});

// Get "Requests" (Incoming pending requests)
router.get('/requests', authMiddleware, async (req, res) => {
    const { uid } = req.user;
    try {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('uid', sql.NVARCHAR, uid)
            .query(`
                SELECT 
                    U.firebaseUid, U.fullName, U.profilePictureUrl, U.coverPhotoUrl,
                    CR.createdAt as requestTime,
                    (SELECT TOP 1 content FROM Messages 
                     WHERE senderUid = U.firebaseUid AND receiverUid = @uid
                     ORDER BY createdAt DESC) as lastMessage
                FROM ChatRequests CR
                JOIN Users U ON CR.senderUid = U.firebaseUid
                WHERE CR.receiverUid = @uid 
                  AND CR.status = 'pending'
                  AND NOT EXISTS (SELECT 1 FROM Blocks WHERE blockerUid = @uid AND blockedUid = CR.senderUid)
                ORDER BY requestTime DESC
            `);
        res.json(result.recordset);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Server error' });
    }
});

// Get Messages with specific user
router.get('/messages/:otherUid', authMiddleware, async (req, res) => {
    const { uid } = req.user;
    const { otherUid } = req.params;
    try {
        const pool = await poolPromise;

        // Mark messages as read
        await pool.request()
            .input('sender', sql.NVARCHAR, otherUid)
            .input('receiver', sql.NVARCHAR, uid)
            .query(`UPDATE Messages SET isRead = 1 WHERE senderUid = @sender AND receiverUid = @receiver`);

        // Fetch history
        const result = await pool.request()
            .input('u1', sql.NVARCHAR, uid)
            .input('u2', sql.NVARCHAR, otherUid)
            .query(`
                SELECT * FROM Messages 
                WHERE (senderUid = @u1 AND receiverUid = @u2) 
                   OR (senderUid = @u2 AND receiverUid = @u1)
                ORDER BY createdAt ASC
            `);
        res.json(result.recordset);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Server error' });
    }
});

// Handle Request Action (Accept, Delete/Reject, Block)
router.post('/request/respond', authMiddleware, async (req, res) => {
    const { uid } = req.user;
    const { targetUid, action } = req.body; // action: 'accept', 'reject', 'block'

    try {
        const pool = await poolPromise;

        if (action === 'accept') {
            await pool.request()
                .input('me', sql.NVARCHAR, uid)
                .input('other', sql.NVARCHAR, targetUid)
                .query(`UPDATE ChatRequests SET status = 'accepted' WHERE (senderUid = @other AND receiverUid = @me)`);
            
            // --- NEW: Insert "Match Accepted" into Notifications table ---
            try {
                // Get name of the person who accepted (current user)
                const meResult = await pool.request()
                    .input('uid', sql.NVARCHAR, uid)
                    .query('SELECT fullName FROM Users WHERE firebaseUid = @uid');
                const myName = meResult.recordset[0]?.fullName || 'Someone';

                await pool.request()
                    .input('recipientUid', sql.NVARCHAR, targetUid)
                    .input('senderUid', sql.NVARCHAR, uid)
                    .input('type', sql.NVARCHAR, 'match_accepted')
                    .input('title', sql.NVARCHAR, 'Match Accepted')
                    .input('message', sql.NVARCHAR, `${myName} accepted your chat request!`)
                    .input('referenceId', sql.NVARCHAR, uid)
                    .query(`
                        INSERT INTO Notifications (recipientUid, senderUid, type, title, message, referenceId, createdAt)
                        VALUES (@recipientUid, @senderUid, @type, @title, @message, @referenceId, GETUTCDATE())
                    `);
            } catch (notifErr) {
                console.error('Error recording match_accepted notification:', notifErr);
            }
            // -------------------------------------------------------------

            res.json({ message: 'Request accepted' });
        }
        else if (action === 'reject') {
            // Delete the request row but keep messages (or delete messages too? usually keep messages but hid request)
            // The user said "it just removes it from request list", so we delete ChatRequests row
            await pool.request()
                .input('sender', sql.NVARCHAR, targetUid)
                .input('receiver', sql.NVARCHAR, uid)
                .query(`DELETE FROM ChatRequests WHERE senderUid = @sender AND receiverUid = @receiver`);
            res.json({ message: 'Request deleted' });
        }
        else if (action === 'block') {
            // Add to Blocks table
            await pool.request()
                .input('blocker', sql.NVARCHAR, uid)
                .input('blocked', sql.NVARCHAR, targetUid)
                .query(`
                    BEGIN TRY
                        IF NOT EXISTS (SELECT 1 FROM Blocks WHERE blockerUid = @blocker AND blockedUid = @blocked)
                        BEGIN
                            INSERT INTO Blocks (blockerUid, blockedUid) VALUES (@blocker, @blocked)
                        END
                    END TRY
                    BEGIN CATCH
                        -- Ignore unique constraint violations (2627)
                        IF ERROR_NUMBER() != 2627 THROW;
                    END CATCH
                `);

            res.json({ message: 'User blocked' });
        }
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Server error' });
    }
});

// Check chat status between two users (updated for Blocks)
router.get('/status/:otherUid', authMiddleware, async (req, res) => {
    const { uid } = req.user;
    const { otherUid } = req.params;
    try {
        const pool = await poolPromise;

        // 1. Check if ANYONE blocked ANYONE
        const blockResult = await pool.request()
            .input('u1', sql.NVARCHAR, uid)
            .input('u2', sql.NVARCHAR, otherUid)
            .query(`SELECT * FROM Blocks WHERE (blockerUid = @u1 AND blockedUid = @u2) OR (blockerUid = @u2 AND blockedUid = @u1)`);

        if (blockResult.recordset.length > 0) {
            const block = blockResult.recordset[0];
            return res.json({
                status: 'blocked',
                blockedByMe: block.blockerUid === uid
            });
        }

        // 2. Check Chat Request status
        const result = await pool.request()
            .input('u1', sql.NVARCHAR, uid)
            .input('u2', sql.NVARCHAR, otherUid)
            .query(`
                SELECT status, senderUid, receiverUid 
                FROM ChatRequests 
                WHERE (senderUid = @u1 AND receiverUid = @u2) 
                   OR (senderUid = @u2 AND receiverUid = @u1)
            `);

        if (result.recordset.length > 0) {
            res.json(result.recordset[0]);
        } else {
            res.json({ status: 'none' });
        }
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Server error' });
    }
});

// Block a user directly
router.post('/block', authMiddleware, async (req, res) => {
    const { uid } = req.user;
    const { targetUid } = req.body;
    try {
        const pool = await poolPromise;
        await pool.request()
            .input('blocker', sql.NVARCHAR, uid)
            .input('blocked', sql.NVARCHAR, targetUid)
            .query(`
                BEGIN TRY
                    IF NOT EXISTS (SELECT 1 FROM Blocks WHERE blockerUid = @blocker AND blockedUid = @blocked)
                    BEGIN
                        INSERT INTO Blocks (blockerUid, blockedUid) VALUES (@blocker, @blocked)
                    END
                END TRY
                BEGIN CATCH
                    -- Ignore unique constraint violations (2627)
                    IF ERROR_NUMBER() != 2627 THROW;
                END CATCH
            `);

        res.json({ message: 'User blocked' });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Server error' });
    }
});

// Unblock a user
router.post('/unblock', authMiddleware, async (req, res) => {
    const { uid } = req.user;
    const { targetUid } = req.body;
    try {
        const pool = await poolPromise;
        await pool.request()
            .input('blocker', sql.NVARCHAR, uid)
            .input('blocked', sql.NVARCHAR, targetUid)
            .query(`DELETE FROM Blocks WHERE blockerUid = @blocker AND blockedUid = @blocked`);

        res.json({ message: 'User unblocked' });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Server error' });
    }
});

// Get blocked users list
router.get('/blocked-users', authMiddleware, async (req, res) => {
    const { uid } = req.user;
    try {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('uid', sql.NVARCHAR, uid)
            .query(`
                SELECT U.firebaseUid, U.fullName, U.profilePictureUrl 
                FROM Blocks B
                JOIN Users U ON B.blockedUid = U.firebaseUid
                WHERE B.blockerUid = @uid
            `);
        res.json(result.recordset);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Server error' });
    }
});

// Clear conversation (delete messages)
router.post('/clear', authMiddleware, async (req, res) => {
    const { uid } = req.user;
    const { targetUid } = req.body;
    try {
        const pool = await poolPromise;
        await pool.request()
            .input('u1', sql.NVARCHAR, uid)
            .input('u2', sql.NVARCHAR, targetUid)
            .query(`
                DELETE FROM Messages WHERE (senderUid = @u1 AND receiverUid = @u2) OR (senderUid = @u2 AND receiverUid = @u1);
                DELETE FROM ChatRequests WHERE (senderUid = @u1 AND receiverUid = @u2) OR (senderUid = @u2 AND receiverUid = @u1);
            `);
        res.json({ message: 'Conversation deleted' });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Server error' });
    }
});

// Upload media for chat
router.post('/upload', authMiddleware, upload.single('media'), async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ error: 'No file uploaded' });
        }

        const isVideo = req.file.mimetype.startsWith('video/');
        const uploadStream = cloudinary.uploader.upload_stream(
            {
                folder: 'chat_media',
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

// Unsend (delete) a single message
router.delete('/messages/:messageId', authMiddleware, async (req, res) => {
    const { uid } = req.user;
    const { messageId } = req.params;

    try {
        const pool = await poolPromise;

        // Only allow sender to unsend their own message
        const result = await pool.request()
            .input('id', sql.INT, messageId)
            .input('sender', sql.NVARCHAR, uid)
            .query('DELETE FROM Messages WHERE id = @id AND senderUid = @sender');

        if (result.rowsAffected[0] === 0) {
            return res.status(403).json({ error: 'Message not found or you are not the sender' });
        }

        res.json({ message: 'Message unsent successfully' });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Server error' });
    }
});

module.exports = router;

