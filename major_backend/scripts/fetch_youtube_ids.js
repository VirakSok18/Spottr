const fs = require('fs');
const youtubesearchapi = require('youtube-search-api');

const INPUT_JSON_PATH = 'd:\\Major 1\\major_frontend\\assets\\data\\exercises_v2.json';
const OUTPUT_JSON_PATH = 'd:\\Major 1\\major_frontend\\assets\\data\\exercises_v3.json';

// Delay helper to avoid rate limiting/blocking by YouTube
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));

async function fetchIds() {
    console.log('Starting YouTube Search...');

    if (!fs.existsSync(INPUT_JSON_PATH)) {
        console.error('Input JSON not found');
        return;
    }

    const exercises = JSON.parse(fs.readFileSync(INPUT_JSON_PATH, 'utf8'));
    const updatedExercises = [];
    let foundCount = 0;

    // We'll process in chunks to be safe, or just sequential with delay
    // Sequential is slower but safer for scraping
    for (let i = 0; i < exercises.length; i++) {
        const exercise = exercises[i];
        let youtubeId = null;

        try {
            const query = `${exercise.name} exercise tutorial`;

            // Search
            const result = await youtubesearchapi.GetListByKeyword(query, false, 1); // Get top 1

            if (result && result.items && result.items.length > 0) {
                youtubeId = result.items[0].id;
                foundCount++;
                console.log(`[${i + 1}/${exercises.length}] Found ID: ${youtubeId} for "${exercise.name}"`);
            } else {
                console.log(`[${i + 1}/${exercises.length}] No video found for "${exercise.name}"`);
            }

        } catch (error) {
            console.error(`[${i + 1}/${exercises.length}] Error processing "${exercise.name}":`, error.message);
        }

        updatedExercises.push({
            ...exercise,
            youtubeId: youtubeId
        });

        // Add a small delay between requests to be polite and avoid IP bans
        // 500ms delay
        await delay(500);

        // Save progress every 50 items
        if (i % 50 === 0) {
            fs.writeFileSync(OUTPUT_JSON_PATH, JSON.stringify(updatedExercises, null, 2));
        }
    }

    // Final save
    fs.writeFileSync(OUTPUT_JSON_PATH, JSON.stringify(updatedExercises, null, 2));

    console.log('---------------------------------------------------');
    console.log(`Search Complete.`);
    console.log(`Videos Found: ${foundCount}/${exercises.length}`);
    console.log(`Output saved to: ${OUTPUT_JSON_PATH}`);
}

fetchIds();
