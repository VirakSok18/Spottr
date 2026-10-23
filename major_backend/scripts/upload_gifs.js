require('dotenv').config();
const cloudinary = require('cloudinary').v2;
const fs = require('fs');
const path = require('path');

// Configure Cloudinary
cloudinary.config({
    cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
    api_key: process.env.CLOUDINARY_API_KEY,
    api_secret: process.env.CLOUDINARY_API_SECRET
});

const EXERCISES_JSON_PATH = 'd:\\Major 1\\major_frontend\\assets\\data\\exercises.json';
const OUTPUT_JSON_PATH = 'd:\\Major 1\\major_frontend\\assets\\data\\exercises_v2.json';
const EXERCISES_CSV_PATH = 'd:\\Major 1\\exercises-gifs\\exercises.csv';
const GIFS_DIR = 'd:\\Major 1\\exercises-gifs\\assets';

function parseCSV(csvText) {
    const lines = csvText.split(/\r?\n/);
    const headers = lines[0].split(',');
    const idIndex = headers.indexOf('id');
    const nameIndex = headers.indexOf('name');

    const data = [];

    for (let i = 1; i < lines.length; i++) {
        const line = lines[i].trim();
        if (!line) continue;

        const matches = [];
        let inQuote = false;
        let currentField = '';

        for (let j = 0; j < line.length; j++) {
            const char = line[j];
            if (char === '"') {
                inQuote = !inQuote;
            } else if (char === ',' && !inQuote) {
                matches.push(currentField);
                currentField = '';
            } else {
                currentField += char;
            }
        }
        matches.push(currentField);

        if (matches.length > Math.max(idIndex, nameIndex)) {
            data.push({
                id: matches[idIndex],
                name: matches[nameIndex]
            });
        }
    }
    return data;
}

function normalize(str) {
    return str.toLowerCase().replace(/[^a-z0-9]/g, '');
}

async function uploadFile(filePath, publicId) {
    try {
        const result = await cloudinary.uploader.upload(filePath, {
            folder: 'exercises_gifs',
            public_id: publicId,
            resource_type: 'image',
            overwrite: true
        });
        return result.secure_url;
    } catch (error) {
        console.error(`Error uploading ${filePath}:`, error.message);
        return null;
    }
}

async function startMigration() {
    console.log('Starting Cloudinary Migration...');

    // Read input files
    if (!fs.existsSync(EXERCISES_JSON_PATH)) { console.error('JSON not found'); return; }
    if (!fs.existsSync(EXERCISES_CSV_PATH)) { console.error('CSV not found'); return; }

    const exercisesJson = JSON.parse(fs.readFileSync(EXERCISES_JSON_PATH, 'utf8'));
    const csvContent = fs.readFileSync(EXERCISES_CSV_PATH, 'utf8');
    const csvData = parseCSV(csvContent);

    // Map CSV names to IDs
    const nameToIdMap = new Map();
    csvData.forEach(item => {
        nameToIdMap.set(normalize(item.name), item.id);
    });

    let uploadedCount = 0;
    const updatedExercises = [];

    // Process exercises matched
    for (let i = 0; i < exercisesJson.length; i++) {
        const exercise = exercisesJson[i];
        const normName = normalize(exercise.name);
        let gifUrl = null;

        if (nameToIdMap.has(normName)) {
            const id = nameToIdMap.get(normName);
            const gifPath = path.join(GIFS_DIR, `${id}.gif`);

            if (fs.existsSync(gifPath)) {
                console.log(`[${i + 1}/${exercisesJson.length}] Uploading GIF for: ${exercise.name} (ID: ${id})`);
                const url = await uploadFile(gifPath, `ex_${id}`);
                if (url) {
                    gifUrl = url;
                    uploadedCount++;
                }
            }
        }

        // Create new exercise object
        updatedExercises.push({
            ...exercise,
            gifUrl: gifUrl // Add the new field (null if no GIF)
        });
    }

    // Write Output
    fs.writeFileSync(OUTPUT_JSON_PATH, JSON.stringify(updatedExercises, null, 2));
    console.log('---------------------------------------------------');
    console.log(`Migration Complete.`);
    console.log(`Total Uploaded: ${uploadedCount}`);
    console.log(`Output saved to: ${OUTPUT_JSON_PATH}`);
}

startMigration();
