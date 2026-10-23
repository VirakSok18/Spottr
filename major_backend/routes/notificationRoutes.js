const express = require('express');
const router = express.Router();
const notificationScheduler = require('../services/notificationScheduler');
const { poolPromise, sql } = require('../config/db');

const authMiddleware = require('../middleware/auth');

// GET /api/notifications
router.get('/', authMiddleware, async (req, res) => {
    const { uid } = req.user;
    try {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('uid', sql.NVARCHAR, uid)
            .query(`
                SELECT N.*, U.fullName as senderName, U.profilePictureUrl as senderAvatar, U.coverPhotoUrl as senderCover
                FROM Notifications N
                LEFT JOIN Users U ON N.senderUid = U.firebaseUid
                WHERE N.recipientUid = @uid
                ORDER BY N.createdAt DESC
            `);
        res.json(result.recordset);
    } catch (err) {
        console.error('Error fetching notifications:', err);
        res.status(500).json({ error: 'Server error' });
    }
});

// Mark single notification as read
router.put('/:id/read', authMiddleware, async (req, res) => {
    const { id } = req.params;
    const { uid } = req.user;
    try {
        const pool = await poolPromise;
        await pool.request()
            .input('id', sql.INT, id)
            .input('uid', sql.NVARCHAR, uid)
            .query('UPDATE Notifications SET isRead = 1 WHERE id = @id AND recipientUid = @uid');
        res.json({ success: true });
    } catch (err) {
        console.error('Error marking notification read:', err);
        res.status(500).json({ error: 'Server error' });
    }
});

// Mark all as read
router.put('/read-all', authMiddleware, async (req, res) => {
    const { uid } = req.user;
    try {
        const pool = await poolPromise;
        await pool.request()
            .input('uid', sql.NVARCHAR, uid)
            .query('UPDATE Notifications SET isRead = 1 WHERE recipientUid = @uid');
        res.json({ success: true });
    } catch (err) {
        console.error('Error marking all read:', err);
        res.status(500).json({ error: 'Server error' });
    }
});

// Delete single notification
router.delete('/:id', authMiddleware, async (req, res) => {
    const { id } = req.params;
    const { uid } = req.user;
    try {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('id', sql.INT, id)
            .input('uid', sql.NVARCHAR, uid)
            .query('DELETE FROM Notifications WHERE id = @id AND recipientUid = @uid');
        
        if (result.rowsAffected[0] > 0) {
            res.json({ success: true, message: 'Notification deleted' });
        } else {
            res.status(404).json({ error: 'Notification not found' });
        }
    } catch (err) {
        console.error('Error deleting notification:', err);
        res.status(500).json({ error: 'Server error' });
    }
});

// Delete multiple notifications
router.post('/delete-multiple', authMiddleware, async (req, res) => {
    const { ids } = req.body; // Expects an array of IDs
    const { uid } = req.user;
    
    if (!ids || !Array.isArray(ids) || ids.length === 0) {
        return res.status(400).json({ error: 'Invalid or empty IDs array' });
    }

    try {
        const pool = await poolPromise;
        // Construct the IN clause safely
        const request = pool.request();
        request.input('uid', sql.NVARCHAR, uid);
        
        // We use a safe parameterized approach for IDs if possible, but for multiple IDs 
        // in a single query we might need to build the string if the driver doesn't support array inputs for IN.
        // MSSQL driver often needs table-valued parameters for arrays, but simple string building for small sets is common.
        const idParams = ids.map((id, index) => {
            const paramName = `id${index}`;
            request.input(paramName, sql.INT, id);
            return `@${paramName}`;
        }).join(',');

        await request.query(`DELETE FROM Notifications WHERE recipientUid = @uid AND id IN (${idParams})`);
        res.json({ success: true, message: `${ids.length} notifications deleted` });
    } catch (err) {
        console.error('Error deleting multiple notifications:', err);
        res.status(500).json({ error: 'Server error' });
    }
});

// Clear all notifications (DELETE)
router.delete('/', authMiddleware, async (req, res) => {
    const { uid } = req.user;
    try {
        const pool = await poolPromise;
        await pool.request()
            .input('uid', sql.NVARCHAR, uid)
            .query('DELETE FROM Notifications WHERE recipientUid = @uid');
        res.json({ success: true, message: 'All notifications cleared' });
    } catch (err) {
        console.error('Error clearing notifications:', err);
        res.status(500).json({ error: 'Server error' });
    }
});

// POST /api/notifications/schedule-test
router.post('/schedule-test', authMiddleware, async (req, res) => {
    const { uid } = req.user;
    const { delaySeconds } = req.body;

    try {
        const pool = await poolPromise;

        // Fetch the user's current FCM token
        const userResult = await pool.request()
            .input('uid', sql.NVARCHAR, uid)
            .query('SELECT fcmToken FROM Users WHERE firebaseUid = @uid');

        if (userResult.recordset.length === 0 || !userResult.recordset[0].fcmToken) {
            console.error('FCM token not found for user:', uid);
            return res.status(404).json({ error: 'FCM token not found. Please ensure notifications are enabled.' });
        }

        const fcmToken = userResult.recordset[0].fcmToken;

        await notificationScheduler.scheduleTestReminder(uid, fcmToken, delaySeconds || 15);
        res.json({ message: 'Test reminder scheduled' });
    } catch (error) {
        console.error('Error scheduling test reminder:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

module.exports = router;
