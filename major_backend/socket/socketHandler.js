const { poolPromise, sql } = require('../config/db');

// Keep track of socketId -> uid for disconnect handling
const onlineUsers = new Map();

module.exports = (io) => {
    io.on('connection', (socket) => {
        console.log('New client connected:', socket.id);

        // User joins their own room identified by UID for direct messaging
        socket.on('join_user_room', async (uid) => {
            if (uid) {
                socket.join(uid);
                console.log(`User ${uid} joined room ${uid}`);
                onlineUsers.set(socket.id, { uid, activeChat: null });

                // Set user as Online in DB
                try {
                    const pool = await poolPromise;
                    await pool.request()
                        .input('uid', sql.NVARCHAR, uid)
                        .query('UPDATE Users SET isOnline = 1 WHERE firebaseUid = @uid');

                    // Optional: Broadcast to contacts that this user came online?
                    // For now, let's just update DB. Client polls or listens.
                } catch (err) {
                    console.error('Error setting user online:', err);
                }
            }
        });

        // Handle sending a private message
        socket.on('send_message', async ({ senderUid, receiverUid, content, mediaUrl, mediaType, parentId, parentContent, parentMediaType }) => {
            try {
                const pool = await poolPromise;

                // 1. Check if ANYONE blocked ANYONE
                const blockCheck = await pool.request()
                    .input('u1', sql.NVARCHAR, senderUid)
                    .input('u2', sql.NVARCHAR, receiverUid)
                    .query(`SELECT * FROM Blocks WHERE (blockerUid = @u1 AND blockedUid = @u2) OR (blockerUid = @u2 AND blockedUid = @u1)`);

                if (blockCheck.recordset.length > 0) {
                    console.log('Message blocked by user settings');
                    return;
                }

                // 2. Check chat request status
                const requestCheck = await pool.request()
                    .input('sender', sql.NVARCHAR, senderUid)
                    .input('receiver', sql.NVARCHAR, receiverUid)
                    .query(`
                        SELECT * FROM ChatRequests 
                        WHERE (senderUid = @sender AND receiverUid = @receiver) 
                           OR (senderUid = @receiver AND receiverUid = @sender)
                    `);

                let status = 'none';
                if (requestCheck.recordset.length > 0) {
                    status = requestCheck.recordset[0].status;
                } else {
                    // Create pending request if it doesn't exist
                    await pool.request()
                        .input('sender', sql.NVARCHAR, senderUid)
                        .input('receiver', sql.NVARCHAR, receiverUid)
                        .query(`INSERT INTO ChatRequests (senderUid, receiverUid, status, createdAt, updatedAt) VALUES (@sender, @receiver, 'pending', GETUTCDATE(), GETUTCDATE())`);
                    status = 'pending';
                    io.to(receiverUid).emit('new_request', { senderUid });

                    // --- NEW: Insert Chat Request into Notifications table ---
                    try {
                        const senderResult = await pool.request()
                            .input('uid', sql.NVARCHAR, senderUid)
                            .query('SELECT fullName FROM Users WHERE firebaseUid = @uid');
                        const senderName = senderResult.recordset[0]?.fullName || 'Someone';

                        await pool.request()
                            .input('recipientUid', sql.NVARCHAR, receiverUid)
                            .input('senderUid', sql.NVARCHAR, senderUid)
                            .input('type', sql.NVARCHAR, 'chat_request')
                            .input('title', sql.NVARCHAR, 'New Chat Request')
                            .input('message', sql.NVARCHAR, `${senderName} wants to chat with you`)
                            .input('referenceId', sql.NVARCHAR, senderUid)
                            .query(`
                                INSERT INTO Notifications (recipientUid, senderUid, type, title, message, referenceId, createdAt)
                                VALUES (@recipientUid, @senderUid, @type, @title, @message, @referenceId, GETUTCDATE())
                            `);
                    } catch (notifErr) {
                        console.error('Error recording chat request notification:', notifErr);
                    }
                    // ---------------------------------------------------------
                }

                // 3. Save Message to DB (including media and parent info)
                const msgResult = await pool.request()
                    .input('sender', sql.NVARCHAR, senderUid)
                    .input('receiver', sql.NVARCHAR, receiverUid)
                    .input('content', sql.NVARCHAR, content || null)
                    .input('mediaUrl', sql.NVARCHAR, mediaUrl || null)
                    .input('mediaType', sql.NVARCHAR, mediaType || null)
                    .input('parentId', sql.INT, parentId || null)
                    .input('parentContent', sql.NVARCHAR, parentContent || null)
                    .input('parentMediaType', sql.NVARCHAR, parentMediaType || null)
                    .query(`
                        INSERT INTO Messages (senderUid, receiverUid, content, mediaUrl, mediaType, createdAt, parentId, parentContent, parentMediaType)
                        OUTPUT inserted.*
                        VALUES (@sender, @receiver, @content, @mediaUrl, @mediaType, GETUTCDATE(), @parentId, @parentContent, @parentMediaType)
                    `);

                const newMessage = msgResult.recordset[0];

                // 4. Emit to both parties
                io.to(receiverUid).emit('receive_message', newMessage);
                io.to(senderUid).emit('receive_message', newMessage);

                // Send Push Notification
                await sendPushNotification(receiverUid, newMessage, senderUid);

            } catch (err) {
                console.error('Socket Send Message Error:', err);
            }
        });

        // Helper function to send push notification
        const sendPushNotification = async (receiverUid, message, senderUid) => {
            try {
                const pool = await poolPromise;

                // Get receiver's FCM token and details
                const userResult = await pool.request()
                    .input('uid', sql.NVARCHAR, receiverUid)
                    .query('SELECT fcmToken, fullName FROM Users WHERE firebaseUid = @uid');

                if (userResult.recordset.length === 0) return;
                const receiver = userResult.recordset[0];
                if (!receiver.fcmToken) return;

                // Check if receiver is currently in chat with sender
                const receiverSocketEntry = [...onlineUsers.entries()]
                    .find(([_, userState]) => userState.uid === receiverUid);

                if (receiverSocketEntry) {
                    const receiverSocketId = receiverSocketEntry[0];
                    const activeChat = onlineUsers.get(receiverSocketId).activeChat;
                    if (activeChat === senderUid) {
                        console.log(`User ${receiverUid} is active in chat with ${senderUid}, skipping notification.`);
                        return;
                    }
                }

                // Get sender's details
                const senderResult = await pool.request()
                    .input('uid', sql.NVARCHAR, senderUid)
                    .query('SELECT fullName, profilePictureUrl FROM Users WHERE firebaseUid = @uid');

                const senderDetails = senderResult.recordset[0];
                const senderName = senderDetails?.fullName || 'Someone';
                let senderAvatar = senderDetails?.profilePictureUrl;

                // --- NEW: Insert into Notifications table ---
                try {
                    await pool.request()
                        .input('recipientUid', sql.NVARCHAR, receiverUid)
                        .input('senderUid', sql.NVARCHAR, senderUid)
                        .input('type', sql.NVARCHAR, 'message')
                        .input('title', sql.NVARCHAR, senderName)
                        .input('message', sql.NVARCHAR, message.content || (message.mediaUrl ? 'Sent a media' : 'Sent a message'))
                        .input('referenceId', sql.NVARCHAR, senderUid) // Using senderUid as reference for navigation
                        .query(`
                            INSERT INTO Notifications (recipientUid, senderUid, type, title, message, referenceId, createdAt)
                            VALUES (@recipientUid, @senderUid, @type, @title, @message, @referenceId, GETUTCDATE())
                        `);
                    console.log(`Chat notification inserted for ${receiverUid} from ${senderUid}`);
                } catch (dbErr) {
                    console.error('Error inserting chat notification into DB:', dbErr);
                }
                // ------------------------------------------

                if (senderAvatar && senderAvatar.includes('cloudinary.com')) {
                    senderAvatar = senderAvatar.replace('/upload/', '/upload/w_200,h_200,c_fill,q_auto,f_png/');
                }

                const notificationPayload = {
                    notification: {
                        title: senderName,
                        body: message.content || (message.mediaUrl ? 'Sent a media' : 'Sent a message'),
                    },
                    android: {
                        priority: 'high',
                        notification: {
                            icon: 'ic_notification',
                            color: '#B794F6',
                            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
                        }
                    },
                    data: {
                        type: 'chat_message',
                        senderUid: senderUid,
                        senderAvatar: senderAvatar || '',
                        click_action: 'FLUTTER_NOTIFICATION_CLICK'
                    },
                    token: receiver.fcmToken,
                    apns: {
                        payload: {
                            aps: {
                                sound: 'default',
                                contentAvailable: true,
                            }
                        }
                    }
                };

                const admin = require('../config/firebase');
                console.log('Sending FCM Payload:', JSON.stringify(notificationPayload, null, 2));
                const response = await admin.messaging().send(notificationPayload);
                console.log('Notification sent successfully. Response:', response);

            } catch (err) {
                console.error('Error sending push notification:', err);
            }
        };

        // Track Active Chat
        socket.on('enter_chat', (partnerUid) => {
            const userState = onlineUsers.get(socket.id);
            if (userState) {
                onlineUsers.set(socket.id, { ...userState, activeChat: partnerUid });
                console.log(`User ${userState.uid} entered chat with ${partnerUid}`);
            }
        });

        socket.on('leave_chat', () => {
            const userState = onlineUsers.get(socket.id);
            if (userState) {
                onlineUsers.set(socket.id, { ...userState, activeChat: null });
                console.log(`User ${userState.uid} left chat`);
            }
        });

        // Add Seen/Read Status
        socket.on('mark_as_read', async ({ senderUid, receiverUid }) => {
            try {
                const pool = await poolPromise;
                await pool.request()
                    .input('sender', sql.NVARCHAR, senderUid) // The person whose messages are being read
                    .input('receiver', sql.NVARCHAR, receiverUid) // The person reading (current user)
                    .query(`UPDATE Messages SET isRead = 1 WHERE senderUid = @sender AND receiverUid = @receiver AND isRead = 0`);

                // Notify the sender that their messages were seen
                io.to(senderUid).emit('messages_seen', { seenBy: receiverUid });
            } catch (err) {
                console.error('Socket Mark Read Error:', err);
            }
        });

        // Unsend message handler
        socket.on('unsend_message', ({ messageId, receiverUid, senderUid }) => {
            // Broadcast to the other person and the sender
            io.to(receiverUid).emit('message_deleted', { messageId });
            io.to(senderUid).emit('message_deleted', { messageId });
        });

        // Get User Status
        socket.on('get_user_status', async (uid) => {
            try {
                const pool = await poolPromise;
                const result = await pool.request()
                    .input('uid', sql.NVARCHAR, uid)
                    .query('SELECT isOnline, lastActive FROM Users WHERE firebaseUid = @uid');

                if (result.recordset.length > 0) {
                    const user = result.recordset[0];
                    socket.emit('user_status', {
                        uid: uid,
                        isOnline: user.isOnline,
                        lastActive: user.lastActive
                    });
                }
            } catch (err) {
                console.error('Error fetching user status:', err);
            }
        });

        socket.on('disconnect', async () => {
            console.log('Client disconnected:', socket.id);
            const userData = onlineUsers.get(socket.id);
            if (userData) {
                const { uid } = userData;
                onlineUsers.delete(socket.id);
                // Set user as Offline in DB
                try {
                    const pool = await poolPromise;
                    await pool.request()
                        .input('uid', sql.NVARCHAR, uid)
                        .query('UPDATE Users SET isOnline = 0, lastActive = GETUTCDATE() WHERE firebaseUid = @uid');
                } catch (err) {
                    console.error('Error setting user offline:', err);
                }
            }
        });
    });
};
