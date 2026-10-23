const { poolPromise, sql } = require('../config/db');
require('dotenv').config();

const fullProfiles = [
    {
        uid: 'BlJph660RecT8I35MkQGsQMusmD2', // Alex Johnson
        age: 26,
        gender: 'Male',
        weight: 85,
        weight_unit: 'kg',
        height: 180,
        bio: 'Passionate about starting a healthier lifestyle. Looking for a buddy to keep me accountable during morning sessions!',
        looking_for: 'Workout Buddy',
        fitness_goal: 'Weight Loss',
        training_level: 'Beginner',
        workout_location: 'Gym',
        equipment_list: 'Dumbbells, Barbells, Machines',
        focus_areas: 'Full Body, Cardio',
        workout_frequency: 3,
        experience: 1,
        preferences: JSON.stringify(['Cardio', 'Weightlifting']),
        availability: JSON.stringify(['Morning', 'Weekends']),
        latitude: 11.5564, // Phnom Penh area example
        longitude: 104.9282,
        location_label: 'Phnom Penh, Cambodia',
        is_setup_completed: 1
    },
    {
        uid: 'wZpm8xWqdhON6UzwIZY26c9Mbav1', // Jordan Smith
        age: 29,
        gender: 'Female',
        weight: 65,
        weight_unit: 'kg',
        height: 168,
        bio: 'Gym rat and protein shake enthusiast. I love heavy lifting and high-intensity interval training. Let’s crush some goals!',
        looking_for: 'Gym Partner',
        fitness_goal: 'Muscle Gain',
        training_level: 'Intermediate',
        workout_location: 'Gym',
        equipment_list: 'Full Gym Access',
        focus_areas: 'Back, Legs, Arms',
        workout_frequency: 5,
        experience: 4,
        preferences: JSON.stringify(['Crossfit', 'Powerlifting']),
        availability: JSON.stringify(['Evening', 'Weekdays']),
        latitude: 11.5621,
        longitude: 104.9108,
        location_label: 'Toul Kork, Phnom Penh',
        is_setup_completed: 1
    },
    {
        uid: 'rrWzUz8v8jNeFkBQjAv3GHEzKu63', // Casey Avery
        age: 32,
        gender: 'Non-binary',
        weight: 70,
        weight_unit: 'kg',
        height: 175,
        bio: 'Long-distance runner transitioning into more functional strength training. Balance and endurance are my focus.',
        looking_for: 'Running Partner',
        fitness_goal: 'Endurance',
        training_level: 'Advanced',
        workout_location: 'Outdoor',
        equipment_list: 'Running Shoes, Resistance Bands',
        focus_areas: 'Endurance, Core, Flexibility',
        workout_frequency: 6,
        experience: 8,
        preferences: JSON.stringify(['Yoga', 'Running', 'HIIT']),
        availability: JSON.stringify(['Early Morning', 'Weekdays', 'Weekends']),
        latitude: 11.5449,
        longitude: 104.8922,
        location_label: 'BKK1, Phnom Penh',
        is_setup_completed: 1
    }
];

async function populateProfiles() {
    let pool;
    try {
        pool = await poolPromise;
        console.log('--- Populating Full User Profiles Started ---');

        for (const profile of fullProfiles) {
            console.log(`Updating profile for user UID: ${profile.uid}...`);

            await pool.request()
                .input('uid', sql.NVARCHAR, profile.uid)
                .input('age', sql.INT, profile.age)
                .input('gender', sql.NVARCHAR, profile.gender)
                .input('weight', sql.FLOAT, profile.weight)
                .input('weight_unit', sql.NVARCHAR, profile.weight_unit)
                .input('height', sql.FLOAT, profile.height)
                .input('bio', sql.NVARCHAR, profile.bio)
                .input('looking_for', sql.NVARCHAR, profile.looking_for)
                .input('fitness_goal', sql.NVARCHAR, profile.fitness_goal)
                .input('training_level', sql.NVARCHAR, profile.training_level)
                .input('workout_location', sql.NVARCHAR, profile.workout_location)
                .input('equipment_list', sql.NVARCHAR, profile.equipment_list)
                .input('focus_areas', sql.NVARCHAR, profile.focus_areas)
                .input('workout_frequency', sql.INT, profile.workout_frequency)
                .input('experience', sql.INT, profile.experience)
                .input('preferences', sql.NVARCHAR, profile.preferences)
                .input('availability', sql.NVARCHAR, profile.availability)
                .input('latitude', sql.FLOAT, profile.latitude)
                .input('longitude', sql.FLOAT, profile.longitude)
                .input('location_label', sql.NVARCHAR, profile.location_label)
                .input('is_setup_completed', sql.BIT, profile.is_setup_completed)
                .query(`
                    UPDATE Users 
                    SET 
                        age = @age,
                        gender = @gender,
                        weight = @weight,
                        weight_unit = @weight_unit,
                        height = @height,
                        bio = @bio,
                        looking_for = @looking_for,
                        fitness_goal = @fitness_goal,
                        training_level = @training_level,
                        workout_location = @workout_location,
                        equipment_list = @equipment_list,
                        focus_areas = @focus_areas,
                        workout_frequency = @workout_frequency,
                        experience = @experience,
                        preferences = @preferences,
                        availability = @availability,
                        latitude = @latitude,
                        longitude = @longitude,
                        location_label = @location_label,
                        is_setup_completed = @is_setup_completed,
                        updatedAt = GETDATE()
                    WHERE firebaseUid = @uid
                `);

            console.log(`Successfully updated profile for user UID: ${profile.uid}.`);
        }

        console.log('--- All Test Profiles Populated Successfully ---');
    } catch (err) {
        console.error('Update Failed:', err);
    } finally {
        if (pool) {
            process.exit(0);
        }
    }
}

populateProfiles();
