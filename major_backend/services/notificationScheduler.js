const cron = require('node-cron');
const admin = require('firebase-admin');
const { poolPromise, sql } = require('../config/db');

class NotificationScheduler {
    constructor() {
        this.scheduledJobs = new Map();
    }

    // Initialize cron jobs
    init() {
        // Run every hour to check for inactive users (Simple 24h reminder logic)
        cron.schedule('0 * * * *', async () => {
            console.log('Running hourly workout reminder check...');
            await this.checkAndSendReminders();
        });
    }

    async scheduleTestReminder(userId, fcmToken, delaySeconds = 15) {
        // Cancel any existing reminder for this user
        if (this.scheduledJobs.has(userId)) {
            console.log(`Cancelling existing reminder for user ${userId}`);
            clearTimeout(this.scheduledJobs.get(userId));
            this.scheduledJobs.delete(userId);
        }

        console.log(`Scheduling workout reminder for user ${userId} in ${delaySeconds}s`);

        const timeout = setTimeout(async () => {
            try {
                const pool = await poolPromise;
                const messageText = 'Hey! Time to crush your workout today! 💪';

                // 1. Save reminder to AI Chat History so it appears in Gym Bot
                await pool.request()
                    .input('uid', sql.NVARCHAR, userId)
                    .input('role', sql.NVARCHAR, 'assistant')
                    .input('content', sql.NVARCHAR, messageText)
                    .query('INSERT INTO AICoachMessages (userUid, role, content) VALUES (@uid, @role, @content)');

                // 2. Save to Notifications Table so it appears in the notification bell
                await pool.request()
                    .input('recipientUid', sql.NVARCHAR, userId)
                    .input('type', sql.NVARCHAR, 'reminder')
                    .input('title', sql.NVARCHAR, 'Gym Bot 🤖')
                    .input('message', sql.NVARCHAR, messageText)
                    .input('referenceId', sql.NVARCHAR, 'ai_coach')
                    .query(`
                        INSERT INTO Notifications (recipientUid, type, title, message, referenceId)
                        VALUES (@recipientUid, @type, @title, @message, @referenceId)
                    `);

                console.log(`Reminder sent to user ${userId}.`);

                // 3. Send Push Notification
                await this.sendPushNotification(fcmToken, {
                    title: 'Gym Bot 🤖',
                    body: messageText,
                    data: {
                        type: 'workout_reminder',
                        screen: 'CentralAICoachScreen'
                    }
                });

                // Clear record once sent
                this.scheduledJobs.delete(userId);

            } catch (error) {
                console.error('Error processing workout reminder:', error);
            }
        }, delaySeconds * 1000);

        this.scheduledJobs.set(userId, timeout);
    }

    async sendPushNotification(fcmToken, { title, body, data }) {
        if (!fcmToken) return;

        try {
            const message = {
                notification: {
                    title,
                    body,
                },
                android: {
                    notification: {
                        icon: 'ic_notification', // Reverted to custom icon
                        color: '#B794F6', // Purple accent
                        clickAction: 'FLUTTER_NOTIFICATION_CLICK',
                        channelId: 'workout_reminders_v2'
                    }
                },
                data: data || {},
                token: fcmToken
            };

            const response = await admin.messaging().send(message);
            console.log('Successfully sent message:', response);
        } catch (error) {
            console.error('Error sending message:', error);
        }
    }

    async checkAndSendReminders() {
        // Mock logic for now - real implementation would query DB for last_workout > 24h
        console.log('Checking for reminders (Mock)...');
    }
}

module.exports = new NotificationScheduler();
