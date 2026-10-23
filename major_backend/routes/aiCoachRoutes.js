const express = require('express');
const router = express.Router();
const { poolPromise, sql } = require('../config/db');
const authMiddleware = require('../middleware/auth');

// --- AI Coach Messages ---

// Get persistent chat history for the AI Coach
router.get('/messages', authMiddleware, async (req, res) => {
    const { uid } = req.user;
    try {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('uid', sql.NVARCHAR, uid)
            .query('SELECT role, content, createdAt FROM AICoachMessages WHERE userUid = @uid ORDER BY createdAt ASC');
        res.json(result.recordset);
    } catch (err) {
        console.error('Error fetching AI coach messages:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// Save a new message (user or assistant) to the AI coach history
router.post('/messages', authMiddleware, async (req, res) => {
    const { uid } = req.user;
    const { role, content } = req.body;
    try {
        const pool = await poolPromise;
        await pool.request()
            .input('uid', sql.NVARCHAR, uid)
            .input('role', sql.NVARCHAR, role)
            .input('content', sql.NVARCHAR, content)
            .query('INSERT INTO AICoachMessages (userUid, role, content) VALUES (@uid, @role, @content)');
        res.status(201).json({ message: 'Message saved' });
    } catch (err) {
        console.error('Error saving AI coach message:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// --- Workout Logs ---

// Log a completed workout
router.post('/log-workout', authMiddleware, async (req, res) => {
    const { uid } = req.user;
    const { workoutName, exercises, duration, caloriesBurned } = req.body;
    try {
        const pool = await poolPromise;
        await pool.request()
            .input('uid', sql.NVARCHAR, uid)
            .input('name', sql.NVARCHAR, workoutName)
            .input('exercises', sql.NVARCHAR, JSON.stringify(exercises))
            .input('duration', sql.INT, duration)
            .input('calories', sql.INT, caloriesBurned)
            .query(`
                INSERT INTO WorkoutLogs (userUid, workoutName, exercises, duration, caloriesBurned)
                VALUES (@uid, @name, @exercises, @duration, @calories)
            `);
        res.status(201).json({ message: 'Workout logged successfully' });
    } catch (err) {
        console.error('Error logging workout:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// Get recent workout logs for the user (for AI context)
router.get('/workout-history', authMiddleware, async (req, res) => {
    const { uid } = req.user;
    const limit = parseInt(req.query.limit) || 5;
    try {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('uid', sql.NVARCHAR, uid)
            .input('limit', sql.INT, limit)
            .query(`
                SELECT TOP (@limit) id, workoutName, exercises, duration, caloriesBurned, createdAt 
                FROM WorkoutLogs 
                WHERE userUid = @uid 
                ORDER BY createdAt DESC
            `);

        // Parse JSON exercises back to objects
        const logs = result.recordset.map(log => ({
            ...log,
            exercises: JSON.parse(log.exercises || '[]')
        }));

        res.json(logs);
    } catch (err) {
        console.error('Error fetching workout history:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// --- User Plans ---

// Save an AI-generated plan
router.post('/save-plan', authMiddleware, async (req, res) => {
    const { uid } = req.user;
    const { planData, isAI } = req.body;
    try {
        const pool = await poolPromise;
        await pool.request()
            .input('uid', sql.NVARCHAR, uid)
            .input('data', sql.NVARCHAR, JSON.stringify(planData))
            .input('isAI', sql.BIT, isAI ? 1 : 0)
            .query('INSERT INTO UserPlans (userUid, planData, isAI) VALUES (@uid, @data, @isAI)');
        res.status(201).json({ message: 'Plan saved successfully' });
    } catch (err) {
        console.error('Error saving user plan:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// Get saved plans for the user
router.get('/plans', authMiddleware, async (req, res) => {
    const { uid } = req.user;
    try {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('uid', sql.NVARCHAR, uid)
            .query('SELECT id, planData, isAI, createdAt FROM UserPlans WHERE userUid = @uid ORDER BY createdAt DESC');

        const plans = result.recordset.map(plan => ({
            ...plan,
            planData: JSON.parse(plan.planData || '{}')
        }));

        res.json(plans);
    } catch (err) {
        console.error('Error fetching user plans:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// --- Premium & Usage Limits ---

// Get usage limits and premium status
router.get('/usage', authMiddleware, async (req, res) => {
    const { uid } = req.user;
    try {
        const pool = await poolPromise;

        // 1. Fetch usage limits
        const usageResult = await pool.request()
            .input('uid', sql.NVARCHAR, uid)
            .query('SELECT limitType, messageCount, lastResetDate FROM DailyUsageLimits WHERE firebaseUid = @uid');

        // 2. Fetch user premium status
        const userResult = await pool.request()
            .input('uid', sql.NVARCHAR, uid)
            .query('SELECT isPremium FROM Users WHERE firebaseUid = @uid');

        const isPremium = userResult.recordset[0]?.isPremium || false;

        // Reset if date changed
        const today = new Date().toISOString().split('T')[0];
        const limits = usageResult.recordset.map(row => {
            const rowDate = new Date(row.lastResetDate).toISOString().split('T')[0];
            if (rowDate !== today) {
                return { limitType: row.limitType, messageCount: 0 };
            }
            return { limitType: row.limitType, messageCount: row.messageCount };
        });

        res.json({
            isPremium: isPremium === true || isPremium === 1,
            limits: limits
        });
    } catch (err) {
        console.error('Error fetching usage limits:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// Increment usage for a specific limit type
router.post('/increment-usage', authMiddleware, async (req, res) => {
    const { uid } = req.user;
    const { limitType } = req.body; // 'social_chat' or 'workout_chat'
    if (!limitType) return res.status(400).json({ error: 'limitType required' });

    try {
        const pool = await poolPromise;
        const today = new Date().toISOString().split('T')[0];

        await pool.request()
            .input('uid', sql.NVARCHAR, uid)
            .input('type', sql.NVARCHAR, limitType)
            .input('today', sql.DATE, today)
            .query(`
                IF EXISTS (SELECT 1 FROM DailyUsageLimits WHERE firebaseUid = @uid AND limitType = @type)
                BEGIN
                    DECLARE @lastDate DATE;
                    SELECT @lastDate = lastResetDate FROM DailyUsageLimits WHERE firebaseUid = @uid AND limitType = @type;
                    
                    IF @lastDate < @today
                    BEGIN
                        UPDATE DailyUsageLimits SET messageCount = 1, lastResetDate = @today WHERE firebaseUid = @uid AND limitType = @type;
                    END
                    ELSE
                    BEGIN
                        UPDATE DailyUsageLimits SET messageCount = messageCount + 1 WHERE firebaseUid = @uid AND limitType = @type;
                    END
                END
                ELSE
                BEGIN
                    INSERT INTO DailyUsageLimits (firebaseUid, limitType, messageCount, lastResetDate)
                    VALUES (@uid, @type, 1, @today);
                END
            `);

        res.json({ message: 'Usage incremented' });
    } catch (err) {
        console.error('Error incrementing usage:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

module.exports = router;
