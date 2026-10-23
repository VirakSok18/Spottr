const { poolPromise, sql } = require('./config/db');

async function audit() {
    try {
        const pool = await poolPromise;
        console.log('--- Deep Audit: Intra-Day Video Uniqueness ---');

        const testUidResult = await pool.request().query('SELECT TOP 1 firebaseUid FROM Users');
        let testUid = testUidResult.recordset[0]?.firebaseUid || 'mock-uid-123';

        const workoutRoutes = require('./routes/workoutRoutes');
        const req = {
            user: { uid: testUid },
            query: { duration: 7 }
        };

        const res = {
            status: (code) => res,
            json: (plans) => {
                plans.forEach((plan, pIdx) => {
                    console.log(`\nPlan ${pIdx + 1}: ${plan.title}`);
                    plan.days.forEach(day => {
                        if (day.isRestDay) return;

                        const videoUrls = day.exercises.map(ex => ex.videoUrl);
                        const uniqueVideos = new Set(videoUrls.filter(Boolean));

                        console.log(` Day ${day.day} (${day.routine}): ${day.exercises.length} exercises, ${uniqueVideos.size} unique videos`);

                        if (uniqueVideos.size < videoUrls.length) {
                            console.log(' ❌ ERROR: DUPLICATE VIDEOS FOUND IN DAY!');
                            const counts = {};
                            videoUrls.forEach(v => {
                                if (!v) return;
                                counts[v] = (counts[v] || 0) + 1;
                                if (counts[v] > 1) {
                                    const dupExercises = day.exercises.filter(ex => ex.videoUrl === v);
                                    console.log(`   Dup Video: ${v}`);
                                    dupExercises.forEach(ex => console.log(`     - ${ex.name} (ID: ${ex.id})`));
                                }
                            });
                        }
                    });
                });
            }
        };

        const handler = workoutRoutes.stack.find(s => s.route && s.route.path === '/suggested-plans').route.stack[1].handle;
        await handler(req, res);

        process.exit(0);
    } catch (err) {
        console.error('Audit Failed:', err);
        process.exit(1);
    }
}

audit();
