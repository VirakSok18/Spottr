const { poolPromise, sql } = require('./config/db');

async function test() {
    try {
        const pool = await poolPromise;
        console.log('--- Verification: High-Entropy Plan Start Variety ---');

        const testUidResult = await pool.request().query('SELECT TOP 1 firebaseUid FROM Users');
        let testUid = testUidResult.recordset[0]?.firebaseUid;

        if (!testUid) {
            testUid = 'mock-uid-123';
            await pool.request().input('uid', sql.NVARCHAR, testUid).input('email', sql.NVARCHAR, 'test@example.com').query('INSERT INTO Users (firebaseUid, email, training_level, workout_frequency, fitness_goal) VALUES (@uid, @email, \'Beginner\', 3, \'Stay Active\')');
        }

        await pool.request()
            .input('uid', sql.NVARCHAR, testUid)
            .query(`
                UPDATE Users SET 
                focus_areas = '["Arm"]',
                equipment_list = '["Dumbbell", "Barbell", "Bodyweight", "Machine"]',
                workout_frequency = 3, 
                fitness_goal = 'Gain Muscle',
                training_level = 'Advanced'
                WHERE firebaseUid = @uid
            `);

        const workoutRoutes = require('./routes/workoutRoutes');
        const req = {
            user: { uid: testUid },
            query: { duration: 7 }
        };

        const res = {
            status: (code) => ({
                json: (data) => {
                    console.log(`\nFound ${data.length} Plans.`);
                    const firstExercises = data.map(plan => {
                        const day1 = plan.days.find(d => !d.isRestDay);
                        return day1 ? day1.exercises[0] : null;
                    });

                    firstExercises.forEach((ex, i) => {
                        if (ex) {
                            console.log(`Plan ${i + 1} First Exercise: ${ex.name} (Tier: ${ex.tier})`);
                        }
                    });

                    const names = firstExercises.map(ex => ex?.name).filter(Boolean);
                    const uniqueNames = new Set(names);

                    if (uniqueNames.size === names.length && names.length > 1) {
                        console.log('\n✅ Success: All suggested plans start with DIFFERENT exercises.');
                    } else if (names.length > 1) {
                        console.log('\n❌ Failure: Some plans start with the SAME exercise.');
                    }
                }
            })
        };

        const handler = workoutRoutes.stack.find(s => s.route && s.route.path === '/suggested-plans').route.stack[1].handle;
        await handler(req, res);

        process.exit(0);
    } catch (err) {
        console.error('Test Failed:', err);
        process.exit(1);
    }
}

test();
