const { poolPromise, sql } = require('./config/db');
require('dotenv').config();

const bios = [
    "Fitness enthusiast. Love lifting and healthy living! 💪",
    "On a journey to get stronger every day. Let's work out together!",
    "Marathon runner in training. Looking for a partner to push limits.",
    "Lover of HIIT and strength training. Grinding never stops! 🔥",
    "Casual gym goer. Let's stay active and healthy.",
    "Looking for a motivated workout partner to keep me accountable.",
    "Yoga and functional training enthusiast. Movement is life! 🧘‍♂️",
    "Getting back into fitness. Beginner-friendly vibes only!",
    "Strength training is my passion. PB hunting! 🏆",
    "Crossfit lover and enthusiast. Hard work pays off."
];

const fitnessGoals = ["Weight Loss", "Muscle Gain", "Endurance", "General Fitness", "Bodybuilding", "Flexibility", "Strength"];
const lookingFor = ["Workout Buddy", "Sports Partner", "Gym Motivation", "Running Partner", "Yoga Friend"];
const levels = ["Beginner", "Intermediate", "Advanced", "Elite"];
const genders = ["Male", "Female", "Prefer not to say"];
const workoutLocations = ["Gym", "Home", "Outdoor", "Hybrid"];
const focusAreas = ["Chest", "Back", "Legs", "Arms", "Shoulders", "Core", "Full Body"];
const equipment = ["Dumbbells", "Barbell", "Resistance Bands", "Kettlebells", "Pull-up Bar", "Bench", "Squat Rack", "Treadmill"];
const preferences = ["Basketball", "Swimming", "Running", "Weightlifting", "Yoga", "Cycling", "Tennis", "HIIT"];
const days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
const timeSpans = ["6:00 AM - 9:00 AM", "9:00 AM - 12:00 PM", "1:00 PM - 4:00 PM", "5:00 PM - 8:00 PM", "8:00 PM - 11:00 PM"];

async function run() {
    let pool;
    try {
        pool = await poolPromise;

        const usersRes = await pool.request().query("SELECT firebaseUid, fullName FROM Users WHERE email LIKE 'dummy%@spottr.com'");
        const users = usersRes.recordset;

        console.log(`Starting full profile completion for ${users.length} dummy users...`);

        for (const user of users) {
            const randomGender = genders[Math.floor(Math.random() * genders.length)];
            const randomAge = 19 + Math.floor(Math.random() * 22);
            const randomWeight = 55 + Math.floor(Math.random() * 40);
            const randomHeight = 155 + Math.floor(Math.random() * 35);
            const randomBio = bios[Math.floor(Math.random() * bios.length)];
            const randomGoal = fitnessGoals[Math.floor(Math.random() * fitnessGoals.length)];
            const randomLevel = levels[Math.floor(Math.random() * levels.length)];
            const randomFreq = 3 + Math.floor(Math.random() * 4);
            const randomLoc = workoutLocations[Math.floor(Math.random() * workoutLocations.length)];
            const randomExp = 1 + Math.floor(Math.random() * 10);
            const randomLooking = lookingFor[Math.floor(Math.random() * lookingFor.length)];
            
            // Focus Areas
            const shuffledFocus = [...focusAreas].sort(() => 0.5 - Math.random());
            const selectedFocus = shuffledFocus.slice(0, 2 + Math.floor(Math.random() * 3));

            // Equipment
            const shuffledEquip = [...equipment].sort(() => 0.5 - Math.random());
            const selectedEquip = shuffledEquip.slice(0, 3 + Math.floor(Math.random() * 4));

            // Preferences
            const shuffledPrefs = [...preferences].sort(() => 0.5 - Math.random());
            const selectedPrefs = shuffledPrefs.slice(0, 2 + Math.floor(Math.random() * 4));

            // Availability
            const shuffledDays = [...days].sort(() => 0.5 - Math.random());
            const selectedDays = shuffledDays.slice(0, 3 + Math.floor(Math.random() * 3));
            
            // Time Spans object
            const availSpans = {};
            selectedDays.forEach(day => {
                availSpans[day] = timeSpans[Math.floor(Math.random() * timeSpans.length)];
            });

            await pool.request()
                .input('uid', sql.NVARCHAR, user.firebaseUid)
                .input('gender', sql.NVARCHAR, randomGender)
                .input('age', sql.INT, randomAge)
                .input('weight', sql.FLOAT, randomWeight)
                .input('height', sql.FLOAT, randomHeight)
                .input('bio', sql.NVARCHAR, randomBio)
                .input('goal', sql.NVARCHAR, randomGoal)
                .input('level', sql.NVARCHAR, randomLevel)
                .input('freq', sql.INT, randomFreq)
                .input('loc', sql.NVARCHAR, randomLoc)
                .input('exp', sql.INT, randomExp)
                .input('looking', sql.NVARCHAR, randomLooking)
                .input('focus', sql.NVARCHAR, JSON.stringify(selectedFocus))
                .input('equip', sql.NVARCHAR, JSON.stringify(selectedEquip))
                .input('prefs', sql.NVARCHAR, JSON.stringify(selectedPrefs))
                .input('avail', sql.NVARCHAR, JSON.stringify(selectedDays))
                .input('spans', sql.NVARCHAR, JSON.stringify(availSpans))
                .query(`
                    UPDATE Users 
                    SET gender = @gender,
                        age = @age,
                        weight = @weight,
                        height = @height,
                        bio = @bio,
                        fitness_goal = @goal,
                        training_level = @level,
                        workout_frequency = @freq,
                        workout_location = @loc,
                        experience = @exp,
                        looking_for = @looking,
                        focus_areas = @focus,
                        equipment_list = @equip,
                        preferences = @prefs,
                        availability = @avail,
                        availability_time_spans = @spans,
                        weight_unit = 'kg',
                        location_privacy = 'full',
                        is_setup_completed = 1,
                        updatedAt = GETUTCDATE()
                    WHERE firebaseUid = @uid
                `);

            console.log(`Fully updated profile for: ${user.fullName} (${user.firebaseUid})`);
        }

        console.log('--- ALL DUMMY ACCOUNTS ARE NOW FULLY POPULATED! ---');

    } catch (err) {
        console.error('Error during full dummy population:', err);
    } finally {
        if (pool) process.exit();
    }
}

run();
