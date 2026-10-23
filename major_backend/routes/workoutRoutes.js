const express = require('express');
const router = express.Router();
const { poolPromise, sql } = require('../config/db');
const authMiddleware = require('../middleware/auth');

// Helper to map user training level to DB difficulty
const mapDifficulty = (level) => {
    switch (level) {
        case 'Beginner': return ['Beginner', 'Novice'];
        case 'Irregular': return ['Beginner', 'Novice', 'Intermediate'];
        case 'Medium': return ['Intermediate', 'Novice'];
        case 'Advanced': return ['Advanced', 'Intermediate'];
        default: return ['Beginner'];
    }
};

// Helper to map focus areas to DB muscle groups
const mapMuscleGroups = (area) => {
    const mapping = {
        'Full Body': null,
        'Arm': ['Biceps', 'Triceps', 'Forearms'],
        'Shoulder': ['Shoulders', 'Trapezius'],
        'Back': ['Back', 'Trapezius'],
        'Chest': ['Chest'],
        'Cores': ['Abdominals'],
        'Leg': ['Glutes', 'Hamstrings', 'Quadriceps', 'Calves', 'Adductors', 'Hip Flexors', 'Abductors']
    };
    return mapping[area] || null;
};

// Calculate BMI
const calculateBMI = (weight, height) => {
    if (!weight || !height) return 22; // Default to healthy if data missing
    const heightInMeters = height / 100;
    return weight / (heightInMeters * heightInMeters);
};

// Get split routines based on frequency
const getSplitRoutine = (frequency, dayNum) => {
    const weekDay = (dayNum - 1) % 7;

    if (frequency <= 2) {
        return 'Full Body';
    } else if (frequency <= 4) {
        // Upper/Lower Split
        const activeDays = [0, 2, 4, 6].slice(0, frequency);
        if (!activeDays.includes(weekDay)) return 'Rest';
        const activeIndex = activeDays.indexOf(weekDay);
        return activeIndex % 2 === 0 ? 'Upper' : 'Lower';
    } else {
        // Push/Pull/Legs
        const activeDays = [0, 1, 2, 4, 5, 6].slice(0, frequency);
        if (!activeDays.includes(weekDay)) return 'Rest';
        const activeIndex = activeDays.indexOf(weekDay);
        const routine = ['Push', 'Pull', 'Legs'];
        return routine[activeIndex % 3];
    }
};

// Map Split Routine to Muscle Groups
const mapRoutineToMuscles = (routine) => {
    const mapping = {
        'Upper': ['Chest', 'Back', 'Shoulders', 'Biceps', 'Triceps', 'Trapezius'],
        'Lower': ['Quadriceps', 'Hamstrings', 'Glutes', 'Calves', 'Adductors', 'Abductors', 'Hip Flexors'],
        'Push': ['Chest', 'Shoulders', 'Triceps'],
        'Pull': ['Back', 'Biceps', 'Trapezius'],
        'Legs': ['Quadriceps', 'Hamstrings', 'Glutes', 'Calves', 'Adductors', 'Abductors'],
        'Full Body': null
    };
    return mapping[routine] || null;
};

// Normalize Equipment name from frontend
const normalizeEquipment = (name) => {
    const n = name.toLowerCase().replace(/\n/g, ' ').trim();
    if (n.includes('bodyweight')) return 'Bodyweight';
    if (n.includes('dumbbell')) return 'Dumbbell';
    if (n.includes('barbell')) return 'Barbell';
    if (n.includes('cable')) return 'Cable';
    if (n.includes('machine')) return 'Machine';
    if (n.includes('kettlebell')) return 'Kettlebell';
    if (n.includes('band')) return 'Band';
    if (n.includes('plate')) return 'Plate';
    if (n.includes('rack')) return 'Barbell'; // Powerrack usually implies barbell
    return 'Other';
};

// Normalize YouTube URL to Video ID
const normalizeVideoId = (url) => {
    if (!url) return null;
    try {
        if (url.includes('v=')) {
            return url.split('v=')[1].split('&')[0].trim();
        } else if (url.includes('youtu.be/')) {
            return url.split('youtu.be/')[1].split('?')[0].trim();
        } else if (url.includes('embed/')) {
            return url.split('embed/')[1].split('?')[0].trim();
        }
        return url.trim();
    } catch (e) {
        return url;
    }
};

router.get('/suggested-plans', authMiddleware, async (req, res) => {
    try {
        const pool = await poolPromise;
        const userResult = await pool.request()
            .input('uid', sql.NVARCHAR, req.user.uid)
            .query('SELECT * FROM Users WHERE firebaseUid = @uid');

        if (userResult.recordset.length === 0) {
            return res.status(404).json({ error: 'User not found' });
        }

        const user = userResult.recordset[0];
        const focusAreas = JSON.parse(user.focus_areas || '[]');
        const equipmentList = JSON.parse(user.equipment_list || '["BodyWeight"]');
        const trainingLevel = user.training_level;
        const age = user.age || 30;
        const weight = user.weight || 70;
        const height = user.height || 170;
        const frequency = user.workout_frequency || 3;
        const goal = user.fitness_goal || 'Stay Active';
        const duration = parseInt(req.query.duration) || 7; // Revamp: Default to weekly (7 days)

        const bmi = calculateBMI(weight, height);

        // Fetch all relevant workouts once
        const workoutsResult = await pool.request().query('SELECT * FROM Workouts');
        const allWorkouts = workoutsResult.recordset;

        // Revamp: Video-URL Deduplication
        // We keep only the first exercise found for each unique video ID
        const uniqueVideoIds = new Set();
        const deduplicatedWorkouts = allWorkouts.filter(w => {
            const videoId = normalizeVideoId(w.Short_YouTube_Demonstration);
            if (!videoId) return true; // Keep exercises without videos
            if (uniqueVideoIds.has(videoId)) return false;
            uniqueVideoIds.add(videoId);
            return true;
        });

        const filteredWorkouts = deduplicatedWorkouts.filter(w => {
            const allowedDifficulties = mapDifficulty(trainingLevel);
            if (!allowedDifficulties.includes(w.Difficulty_Level)) return false;

            // Use normalization for equipment matching
            const normalizedUserEquipment = equipmentList.map(item => normalizeEquipment(item));
            const hasEquipment = normalizedUserEquipment.includes(w.Primary_Equipment) ||
                (w.Primary_Equipment === 'Bodyweight' && normalizedUserEquipment.includes('Bodyweight'));

            if (!hasEquipment && w.Primary_Equipment !== null) return false;

            return true;
        });

        // Revamp: Tier Categorization
        const tiers = {
            t1: filteredWorkouts.filter(w =>
                w.Mechanics === 'Compound' &&
                ['Primary', 'Hybrid - Ballistics & Grinds'].includes(w.Exercise_Classification)
            ),
            t2: filteredWorkouts.filter(w => w.Mechanics === 'Compound'),
            t3: filteredWorkouts.filter(w => w.Mechanics === 'Isolation'),
            t4: filteredWorkouts.filter(w => (w.Body_Region === 'Midsection') || (w.Movement_Pattern_1 && w.Movement_Pattern_1.includes('Abdominal')) || w.Force_Type === 'Static')
        };

        // Generate 3 Plans
        const plans = [];
        const areasToUse = focusAreas.length > 0 ? focusAreas : ['Full Body'];

        for (let i = 0; i < 3; i++) {
            const area = areasToUse[i % areasToUse.length];
            const areaMuscles = mapMuscleGroups(area);

            // Per-plan usage tracker to ensure variety across days
            const usageCount = {};
            filteredWorkouts.forEach(ex => usageCount[ex.Exercise_ID] = 0);

            // Plan-specific shuffling: Create a unique pool order for each plan
            const planSpecificTiers = {};
            Object.keys(tiers).forEach(t => {
                planSpecificTiers[t] = [...tiers[t]].sort(() => 0.5 - Math.random());
            });

            const days = [];

            for (let dayNum = 1; dayNum <= duration; dayNum++) {
                const routineName = getSplitRoutine(frequency, dayNum);

                if (routineName === 'Rest') {
                    days.push({ day: dayNum, exercises: [], isRestDay: true, routine: 'Rest' });
                    continue;
                }

                const routineMuscles = mapRoutineToMuscles(routineName);

                // Builder for tiered selection: 1xT1, 2xT2, 2xT3, 1xT4
                const slots = [
                    { tier: 't1', count: 1 },
                    { tier: 't2', count: 2 },
                    { tier: 't3', count: 2 },
                    { tier: 't4', count: 1 }
                ];

                let selectedForToday = [];

                for (const slot of slots) {
                    let tierPool = planSpecificTiers[slot.tier];

                    // Filter candidates for this slot
                    let candidates = tierPool.filter(w => !selectedForToday.some(s => s.Exercise_ID === w.Exercise_ID));

                    // 1. Matches Routine + Focus Area
                    let bestMatch = candidates.filter(w =>
                        (routineMuscles ? routineMuscles.includes(w.Target_Muscle_Group) : true) &&
                        (areaMuscles ? areaMuscles.includes(w.Target_Muscle_Group) : true)
                    );

                    // 2. Matches Routine OR Focus
                    let goodMatch = candidates.filter(w =>
                        (routineMuscles ? routineMuscles.includes(w.Target_Muscle_Group) : false) ||
                        (areaMuscles ? areaMuscles.includes(w.Target_Muscle_Group) : false)
                    );

                    // 3. Fallback to any exercise in this tier, or any exercise at all
                    let pool = bestMatch.length > 0 ? bestMatch : (goodMatch.length > 0 ? goodMatch : candidates);

                    if (pool.length === 0 && slot.tier !== 't1') {
                        // If tier is empty, fallback to lower tiers for variety
                        pool = filteredWorkouts.filter(w => !selectedForToday.some(s => s.Exercise_ID === w.Exercise_ID));
                    }

                    pool.sort((a, b) => (usageCount[a.Exercise_ID] || 0) - (usageCount[b.Exercise_ID] || 0));

                    // Pick exercises for this slot
                    const picked = pool.slice(0, slot.count);
                    picked.forEach(ex => {
                        selectedForToday.push(ex);
                        usageCount[ex.Exercise_ID] = (usageCount[ex.Exercise_ID] || 0) + 1;
                    });
                }

                // Final safety check: if we somehow have fewer than 6 exercises, fill
                if (selectedForToday.length < 6) {
                    const fallback = filteredWorkouts
                        .filter(w => !selectedForToday.some(s => s.Exercise_ID === w.Exercise_ID))
                        .sort((a, b) => (usageCount[a.Exercise_ID] || 0) - (usageCount[b.Exercise_ID] || 0));

                    fallback.slice(0, 6 - selectedForToday.length).forEach(ex => {
                        selectedForToday.push(ex);
                        usageCount[ex.Exercise_ID] = (usageCount[ex.Exercise_ID] || 0) + 1;
                    });
                }

                // Adjust parameters based on goal and demographics
                let reps = trainingLevel === 'Beginner' ? 10 : 12;
                let sets = 3;
                let rest = 30;

                if (goal === 'Lose Weight' || bmi > 25) {
                    reps += 3;
                    rest -= 10;
                } else if (goal === 'Gain Muscle') {
                    sets += 1;
                    rest += 30;
                }

                if (age >= 50) {
                    rest += 30;
                    sets = Math.max(2, sets - 1);
                }

                const finalDailyWorkouts = selectedForToday.map(ex => {
                    // Labeling: Core (t4) has priority, then main lift (t1), then compound (t2), else isolation (t3)
                    let currentTier = 't3';
                    if (tiers.t4.some(t => t.Exercise_ID === ex.Exercise_ID)) currentTier = 't4';
                    else if (tiers.t1.some(t => t.Exercise_ID === ex.Exercise_ID)) currentTier = 't1';
                    else if (tiers.t2.some(t => t.Exercise_ID === ex.Exercise_ID)) currentTier = 't2';

                    return {
                        id: ex.Exercise_ID,
                        name: ex.Exercise,
                        videoUrl: ex.Short_YouTube_Demonstration,
                        target: ex.Target_Muscle_Group,
                        tier: currentTier,
                        sets: sets,
                        reps: reps,
                        restSeconds: Math.max(15, rest)
                    };
                });

                days.push({
                    day: dayNum,
                    exercises: finalDailyWorkouts,
                    isRestDay: false,
                    routine: routineName,
                    title: routineName === 'Full Body' ? `Focus: ${area}` : routineName
                });
            }

            plans.push({
                id: `plan_${i + 1}`,
                title: `${area} ${['Mastery', 'Strength', 'Power'][i]}`,
                description: `A ${duration}-day professional plan focused on ${area}.`,
                days: days,
                focusArea: area,
                meta: {
                    bmi: bmi.toFixed(1),
                    goal: goal,
                    frequency: frequency
                }
            });
        }

        res.status(200).json(plans);
    } catch (err) {
        console.error('Plan Generation Error:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

const WorkoutProgramService = require('../services/workout_program_service');

router.get('/programs', async (req, res) => {
    try {
        const programs = await WorkoutProgramService.getStructuredPrograms();
        res.status(200).json(programs);
    } catch (err) {
        console.error('Fetch Programs Error:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// --- NEW: Personalized Plan Persistence ---

// Get saved personalized plans
router.get('/personalized-plans', authMiddleware, async (req, res) => {
    try {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('uid', sql.NVARCHAR, req.user.uid)
            .query('SELECT planType, planTitle, planData FROM PersonalizedWorkoutPlans WHERE firebaseUid = @uid');

        if (result.recordset.length === 0) {
            return res.status(200).json([]); // No plans saved yet
        }

        // Parse JSON data for each plan
        const plans = result.recordset.map(row => ({
            planType: row.planType,
            title: row.planTitle,
            ...JSON.parse(row.planData)
        }));

        res.status(200).json(plans);
    } catch (err) {
        console.error('Fetch Personalized Plans Error:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// Save (upsert) personalized plans
router.post('/personalized-plans', authMiddleware, async (req, res) => {
    const { plans } = req.body; // Expecting array of plan objects
    if (!Array.isArray(plans)) {
        return res.status(400).json({ error: 'Invalid plans data' });
    }

    try {
        const pool = await poolPromise;

        for (const plan of plans) {
            await pool.request()
                .input('uid', sql.NVARCHAR, req.user.uid)
                .input('type', sql.NVARCHAR, plan.planType || 'Primary')
                .input('title', sql.NVARCHAR, plan.title)
                .input('data', sql.NVARCHAR, JSON.stringify(plan))
                .query(`
                    IF EXISTS (SELECT 1 FROM PersonalizedWorkoutPlans WHERE firebaseUid = @uid AND planTitle = @title)
                    BEGIN
                        UPDATE PersonalizedWorkoutPlans 
                        SET planData = @data, updatedAt = GETDATE()
                        WHERE firebaseUid = @uid AND planTitle = @title
                    END
                    ELSE
                    BEGIN
                        INSERT INTO PersonalizedWorkoutPlans (firebaseUid, planType, planTitle, planData)
                        VALUES (@uid, @type, @title, @data)
                    END
                `);
        }

        res.status(200).json({ message: 'Plans saved successfully' });
    } catch (err) {
        console.error('Save Personalized Plans Error:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// Get progress for a specific plan
router.get('/progress/:planTitle', authMiddleware, async (req, res) => {
    try {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('uid', sql.NVARCHAR, req.user.uid)
            .input('title', sql.NVARCHAR, req.params.planTitle)
            .query('SELECT dayNumber FROM WorkoutDayProgress WHERE firebaseUid = @uid AND planTitle = @title');

        const completedDays = result.recordset.map(row => row.dayNumber);
        res.status(200).json({ completedDays });
    } catch (err) {
        console.error('Fetch Progress Error:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// Record completed day
router.post('/progress', authMiddleware, async (req, res) => {
    const { planTitle, dayNumber } = req.body;
    if (!planTitle || dayNumber === undefined) {
        return res.status(400).json({ error: 'planTitle and dayNumber are required' });
    }

    try {
        const pool = await poolPromise;
        await pool.request()
            .input('uid', sql.NVARCHAR, req.user.uid)
            .input('title', sql.NVARCHAR, planTitle)
            .input('day', sql.INT, dayNumber)
            .query(`
                IF NOT EXISTS (SELECT 1 FROM WorkoutDayProgress WHERE firebaseUid = @uid AND planTitle = @title AND dayNumber = @day)
                BEGIN
                    INSERT INTO WorkoutDayProgress (firebaseUid, planTitle, dayNumber)
                    VALUES (@uid, @title, @day)
                END
            `);

        res.status(200).json({ message: 'Progress recorded' });
    } catch (err) {
        console.error('Save Progress Error:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

module.exports = router;
