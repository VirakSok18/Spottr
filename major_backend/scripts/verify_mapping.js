const fs = require('fs');
const path = require('path');

const EXERCISES_JSON_PATH = 'd:\\Major 1\\major_frontend\\assets\\data\\exercises.json';
const EXERCISES_CSV_PATH = 'd:\\Major 1\\exercises-gifs\\exercises.csv';
const GIFS_DIR = 'd:\\Major 1\\exercises-gifs\\assets';

function parseCSV(csvText) {
    const lines = csvText.split(/\r?\n/);
    const headers = lines[0].split(',');
    const idIndex = headers.indexOf('id');
    const nameIndex = headers.indexOf('name');

    const data = [];

    // Simple parser handling quoted fields specifically for this CSV structure
    // We assume standard CSV quoting: "field, with, commas"
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

async function verify() {
    if (!fs.existsSync(EXERCISES_JSON_PATH)) {
        console.error('Json file not found:', EXERCISES_JSON_PATH);
        return;
    }
    if (!fs.existsSync(EXERCISES_CSV_PATH)) {
        console.error('CSV file not found:', EXERCISES_CSV_PATH);
        return;
    }

    const exercisesJson = JSON.parse(fs.readFileSync(EXERCISES_JSON_PATH, 'utf8'));
    const csvContent = fs.readFileSync(EXERCISES_CSV_PATH, 'utf8');
    const csvData = parseCSV(csvContent);

    // Create map of normalized name -> ID
    const nameToIdMap = new Map();
    csvData.forEach(item => {
        nameToIdMap.set(normalize(item.name), item.id);
    });

    let mappedCount = 0;
    let missingGifCount = 0;
    let notFoundInCsvCount = 0;

    console.log(`Total exercises in JSON: ${exercisesJson.length}`);
    console.log(`Total exercises in CSV: ${csvData.length}`);

    exercisesJson.forEach(exercise => {
        const normName = normalize(exercise.name);
        if (nameToIdMap.has(normName)) {
            const id = nameToIdMap.get(normName);
            const gifPath = path.join(GIFS_DIR, `${id}.gif`);

            if (fs.existsSync(gifPath)) {
                mappedCount++;
            } else {
                // consolex.log(`GIF missing for: ${exercise.name} (ID: ${id})`);
                missingGifCount++;
            }
        } else {
            if (notFoundInCsvCount < 20) {
                console.log(`Not found in CSV: ${exercise.name} (Norm: ${normName})`);
            }
            notFoundInCsvCount++;
        }
    });

    console.log('---------------------------------------------------');
    console.log(`Successfully mapped and verified GIFs: ${mappedCount}`);
    console.log(`Matched CSV but missing GIF file: ${missingGifCount}`);
    console.log(`Failed to match name in CSV: ${notFoundInCsvCount}`);
    console.log(`Success Rate: ${((mappedCount / exercisesJson.length) * 100).toFixed(1)}%`);
}

verify();
