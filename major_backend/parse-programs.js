const fs = require('fs');
const data = JSON.parse(fs.readFileSync('library_data.json', 'utf8'));

const programs = [];
let currentProgram = null;
let currentDay = null;

// Helper to check if a string is a day header
function isDayHeader(str) {
    if (!str) return false;
    const lower = str.toLowerCase().trim();
    // Common day patterns in this dataset
    const matches = [
        'day ', ' day', 'chest + back', 'shoulders + arms', 'legs', 'fat loss circuit',
        'upper', 'lower', 'chest', 'back', 'shoulder', 'arm', 'core', 'full body'
    ];

    // Exact matches or specific prefixes
    if (matches.some(m => lower.startsWith(m) || lower === m)) {
        // Exclude headers that are descriptions or table headers
        if (lower === '#' || lower === 'exercise' || lower.includes('difficulty:') || lower.includes('split') || lower.includes('program')) {
            return false;
        }
        return true;
    }
    return false;
}

data.forEach((row, index) => {
    const col1 = row.Column_1;
    const programName = row.Program;
    const difficulty = row.Difficulty;
    const equipment = row.Equipment;

    // Check for Program Header (Rows 0-9)
    if (index < 10 && col1 && programName) {
        programs.push({
            id: index + 1,
            title: programName,
            difficulty: difficulty,
            equipment: equipment,
            days: []
        });
        return;
    }

    // Check for Program Start in the list block
    if (col1 && col1.match(/^[1-9]️⃣|🔟/)) {
        const programIdStr = col1.split(' ')[0];
        const titlePart = col1.substring(programIdStr.length).trim();
        currentProgram = programs.find(p => titlePart.includes(p.title) || p.title.includes(titlePart));
        currentDay = null;
        return;
    }

    // Check for Day header
    if (currentProgram && col1 && isDayHeader(col1)) {
        currentDay = {
            title: col1,
            exercises: []
        };
        currentProgram.days.push(currentDay);
        return;
    }

    // Check for Exercises
    if (currentProgram && currentDay && col1 && !isNaN(parseInt(col1))) {
        currentDay.exercises.push({
            name: row.Program,
            youtubeUrl: row.Difficulty
        });
    }
});

// Helper to distribute days in a week
function getSchedule(numDays) {
    const schedule = [false, false, false, false, false, false, false]; // S M T W T F S
    if (numDays === 1) schedule[1] = true; // Monday
    else if (numDays === 2) { schedule[2] = true; schedule[4] = true; } // T, Th
    else if (numDays === 3) { schedule[1] = true; schedule[3] = true; schedule[5] = true; } // M, W, F
    else if (numDays === 4) { schedule[1] = true; schedule[2] = true; schedule[4] = true; schedule[5] = true; }
    else if (numDays === 5) { schedule[1] = true; schedule[2] = true; schedule[3] = true; schedule[4] = true; schedule[5] = true; }
    else if (numDays === 6) { schedule[1] = true; schedule[2] = true; schedule[3] = true; schedule[4] = true; schedule[5] = true; schedule[6] = true; }
    else if (numDays >= 7) return [true, true, true, true, true, true, true];
    return schedule;
}

// Post-process
programs.forEach(p => {
    p.days = p.days.filter(d => d.exercises.length > 0);
    p.schedule = getSchedule(p.days.length);
    // Find thumbnail from first video
    if (p.days.length > 0 && p.days[0].exercises.length > 0) {
        const url = p.days[0].exercises[0].youtubeUrl;
        if (url) {
            let videoId = '';
            if (url.includes('v=')) videoId = url.split('v=')[1].split('&')[0];
            else if (url.includes('youtu.be/')) videoId = url.split('youtu.be/')[1].split('?')[0];
            else if (url.includes('shorts/')) videoId = url.split('shorts/')[1].split('?')[0];

            p.thumbnail = `https://img.youtube.com/vi/${videoId}/hqdefault.jpg`;
        }
    }
});

fs.writeFileSync('parsed_programs.json', JSON.stringify(programs, null, 2));
console.log('Parsed programs saved to parsed_programs.json');
programs.forEach(p => {
    console.log(`${p.id}: ${p.title} - ${p.days.length} days - Thumbnail: ${p.thumbnail ? 'OK' : 'MISSING'}`);
});
