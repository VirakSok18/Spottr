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

const goals = ["Weight Loss", "Muscle Gain", "Endurance", "General Fitness", "Bodybuilding"];
const experienceYears = [1, 2, 3, 4, 5, 6, 7];
const days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

async function run() {
    let pool;
    try {
        pool = await poolPromise;

        // Fetch dummy users
        const usersRes = await pool.request().query("SELECT firebaseUid FROM Users WHERE email LIKE 'dummy%@spottr.com'");
        const users = usersRes.recordset;

        console.log(`Updating ${users.length} dummy users with full profile details for Discovery...`);

        for (const user of users) {
            const randomBio = bios[Math.floor(Math.random() * bios.length)];
            const randomGoal = goals[Math.floor(Math.random() * goals.length)];
            const randomAge = 20 + Math.floor(Math.random() * 20);
            const randomWeight = 50 + Math.floor(Math.random() * 50);
            const randomHeight = 150 + Math.floor(Math.random() * 40);
            const randomExp = experienceYears[Math.floor(Math.random() * experienceYears.length)];
            
            // Randomly select 3-5 days
            const shuffledDays = [...days].sort(() => 0.5 - Math.random());
            const randomAvail = shuffledDays.slice(0, 3 + Math.floor(Math.random() * 3));

            await pool.request()
                .input('uid', sql.NVARCHAR, user.firebaseUid)
                .input('bio', sql.NVARCHAR, randomBio)
                .input('looking_for', sql.NVARCHAR, randomGoal)
                .input('age', sql.INT, randomAge)
                .input('weight', sql.FLOAT, randomWeight)
                .input('height', sql.FLOAT, randomHeight)
                .input('experience', sql.INT, randomExp)
                .input('availability', sql.NVARCHAR, JSON.stringify(randomAvail))
                .query(`
                    UPDATE Users 
                    SET bio = @bio,
                        looking_for = @looking_for,
                        age = @age,
                        weight = @weight,
                        height = @height,
                        experience = @experience,
                        availability = @availability,
                        is_setup_completed = 1
                    WHERE firebaseUid = @uid
                `);
        }

        console.log('--- Successfully fixed all dummy users for Discovery! ---');

    } catch (err) {
        console.error('Error:', err);
    } finally {
        if (pool) process.exit();
    }
}

run();
