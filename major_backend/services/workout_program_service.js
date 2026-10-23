const { poolPromise } = require('../config/db');

class WorkoutProgramService {
    static async getStructuredPrograms() {
        const pool = await poolPromise;
        const tableName = '[Copy of Workout_Program_LibraryCSV]';

        const result = await pool.request().query(`SELECT * FROM ${tableName}`);
        const data = result.recordset;

        const programs = [];
        let currentProgram = null;
        let currentDay = null;

        const isDayHeader = (str) => {
            if (!str) return false;
            const lower = str.toLowerCase().trim();
            const matches = [
                'day ', ' day', 'chest + back', 'shoulders + arms', 'legs', 'fat loss circuit',
                'upper', 'lower', 'chest', 'back', 'shoulder', 'arm', 'core', 'full body'
            ];
            if (matches.some(m => lower.startsWith(m) || lower === m)) {
                if (lower === '#' || lower === 'exercise' || lower.includes('difficulty:') || lower.includes('split') || lower.includes('program')) {
                    return false;
                }
                return true;
            }
            return false;
        };

        const getSchedule = (numDays) => {
            const schedule = [false, false, false, false, false, false, false];
            if (numDays === 1) schedule[1] = true;
            else if (numDays === 2) { schedule[2] = true; schedule[4] = true; }
            else if (numDays === 3) { schedule[1] = true; schedule[3] = true; schedule[5] = true; }
            else if (numDays === 4) { schedule[1] = true; schedule[2] = true; schedule[4] = true; schedule[5] = true; }
            else if (numDays === 5) { schedule[1] = true; schedule[2] = true; schedule[3] = true; schedule[4] = true; schedule[5] = true; }
            else if (numDays === 6) { schedule[1] = true; schedule[2] = true; schedule[3] = true; schedule[4] = true; schedule[5] = true; schedule[6] = true; }
            else if (numDays >= 7) return [true, true, true, true, true, true, true];
            return schedule;
        };

        const getThumbnail = (url) => {
            if (!url) return null;
            let videoId = '';
            if (url.includes('v=')) videoId = url.split('v=')[1].split('&')[0];
            else if (url.includes('youtu.be/')) videoId = url.split('youtu.be/')[1].split('?')[0];
            else if (url.includes('shorts/')) videoId = url.split('shorts/')[1].split('?')[0];
            return videoId ? `https://img.youtube.com/vi/${videoId}/hqdefault.jpg` : null;
        };

        const _generateInstructions = (name) => {
            const n = name.toLowerCase();
            if (n.includes('push up') || n.includes('push-up')) return "Place hands shoulder-width apart, lower chest to floor, then push back up while keeping core tight.";
            if (n.includes('squat')) return "Feet shoulder-width apart, lower hips as if sitting in a chair, keep chest up and weight on heels.";
            if (n.includes('lunges') || n.includes('lunge')) return "Step forward and lower back knee until both legs are at 90 degrees. Keep torso upright.";
            if (n.includes('plank')) return "Hold a push-up position on forearms. Keep body in a straight line from head to heels, engaging core.";
            if (n.includes('crunch')) return "Lie on back, knees bent, lift shoulders off floor using abs. Don't pull on your neck.";
            if (n.includes('bicep curl')) return "Hold weights at sides, curl them toward shoulders while keeping elbows tucked at sides.";
            if (n.includes('shoulder press') || n.includes('overhead press')) return "Press weights from shoulders toward ceiling until arms are straight. Control the descent.";
            if (n.includes('row')) return "Pull weight toward your hip/torso, squeezing shoulder blades together. Keep back flat.";
            if (n.includes('deadlift')) return "Hinge at hips, keep back flat, lift weight by extending hips and knees. Keep bar close to body.";
            if (n.includes('bench press')) return "Lie on bench, lower bar to mid-chest, then press it back up to full extension.";
            if (n.includes('burpee')) return "Drop to floor, perform a push-up, jump feet in, and then jump up reaching for the ceiling.";
            if (n.includes('mountain climber')) return "In plank, drive knees toward chest alternately in a running motion. Keep hips low.";
            if (n.includes('leg raise')) return "Lie on back, lift legs to 90 degrees without bending knees. Lower slowly back to start.";
            if (n.includes('dips')) return "Lower body by bending elbows to 90 degrees, then push back up using triceps.";
            if (n.includes('pull up') || n.includes('pull-up')) return "Hang from bar, pull chest toward it by driving elbows down. Lower with control.";
            if (n.includes('lateral raise')) return "Raise arms out to sides until parallel with floor, slight bend in elbows. Controlled descent.";

            // Generic fallback based on common equipment or patterns
            if (n.includes('dumbbell')) return "Perform the movement smoothly with dumbbells, focusing on control and full range of motion.";
            if (n.includes('barbell')) return "Maintain a stable grip on the barbell and keep your core engaged throughout the lift.";
            if (n.includes('cable')) return "Use steady tension from the cables. Avoid using momentum to move the weight.";

            return "Focus on controlled movement, maintain proper form, and breathe steadily through each repetition.";
        };

        data.forEach((row, index) => {
            const col1 = row.Column_1;
            const programName = row.Program;

            if (index < 10 && col1 && programName) {
                programs.push({
                    id: index + 1,
                    title: programName,
                    difficulty: row.Difficulty,
                    equipment: row.Equipment,
                    days: []
                });
                return;
            }

            if (col1 && col1.match(/^[1-9]️⃣|🔟/)) {
                const programIdStr = col1.split(' ')[0];
                const titlePart = col1.substring(programIdStr.length).trim();
                currentProgram = programs.find(p => titlePart.includes(p.title) || p.title.includes(titlePart));
                currentDay = null;
                return;
            }

            if (currentProgram && col1 && isDayHeader(col1)) {
                currentDay = {
                    title: col1,
                    exercises: []
                };
                currentProgram.days.push(currentDay);
                return;
            }

            if (currentProgram && currentDay && col1 && !isNaN(parseInt(col1))) {
                currentDay.exercises.push({
                    name: row.Program,
                    youtubeUrl: row.Difficulty,
                    instructions: _generateInstructions(row.Program)
                });
            }
        });

        programs.forEach(p => {
            p.days = p.days.filter(d => d.exercises.length > 0);
            p.schedule = getSchedule(p.days.length);
            if (p.days.length > 0 && p.days[0].exercises.length > 0) {
                const useSecondThumbnail = [
                    'Bro Split – Dumbbell',
                    'Arnold Split – Dumbbell',
                    'Upper / Lower / Arms Split',
                    'Upper / Lower Split – Dumbbell'
                ].includes(p.title);

                if (useSecondThumbnail && p.days[0].exercises.length > 1) {
                    p.thumbnail = getThumbnail(p.days[0].exercises[1].youtubeUrl);
                } else {
                    p.thumbnail = getThumbnail(p.days[0].exercises[0].youtubeUrl);
                }
            }
        });

        return programs.filter(p => p.days.length > 0);
    }
}

module.exports = WorkoutProgramService;
