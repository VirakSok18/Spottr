const express = require('express');
const router = express.Router();
const { poolPromise, sql } = require('../config/db');
const authMiddleware = require('../middleware/auth');
const multer = require('multer');
const cloudinary = require('cloudinary').v2;
const streamifier = require('streamifier');
const admin = require('../config/firebase');
const { sendOTPEmail, sendVerificationEmail } = require('../services/emailService');
const crypto = require('crypto');

// Cloudinary Configuration
cloudinary.config({
    cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
    api_key: process.env.CLOUDINARY_API_KEY,
    api_secret: process.env.CLOUDINARY_API_SECRET
});

// --- Rate Limiting Helper ---
async function checkEmailRateLimit(email, limitType, maxCount = 3, windowHours = 1) {
    const pool = await poolPromise;
    const now = new Date();
    
    // Get existing record
    const result = await pool.request()
        .input('email', sql.NVARCHAR, email)
        .input('type', sql.NVARCHAR, limitType)
        .query('SELECT * FROM EmailRateLimits WHERE email = @email AND limitType = @type');

    let record = result.recordset[0];

    if (!record) {
        // Create first record - using GETUTCDATE to match Node's new Date() (UTC)
        await pool.request()
            .input('email', sql.NVARCHAR, email)
            .input('type', sql.NVARCHAR, limitType)
            .query('INSERT INTO EmailRateLimits (email, limitType, count, lastAttempt) VALUES (@email, @type, 1, GETUTCDATE())');
        return { allowed: true };
    }

    const lastAttempt = new Date(record.lastAttempt);
    // Node.js Date objects are always UTC based internally. 
    // Having GETUTCDATE in DB ensures exact match.
    const diffHours = (now - lastAttempt) / (1000 * 60 * 60);

    if (diffHours >= windowHours) {
        // Reset count after window passed
        await pool.request()
            .input('email', sql.NVARCHAR, email)
            .input('type', sql.NVARCHAR, limitType)
            .query('UPDATE EmailRateLimits SET count = 1, lastAttempt = GETUTCDATE() WHERE email = @email AND limitType = @type');
        return { allowed: true };
    }

    if (record.count >= maxCount) {
        const resetInMinutes = Math.ceil((windowHours - diffHours) * 60);
        return { allowed: false, resetInMinutes };
    }

    // Increment count
    await pool.request()
        .input('email', sql.NVARCHAR, email)
        .input('type', sql.NVARCHAR, limitType)
        .query('UPDATE EmailRateLimits SET count = count + 1, lastAttempt = GETUTCDATE() WHERE email = @email AND limitType = @type');
    
    return { allowed: true };
}

// Multer in-memory storage config
const storage = multer.memoryStorage();
const upload = multer({ storage: storage });

// Profile Picture Upload Endpoint
router.post('/profile/upload', authMiddleware, upload.single('profilePicture'), async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ error: 'No file uploaded' });
        }

        // Try to delete old profile picture first
        try {
            const pool = await poolPromise;
            const oldUser = await pool.request()
                .input('uid', sql.NVARCHAR, req.user.uid)
                .query('SELECT profilePictureUrl FROM Users WHERE firebaseUid = @uid');

            const oldUrl = oldUser.recordset[0]?.profilePictureUrl;
            if (oldUrl && oldUrl.includes('cloudinary')) {
                const parts = oldUrl.split('/');
                const fileName = parts[parts.length - 1];
                const publicId = `profile_pictures/${fileName.split('.')[0]}`;
                await cloudinary.uploader.destroy(publicId);
            }
        } catch (delErr) {
            console.warn('Old profile picture deletion failed (non-critical):', delErr);
        }

        const uploadStream = cloudinary.uploader.upload_stream(
            {
                folder: 'profile_pictures',
                public_id: `user_${req.user.uid}_${Date.now()}`,
                overwrite: true,
                resource_type: 'image'
            },
            async (error, result) => {
                if (error) {
                    console.error('Cloudinary Upload Error:', error);
                    return res.status(500).json({ error: 'Internal Server Error' });
                }

                // Update the user's profilePictureUrl in the database
                try {
                    const pool = await poolPromise;
                    await pool.request()
                        .input('uid', sql.NVARCHAR, req.user.uid)
                        .input('url', sql.NVARCHAR, result.secure_url)
                        .query('UPDATE Users SET profilePictureUrl = @url WHERE firebaseUid = @uid');

                    res.status(200).json({
                        message: 'Profile picture uploaded and updated successfully',
                        url: result.secure_url
                    });
                } catch (dbErr) {
                    console.error('Database Update Error:', dbErr);
                    res.status(500).json({ error: 'Internal Server Error' });
                }
            }
        );

        streamifier.createReadStream(req.file.buffer).pipe(uploadStream);
    } catch (err) {
        console.error('Upload Process Error:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// Cover Photo Upload Endpoint
router.post('/profile/cover/upload', authMiddleware, upload.single('coverPhoto'), async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ error: 'No file uploaded' });
        }

        // Try to delete old cover photo first
        try {
            const pool = await poolPromise;
            const oldUser = await pool.request()
                .input('uid', sql.NVARCHAR, req.user.uid)
                .query('SELECT coverPhotoUrl FROM Users WHERE firebaseUid = @uid');

            const oldUrl = oldUser.recordset[0]?.coverPhotoUrl;
            if (oldUrl && oldUrl.includes('cloudinary')) {
                const parts = oldUrl.split('/');
                const fileName = parts[parts.length - 1];
                const publicId = `cover_photos/${fileName.split('.')[0]}`;
                await cloudinary.uploader.destroy(publicId);
            }
        } catch (delErr) {
            console.warn('Old cover photo deletion failed (non-critical):', delErr);
        }

        const uploadStream = cloudinary.uploader.upload_stream(
            {
                folder: 'cover_photos',
                public_id: `cover_${req.user.uid}_${Date.now()}`,
                overwrite: true,
                resource_type: 'image'
            },
            async (error, result) => {
                if (error) {
                    console.error('Cloudinary Cover Upload Error:', error);
                    return res.status(500).json({ error: 'Internal Server Error' });
                }

                try {
                    const pool = await poolPromise;
                    await pool.request()
                        .input('uid', sql.NVARCHAR, req.user.uid)
                        .input('url', sql.NVARCHAR, result.secure_url)
                        .query('UPDATE Users SET coverPhotoUrl = @url WHERE firebaseUid = @uid');

                    res.status(200).json({
                        message: 'Cover photo uploaded and updated successfully',
                        url: result.secure_url
                    });
                } catch (dbErr) {
                    console.error('Database Update Error:', dbErr);
                    res.status(500).json({ error: 'Internal Server Error' });
                }
            }
        );

        streamifier.createReadStream(req.file.buffer).pipe(uploadStream);
    } catch (err) {
        console.error('Upload Process Error:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// Sync user from Firebase to MSSQL
// ... (Sync route remains the same, but let's ensure it exists)
router.post('/sync', authMiddleware, async (req, res) => {
    const { uid, email, name, phone_number } = req.user;
    const { fullName, phone } = req.body; // Allow optional manual override from frontend

    console.log('--- Sync Request Started ---');
    console.log('Firebase User:', { uid, email, name });
    console.log('Override Data:', { fullName, phone });

    try {
        const pool = await poolPromise;

        // Use provided info or fallback to firebase info
        const finalName = fullName || name || '';
        const finalPhone = phone || phone_number || '';

        console.log('Database Inputs:', { uid, finalName, email, finalPhone });

        // Upsert logic
        const result = await pool.request()
            .input('uid', sql.NVARCHAR, uid)
            .input('fullName', sql.NVARCHAR, finalName)
            .input('email', sql.NVARCHAR, email)
            .input('phone', sql.NVARCHAR, finalPhone)
            .query(`
                IF EXISTS(SELECT 1 FROM Users WHERE firebaseUid = @uid)
                BEGIN
                    UPDATE Users 
                    SET fullName = @fullName, email = @email, phone = @phone, updatedAt = GETDATE()
                    WHERE firebaseUid = @uid
                END
                ELSE IF EXISTS(SELECT 1 FROM Users WHERE email = @email)
                BEGIN
                    -- Email exists but UID is different (re-linking or new provider)
                    UPDATE Users 
                    SET firebaseUid = @uid, fullName = @fullName, phone = @phone, updatedAt = GETDATE()
                    WHERE email = @email
                END
                ELSE
                BEGIN
                    INSERT INTO Users(firebaseUid, fullName, email, phone)
                    VALUES(@uid, @fullName, @email, @phone)
                END
            `);

        console.log('Sync Database Query Completed');
        res.status(200).json({ message: 'User synced successfully' });
    } catch (err) {
        console.error('Database Sync Error:', err);
        res.status(500).json({ error: 'Internal Server Error', details: err.message });
    } finally {
        console.log('--- Sync Request Finished ---');
    }
});

// Get profile
router.get('/profile', authMiddleware, async (req, res) => {
    try {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('uid', sql.NVARCHAR, req.user.uid)
            .query('SELECT * FROM Users WHERE firebaseUid = @uid');

        if (result.recordset.length === 0) {
            return res.status(404).json({ error: 'User not found' });
        }

        res.status(200).json(result.recordset[0]);
    } catch (err) {
        console.error('Database Fetch Error:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// Get user profile by UID (for social features)
router.get('/profile/:uid', authMiddleware, async (req, res) => {
    try {
        const { uid } = req.params;
        const myUid = req.user.uid;
        const pool = await poolPromise;

        // Fetch target user and my own profile to calculate distance
        const result = await pool.request()
            .input('targetUid', sql.NVARCHAR, uid)
            .input('myUid', sql.NVARCHAR, myUid)
            .query('SELECT * FROM Users WHERE firebaseUid IN (@targetUid, @myUid)');

        if (result.recordset.length === 0) {
            return res.status(404).json({ error: 'User not found' });
        }

        const targetUser = result.recordset.find(u => u.firebaseUid === uid);
        const me = result.recordset.find(u => u.firebaseUid === myUid);

        if (!targetUser) {
            return res.status(404).json({ error: 'Target user not found' });
        }

        const profileData = { ...targetUser };

        // Calculate distance if both have location
        if (me && me.latitude && me.longitude && targetUser.latitude && targetUser.longitude) {
            profileData.distance_km = Math.round(calculateDistanceInKm(me.latitude, me.longitude, targetUser.latitude, targetUser.longitude));
        } else {
            profileData.distance_km = null;
        }

        res.status(200).json(profileData);
    } catch (err) {
        console.error('Database Fetch Error:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// Update profile (body data)
router.put('/profile', authMiddleware, async (req, res) => {
    console.log('Update Profile Request Body:', req.body); // Debug log
    const {
        fullName, phone, profilePictureUrl, coverPhotoUrl,
        gender, age, weight, weight_unit, height, fitness_goal,
        bio, looking_for, preferences, availability, availability_time_spans, experience,
        latitude, longitude, location_label, location_privacy, is_setup_completed
    } = req.body;
    const { uid } = req.user;

    try {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('uid', sql.NVARCHAR, uid)
            .input('fullName', sql.NVARCHAR, fullName)
            .input('phone', sql.NVARCHAR, phone)
            .input('profilePictureUrl', sql.NVARCHAR, profilePictureUrl)
            .input('coverPhotoUrl', sql.NVARCHAR, coverPhotoUrl)
            .input('gender', sql.NVARCHAR, gender)
            .input('age', sql.INT, age)
            .input('weight', sql.FLOAT, weight)
            .input('weight_unit', sql.NVARCHAR, weight_unit)
            .input('height', sql.FLOAT, height)
            .input('fitness_goal', sql.NVARCHAR, fitness_goal)
            .input('workout_location', sql.NVARCHAR, req.body.workout_location)
            .input('equipment_list', sql.NVARCHAR, req.body.equipment_list)
            .input('focus_areas', sql.NVARCHAR, req.body.focus_areas)
            .input('workout_frequency', sql.INT, req.body.workout_frequency)
            .input('training_level', sql.NVARCHAR, req.body.training_level)
            .input('experience', sql.INT, experience)
            .input('is_setup_completed', sql.BIT, is_setup_completed)
            .input('bio', sql.NVARCHAR, bio)
            .input('looking_for', sql.NVARCHAR, looking_for)
            .input('preferences', sql.NVARCHAR, Array.isArray(preferences) ? JSON.stringify(preferences) : preferences)
            .input('availability', sql.NVARCHAR, Array.isArray(availability) ? JSON.stringify(availability) : availability)
            .input('availability_time_spans', sql.NVARCHAR, (availability_time_spans && typeof availability_time_spans === 'object') ? JSON.stringify(availability_time_spans) : availability_time_spans)
            .input('latitude', sql.FLOAT, latitude === undefined ? null : latitude)
            .input('longitude', sql.FLOAT, longitude === undefined ? null : longitude)
            .input('has_latitude', sql.BIT, latitude === undefined ? 0 : 1)
            .input('has_longitude', sql.BIT, longitude === undefined ? 0 : 1)
            .input('location_label', sql.NVARCHAR, location_label)
            .input('location_privacy', sql.NVARCHAR, location_privacy)
            .input('saved_addresses', sql.NVARCHAR, Array.isArray(req.body.saved_addresses) ? JSON.stringify(req.body.saved_addresses) : req.body.saved_addresses)
            .query(`
                UPDATE Users 
                SET 
                fullName = COALESCE(@fullName, fullName),
                phone = COALESCE(@phone, phone),
                profilePictureUrl = COALESCE(@profilePictureUrl, profilePictureUrl),
                coverPhotoUrl = COALESCE(@coverPhotoUrl, coverPhotoUrl),
                gender = COALESCE(@gender, gender),
                age = COALESCE(@age, age),
                weight = COALESCE(@weight, weight),
                weight_unit = COALESCE(@weight_unit, weight_unit),
                height = COALESCE(@height, height),
                fitness_goal = COALESCE(@fitness_goal, fitness_goal),
                workout_location = COALESCE(@workout_location, workout_location),
                equipment_list = COALESCE(@equipment_list, equipment_list),
                focus_areas = COALESCE(@focus_areas, focus_areas),
                workout_frequency = COALESCE(@workout_frequency, workout_frequency),
                training_level = COALESCE(@training_level, training_level),
                experience = COALESCE(@experience, experience),
                is_setup_completed = COALESCE(@is_setup_completed, is_setup_completed),
                bio = COALESCE(@bio, bio),
                looking_for = COALESCE(@looking_for, looking_for),
                preferences = COALESCE(@preferences, preferences),
                availability = COALESCE(@availability, availability),
                availability_time_spans = COALESCE(@availability_time_spans, availability_time_spans),
                latitude = CASE WHEN @has_latitude = 1 THEN @latitude ELSE latitude END,
                longitude = CASE WHEN @has_longitude = 1 THEN @longitude ELSE longitude END,
                location_label = COALESCE(@location_label, location_label),
                location_privacy = COALESCE(@location_privacy, location_privacy),
                saved_addresses = COALESCE(@saved_addresses, saved_addresses),
                updatedAt = GETDATE()
                WHERE firebaseUid = @uid
                `);

        if (result.rowsAffected[0] === 0) {
            console.warn('Update Profile: User not found for update', uid);
            return res.status(404).json({ error: 'User not found' });
        }

        console.log('Profile updated successfully for:', uid);
        res.status(200).json({ message: 'Profile updated successfully' });
    } catch (err) {
        console.error('Database Update Error:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// Search users (for chat)
router.get('/search', authMiddleware, async (req, res) => {
    const { query } = req.query;
    const { uid } = req.user;
    if (!query || query.length < 1) return res.json([]);

    try {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('q', sql.NVARCHAR, `%${query}%`)
            .input('uid', sql.NVARCHAR, uid)
            .query(`
                SELECT TOP 10 firebaseUid, fullName, profilePictureUrl 
                FROM Users 
                WHERE (fullName LIKE @q OR email LIKE @q) 
                  AND firebaseUid != @uid
            `);
        res.json(result.recordset);
    } catch (err) {
        console.error('Search Users Error:', err);
        res.status(500).json({ error: 'Server error' });
    }
});

// Update FCM Token
router.post('/fcm-token', authMiddleware, async (req, res) => {
    const { fcmToken } = req.body;
    const { uid } = req.user;

    if (!fcmToken) {
        return res.status(400).json({ error: 'FCM Token is required' });
    }

    try {
        const pool = await poolPromise;
        await pool.request()
            .input('uid', sql.NVARCHAR, uid)
            .input('token', sql.NVARCHAR, fcmToken)
            .query('UPDATE Users SET fcmToken = @token WHERE firebaseUid = @uid');

        res.status(200).json({ message: 'FCM Token updated successfully' });
    } catch (err) {
        console.error('Error updating FCM Token:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// Matching Algorithm / Discovery
router.get('/matches', authMiddleware, async (req, res) => {
    const { uid } = req.user;
    console.log(`Discovery: User ${uid} is requesting matches...`);

    try {
        const pool = await poolPromise;

        // 1. Get current user's profile to compare
        const currentUserResult = await pool.request()
            .input('uid', sql.NVARCHAR, uid)
            .query('SELECT * FROM Users WHERE firebaseUid = @uid');

        if (currentUserResult.recordset.length === 0) {
            return res.status(404).json({ error: 'Current user not found' });
        }

        const me = currentUserResult.recordset[0];

        // 2. Fetch all potential matches
        // Filter: Not self, Setup completed, and ALL required fields for discovery filled
        const matchesResult = await pool.request()
            .input('uid', sql.NVARCHAR, uid)
            .query(`
                SELECT * FROM Users 
                WHERE firebaseUid != @uid 
                  AND is_setup_completed = 1
                  AND looking_for IS NOT NULL
                  AND bio IS NOT NULL
                  AND age IS NOT NULL
                  AND latitude IS NOT NULL
                  AND longitude IS NOT NULL
                  AND experience IS NOT NULL
                  AND height IS NOT NULL
                  AND weight IS NOT NULL
                  AND availability IS NOT NULL 
                  AND availability != '[]'
            `);

        console.log(`Discovery: Found ${matchesResult.recordset.length} raw candidates for user ${uid}`);

        let candidates = matchesResult.recordset;

        // 3. Apply Tiered Matching Algorithm
        let myPrefs = [];
        let myAvail = [];
        try {
            myPrefs = me.preferences ? (typeof me.preferences === 'string' ? JSON.parse(me.preferences) : me.preferences) : [];
            myAvail = me.availability ? (typeof me.availability === 'string' ? JSON.parse(me.availability) : me.availability) : [];
        } catch (e) {
            console.error('Discovery: Error parsing current user JSON fields:', e);
        }

        const scoredCandidates = candidates.map(user => {
            // Tiers: 
            // 1. Common Goals (Looking For, Training Level) & Proximity (Distance)
            // 2. Schedule / Availability
            // 3. Details (Frequency, Preferences)
            let score = 0;

            // --- TIER 1: PRIMARY (Common Goals & Location) ---

            // A. Looking For (Goal Alignment)
            if (user.looking_for && me.looking_for && user.looking_for.toLowerCase() === me.looking_for.toLowerCase()) {
                score += 1000;
            }

            // B. Training Level (Goal Alignment)
            if (user.training_level && me.training_level && user.training_level === me.training_level) {
                score += 300; // Increased priority as requested
            }

            // C. Proximity (Distance)
            let distance = null;
            if (me.latitude && me.longitude && user.latitude && user.longitude) {
                distance = calculateDistanceInKm(me.latitude, me.longitude, user.latitude, user.longitude);
                user.distance_km = Math.round(distance);

                // Closer = higher score. Max 500 points for being right next to each other.
                const proximityScore = Math.max(0, 500 - (distance * 5)); 
                score += proximityScore;
            } else {
                user.distance_km = null;
            }

            // --- TIER 2: SECONDARY (Availability / Schedule) ---
            try {
                const userAvail = user.availability ? (typeof user.availability === 'string' ? JSON.parse(user.availability) : user.availability) : [];
                const commonAvail = myAvail.filter(a => userAvail.includes(a));
                score += (commonAvail.length * 100); // Priority lower than Primary but higher than details
            } catch (e) {
                console.warn('Error parsing availability:', user.firebaseUid);
            }

            // --- TIER 3: TERTIARY (Activity Details) ---
            // Frequency overlap
            if (user.workout_frequency && me.workout_frequency) {
                if (Math.abs(user.workout_frequency - me.workout_frequency) <= 1) {
                    score += 50;
                }
            }

            // Shared Preferences
            try {
                const userPrefs = user.preferences ? (typeof user.preferences === 'string' ? JSON.parse(user.preferences) : user.preferences) : [];
                const commonPrefs = myPrefs.filter(p => userPrefs.includes(p));
                score += (commonPrefs.length * 15);
            } catch (e) {
                console.warn('Error parsing preferences:', user.firebaseUid);
            }

            user.match_score = score;
            return user;
        });

        // 4. Sort by score (descending)
        scoredCandidates.sort((a, b) => {
            // First sort by total match score
            if (b.match_score !== a.match_score) {
                return b.match_score - a.match_score;
            }
            // If scores are equal, fallback strictly to distance
            if (a.distance_km !== null && b.distance_km !== null) {
                return a.distance_km - b.distance_km;
            }
            return 0;
        });

        // 5. Sanitize and return
        const sanitizedMatches = scoredCandidates.map(u => ({
            firebaseUid: u.firebaseUid,
            fullName: u.fullName,
            profilePictureUrl: u.profilePictureUrl,
            coverPhotoUrl: u.coverPhotoUrl,
            age: u.age,
            bio: u.bio,
            looking_for: u.looking_for,
            distance_km: u.distance_km,
            gender: u.gender,
            experience: u.experience,
            height: u.height,
            weight: u.weight,
            training_level: u.training_level,
            workout_frequency: u.workout_frequency,
            location_label: u.location_label,
            location_privacy: u.location_privacy
        }));

        res.status(200).json(sanitizedMatches);
    } catch (err) {
        console.error('Tiered Matching Algorithm Error:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// Helper: Haversine formula for distance
function calculateDistanceInKm(lat1, lon1, lat2, lon2) {
    const R = 6371; // Radius of the earth in km
    const dLat = deg2rad(lat2 - lat1);
    const dLon = deg2rad(lon2 - lon1);
    const a =
        Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(deg2rad(lat1)) * Math.cos(deg2rad(lat2)) *
        Math.sin(dLon / 2) * Math.sin(dLon / 2)
        ;
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    const d = R * c; // Distance in km
    return d;
}

function deg2rad(deg) {
    return deg * (Math.PI / 180);
}

// --- Password Reset OTP Flow ---

// 1. Send OTP
router.post('/forgot-password', async (req, res) => {
    const { email } = req.body;
    if (!email) return res.status(400).json({ error: 'Email is required' });

    try {
        const pool = await poolPromise;

        // Rate Limit Check
        const rateCheck = await checkEmailRateLimit(email, 'forgot-password');
        if (!rateCheck.allowed) {
            return res.status(429).json({ 
                error: `Too many requests. Please try again in ${rateCheck.resetInMinutes} minutes.`,
                type: 'RATE_LIMIT_EXCEEDED'
            });
        }

        // check if user exists in Firebase or DB
        try {
            await admin.auth().getUserByEmail(email);
        } catch (authErr) {
            if (authErr.code === 'auth/user-not-found') {
                return res.status(404).json({ error: 'User with this email not found' });
            }
            throw authErr;
        }

        // Generate 6-digit OTP
        const otp = Math.floor(100000 + Math.random() * 900000).toString();
        const expiry = new Date(Date.now() + 15 * 60 * 1000);

        // Store OTP in DB (invalidate old ones)
        await pool.request()
            .input('email', sql.NVARCHAR, email)
            .input('code', sql.NVARCHAR, otp)
            .input('expiresAt', sql.DateTime, expiry)
            .query(`
                UPDATE PasswordResetOTPs SET isUsed = 1 WHERE email = @email AND isUsed = 0;
                INSERT INTO PasswordResetOTPs (email, code, expiresAt) VALUES (@email, @code, @expiresAt);
            `);

        // Send Email
        const emailResult = await sendOTPEmail(email, otp);
        if (!emailResult.success) {
            return res.status(500).json({ error: 'Failed to send reset email' });
        }

        res.status(200).json({ message: 'OTP sent successfully' });
    } catch (err) {
        console.error('Forgot Password Error:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// 2. Verify OTP
router.post('/verify-otp', async (req, res) => {
    const { email, code } = req.body;
    if (!email || !code) return res.status(400).json({ error: 'Email and code are required' });

    try {
        const pool = await poolPromise;

        // Rate Limit Check (Verification attempts)
        const rateCheck = await checkEmailRateLimit(email, 'verify-otp', 5, 0.25); // 5 attempts per 15 mins
        if (!rateCheck.allowed) {
            return res.status(429).json({ 
                error: `Too many verification attempts. Please try again in ${rateCheck.resetInMinutes} minutes.`,
                type: 'RATE_LIMIT_EXCEEDED'
            });
        }
        const result = await pool.request()
            .input('email', sql.NVARCHAR, email)
            .input('code', sql.NVARCHAR, code)
            .query(`
                SELECT TOP 1 * FROM PasswordResetOTPs 
                WHERE email = @email AND code = @code AND isUsed = 0 AND expiresAt > GETUTCDATE()
                ORDER BY createdAt DESC
            `);

        if (result.recordset.length === 0) {
            return res.status(400).json({ error: 'Invalid or expired code' });
        }

        res.status(200).json({ message: 'OTP verified' });
    } catch (err) {
        console.error('Verify OTP Error:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// 3. Reset Password
router.post('/reset-password', async (req, res) => {
    const { email, code, newPassword } = req.body;
    if (!email || !code || !newPassword) return res.status(400).json({ error: 'All fields are required' });

    try {
        const pool = await poolPromise;

        // Rate Limit Check (Reset attempts)
        const rateCheck = await checkEmailRateLimit(email, 'reset-password', 5, 0.25);
        if (!rateCheck.allowed) {
            return res.status(429).json({ 
                error: `Too many reset attempts. Please try again in ${rateCheck.resetInMinutes} minutes.`,
                type: 'RATE_LIMIT_EXCEEDED'
            });
        }

        // Double check OTP
        const otpCheck = await pool.request()
            .input('email', sql.NVARCHAR, email)
            .input('code', sql.NVARCHAR, code)
            .query(`
                SELECT TOP 1 * FROM PasswordResetOTPs 
                WHERE email = @email AND code = @code AND isUsed = 0 AND expiresAt > GETUTCDATE()
                ORDER BY createdAt DESC
            `);

        if (otpCheck.recordset.length === 0) {
            return res.status(400).json({ error: 'Invalid or expired code' });
        }

        // Update in Firebase
        const user = await admin.auth().getUserByEmail(email);
        await admin.auth().updateUser(user.uid, {
            password: newPassword
        });

        // Mark OTP as used
        await pool.request()
            .input('email', sql.NVARCHAR, email)
            .input('code', sql.NVARCHAR, code)
            .query('UPDATE PasswordResetOTPs SET isUsed = 1 WHERE email = @email AND code = @code');

        res.status(200).json({ message: 'Password reset successfully' });
    } catch (err) {
        console.error('Reset Password Error:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// --- Signup OTP Flow ---

// 1. Send OTP for Signup
router.post('/signup/send-otp', async (req, res) => {
    try {
        const { email } = req.body;
        if (!email) return res.status(400).json({ error: 'Email is required' });

        // Rate Limit Check
        const rateCheck = await checkEmailRateLimit(email, 'signup-otp');
        if (!rateCheck.allowed) {
            return res.status(429).json({ 
                error: `Too many requests. Please try again in ${rateCheck.resetInMinutes} minutes.`,
                type: 'RATE_LIMIT_EXCEEDED'
            });
        }

        // Generate 6-digit OTP
        const otp = Math.floor(100000 + Math.random() * 900000).toString();
        const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

        // Store OTP in DB (invalidate old ones for this email)
        const pool = await poolPromise;
        await pool.request()
            .input('email', sql.NVARCHAR, email)
            .input('code', sql.NVARCHAR, otp)
            .input('expiresAt', sql.DateTime, expiresAt)
            .query(`
                UPDATE SignupOTPs SET isUsed = 1 WHERE email = @email AND isUsed = 0;
                INSERT INTO SignupOTPs (email, code, expiresAt) VALUES (@email, @code, @expiresAt);
            `);

        const emailResult = await sendVerificationEmail(email, otp);
        if (!emailResult) {
            return res.status(500).json({ error: 'Failed to send verification email' });
        }

        res.status(200).json({ message: 'Verification OTP sent to your email' });
    } catch (err) {
        console.error('Send Signup OTP Error:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// 2. Verify OTP for Signup
router.post('/signup/verify-otp', async (req, res) => {
    try {
        const { email, code } = req.body;
        if (!email || !code) return res.status(400).json({ error: 'Email and code are required' });

        const pool = await poolPromise;

        // Rate Limit Check (Signup Verification attempts)
        const rateCheck = await checkEmailRateLimit(email, 'verify-signup-otp', 5, 0.25);
        if (!rateCheck.allowed) {
            return res.status(429).json({ 
                error: `Too many verification attempts. Please try again in ${rateCheck.resetInMinutes} minutes.`,
                type: 'RATE_LIMIT_EXCEEDED'
            });
        }
        const otpCheck = await pool.request()
            .input('email', sql.NVARCHAR, email)
            .input('code', sql.NVARCHAR, code)
            .query(`
                SELECT TOP 1 * FROM SignupOTPs 
                WHERE email = @email AND code = @code AND isUsed = 0 AND expiresAt > GETUTCDATE()
                ORDER BY createdAt DESC
            `);

        if (otpCheck.recordset.length === 0) {
            return res.status(400).json({ error: 'Invalid or expired verification code' });
        }

        // We DON'T mark as used here yet, because the actual account creation happens next.
        // Or we can mark as used and return a short-lived token? 
        // For simplicity, we just return success and the frontend proceeds.
        // Actually, to be safe, we should mark as used when the account is finally created.
        
        res.status(200).json({ message: 'Email verified successfully' });
    } catch (err) {
        console.error('Verify Signup OTP Error:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});


// Link Social Account — frictionless sign-in when same email already exists
// The client sends the Google idToken (or facebook accessToken + provider).
// We verify it, find the existing Firebase user by email, and return a custom token.
router.post('/link-social', async (req, res) => {
    const { idToken, provider } = req.body;

    if (!idToken || !provider) {
        return res.status(400).json({ error: 'idToken and provider are required' });
    }

    try {
        let email = null;

        if (provider === 'google') {
            // Verify Google ID token using Firebase Admin
            const decodedToken = await admin.auth().verifyIdToken(idToken);
            email = decodedToken.email;
        } else if (provider === 'facebook') {
            // Verify Facebook token by calling the Graph API
            const fbRes = await fetch(`https://graph.facebook.com/me?fields=email&access_token=${idToken}`);
            const fbData = await fbRes.json();
            if (fbData.error || !fbData.email) {
                return res.status(401).json({ error: 'Invalid Facebook token or no email on account' });
            }
            email = fbData.email;
        } else {
            return res.status(400).json({ error: 'Unsupported provider' });
        }

        if (!email) {
            return res.status(400).json({ error: 'Could not retrieve email from social provider' });
        }

        // Find the existing Firebase user by email
        let existingUser;
        try {
            existingUser = await admin.auth().getUserByEmail(email);
        } catch (e) {
            if (e.code === 'auth/user-not-found') {
                // No existing user — let the client create one normally
                return res.status(404).json({ error: 'No existing account found for this email' });
            }
            throw e;
        }

        // Issue a custom token for the existing user's UID
        const customToken = await admin.auth().createCustomToken(existingUser.uid);

        console.log(`link-social: Issued custom token for ${email} (uid: ${existingUser.uid}) via ${provider}`);
        res.status(200).json({ customToken });

    } catch (err) {
        console.error('link-social error:', err);
        res.status(500).json({ error: 'Internal Server Error', details: err.message });
    }
});

module.exports = router;

