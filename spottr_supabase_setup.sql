-- =========================================================
-- SPOTTR COMPLETE SUPABASE SCHEMA & SEED SCRIPT
-- Run this script in your Supabase Dashboard -> SQL Editor
-- =========================================================

-- 1. USERS TABLE
CREATE TABLE IF NOT EXISTS public.users (
  id BIGSERIAL PRIMARY KEY,
  "firebaseUid" TEXT UNIQUE NOT NULL,
  "fullName" TEXT,
  email TEXT,
  phone TEXT,
  "createdAt" TIMESTAMPTZ DEFAULT NOW(),
  gender TEXT,
  age INT,
  weight FLOAT,
  height FLOAT,
  "updatedAt" TIMESTAMPTZ DEFAULT NOW(),
  workout_location TEXT,
  equipment_list TEXT,
  focus_areas TEXT,
  workout_frequency INT,
  training_level TEXT,
  is_setup_completed BOOLEAN DEFAULT TRUE,
  weight_unit TEXT DEFAULT 'kg',
  fitness_goal TEXT,
  "profilePictureUrl" TEXT,
  "coverPhotoUrl" TEXT,
  "isOnline" BOOLEAN DEFAULT FALSE,
  "lastActive" TIMESTAMPTZ,
  "fcmToken" TEXT,
  bio TEXT,
  looking_for TEXT,
  preferences TEXT,
  availability TEXT,
  experience INT DEFAULT 1,
  latitude FLOAT,
  longitude FLOAT,
  location_label TEXT,
  location_privacy TEXT DEFAULT 'public',
  is_location_paused BOOLEAN DEFAULT FALSE,
  saved_addresses TEXT,
  availability_time_spans TEXT,
  "isPremium" BOOLEAN DEFAULT TRUE,
  "planType" TEXT DEFAULT 'free_pro'
);

-- 2. POSTS TABLE
CREATE TABLE IF NOT EXISTS public.posts (
  id BIGSERIAL PRIMARY KEY,
  "userUid" TEXT NOT NULL,
  content TEXT,
  "mediaUrl" TEXT,
  "mediaType" TEXT,
  "createdAt" TIMESTAMPTZ DEFAULT NOW()
);

-- 3. POST MEDIA TABLE
CREATE TABLE IF NOT EXISTS public.post_media (
  id BIGSERIAL PRIMARY KEY,
  "postId" BIGINT REFERENCES public.posts(id) ON DELETE CASCADE,
  "mediaUrl" TEXT NOT NULL,
  "mediaType" TEXT DEFAULT 'image',
  "createdAt" TIMESTAMPTZ DEFAULT NOW()
);

-- 4. LIKES TABLE
CREATE TABLE IF NOT EXISTS public.likes (
  id BIGSERIAL PRIMARY KEY,
  "postId" BIGINT REFERENCES public.posts(id) ON DELETE CASCADE,
  "userUid" TEXT NOT NULL,
  "createdAt" TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE("postId", "userUid")
);

-- 5. COMMENTS TABLE
CREATE TABLE IF NOT EXISTS public.comments (
  id BIGSERIAL PRIMARY KEY,
  "postId" BIGINT REFERENCES public.posts(id) ON DELETE CASCADE,
  "userUid" TEXT NOT NULL,
  content TEXT NOT NULL,
  "createdAt" TIMESTAMPTZ DEFAULT NOW(),
  "parentCommentId" BIGINT
);

-- 6. SAVED POSTS TABLE
CREATE TABLE IF NOT EXISTS public.saved_posts (
  id BIGSERIAL PRIMARY KEY,
  "postId" BIGINT REFERENCES public.posts(id) ON DELETE CASCADE,
  "userUid" TEXT NOT NULL,
  "createdAt" TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE("postId", "userUid")
);

-- 7. MESSAGES TABLE
CREATE TABLE IF NOT EXISTS public.messages (
  id BIGSERIAL PRIMARY KEY,
  "senderUid" TEXT NOT NULL,
  "receiverUid" TEXT NOT NULL,
  content TEXT,
  "isRead" BOOLEAN DEFAULT FALSE,
  "createdAt" TIMESTAMPTZ DEFAULT NOW(),
  "mediaUrl" TEXT,
  "mediaType" TEXT,
  "parentId" BIGINT,
  "parentContent" TEXT,
  "parentMediaType" TEXT
);

-- 8. CHAT REQUESTS TABLE
CREATE TABLE IF NOT EXISTS public.chat_requests (
  id BIGSERIAL PRIMARY KEY,
  "senderUid" TEXT NOT NULL,
  "receiverUid" TEXT NOT NULL,
  status TEXT DEFAULT 'pending',
  "createdAt" TIMESTAMPTZ DEFAULT NOW(),
  "updatedAt" TIMESTAMPTZ DEFAULT NOW()
);

-- 9. BLOCKS TABLE
CREATE TABLE IF NOT EXISTS public.blocks (
  id BIGSERIAL PRIMARY KEY,
  "blockerUid" TEXT NOT NULL,
  "blockedUid" TEXT NOT NULL,
  "createdAt" TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE("blockerUid", "blockedUid")
);

-- 10. NOTIFICATIONS TABLE
CREATE TABLE IF NOT EXISTS public.notifications (
  id BIGSERIAL PRIMARY KEY,
  "recipientUid" TEXT NOT NULL,
  "senderUid" TEXT,
  type TEXT NOT NULL,
  title TEXT,
  message TEXT,
  "referenceId" TEXT,
  "isRead" BOOLEAN DEFAULT FALSE,
  "createdAt" TIMESTAMPTZ DEFAULT NOW()
);

-- 11. USER WORKOUT PLANS TABLE
CREATE TABLE IF NOT EXISTS public.user_plans (
  id BIGSERIAL PRIMARY KEY,
  "userUid" TEXT NOT NULL,
  "planData" TEXT,
  "isAI" BOOLEAN DEFAULT FALSE,
  "createdAt" TIMESTAMPTZ DEFAULT NOW()
);

-- 12. WORKOUT PROGRESS TABLE
CREATE TABLE IF NOT EXISTS public.workout_day_progress (
  id BIGSERIAL PRIMARY KEY,
  "firebaseUid" TEXT NOT NULL,
  "planTitle" TEXT NOT NULL,
  "dayNumber" INT NOT NULL,
  "completedAt" TIMESTAMPTZ DEFAULT NOW()
);

-- 13. ENABLE REALTIME
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;

-- 14. FEED VIEW WITH USER INFO & COUNTS
CREATE OR REPLACE VIEW public.feed_posts_view AS
SELECT 
    p.id,
    p."userUid",
    p.content,
    p."mediaUrl",
    p."mediaType",
    p."createdAt",
    u."fullName" AS "userName",
    u."profilePictureUrl" AS "userAvatar",
    u."coverPhotoUrl" AS "userCover",
    (SELECT COUNT(*) FROM public.likes l WHERE l."postId" = p.id)::int AS "likesCount",
    (SELECT COUNT(*) FROM public.comments c WHERE c."postId" = p.id)::int AS "commentsCount",
    COALESCE((
      SELECT json_agg(json_build_object('url', pm."mediaUrl", 'type', pm."mediaType"))
      FROM public.post_media pm
      WHERE pm."postId" = p.id
    ), '[]'::json) AS media
FROM public.posts p
LEFT JOIN public.users u ON p."userUid" = u."firebaseUid"
ORDER BY p."createdAt" DESC;

-- 15. ROW LEVEL SECURITY (RLS) POLICIES
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_media ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.saved_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_day_progress ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public read on users" ON public.users;
CREATE POLICY "Allow public read on users" ON public.users FOR SELECT USING (true);
DROP POLICY IF EXISTS "Allow all write on users" ON public.users;
CREATE POLICY "Allow all write on users" ON public.users FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public read on posts" ON public.posts;
CREATE POLICY "Allow public read on posts" ON public.posts FOR SELECT USING (true);
DROP POLICY IF EXISTS "Allow all write on posts" ON public.posts;
CREATE POLICY "Allow all write on posts" ON public.posts FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public read on post_media" ON public.post_media;
CREATE POLICY "Allow public read on post_media" ON public.post_media FOR SELECT USING (true);
DROP POLICY IF EXISTS "Allow all write on post_media" ON public.post_media;
CREATE POLICY "Allow all write on post_media" ON public.post_media FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public read on likes" ON public.likes;
CREATE POLICY "Allow public read on likes" ON public.likes FOR SELECT USING (true);
DROP POLICY IF EXISTS "Allow all write on likes" ON public.likes;
CREATE POLICY "Allow all write on likes" ON public.likes FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public read on comments" ON public.comments;
CREATE POLICY "Allow public read on comments" ON public.comments FOR SELECT USING (true);
DROP POLICY IF EXISTS "Allow all write on comments" ON public.comments;
CREATE POLICY "Allow all write on comments" ON public.comments FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public read on saved_posts" ON public.saved_posts;
CREATE POLICY "Allow public read on saved_posts" ON public.saved_posts FOR SELECT USING (true);
DROP POLICY IF EXISTS "Allow all write on saved_posts" ON public.saved_posts;
CREATE POLICY "Allow all write on saved_posts" ON public.saved_posts FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public read on messages" ON public.messages;
CREATE POLICY "Allow public read on messages" ON public.messages FOR SELECT USING (true);
DROP POLICY IF EXISTS "Allow all write on messages" ON public.messages;
CREATE POLICY "Allow all write on messages" ON public.messages FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public read on chat_requests" ON public.chat_requests;
CREATE POLICY "Allow public read on chat_requests" ON public.chat_requests FOR SELECT USING (true);
DROP POLICY IF EXISTS "Allow all write on chat_requests" ON public.chat_requests;
CREATE POLICY "Allow all write on chat_requests" ON public.chat_requests FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public read on blocks" ON public.blocks;
CREATE POLICY "Allow public read on blocks" ON public.blocks FOR SELECT USING (true);
DROP POLICY IF EXISTS "Allow all write on blocks" ON public.blocks;
CREATE POLICY "Allow all write on blocks" ON public.blocks FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public read on notifications" ON public.notifications;
CREATE POLICY "Allow public read on notifications" ON public.notifications FOR SELECT USING (true);
DROP POLICY IF EXISTS "Allow all write on notifications" ON public.notifications;
CREATE POLICY "Allow all write on notifications" ON public.notifications FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public read on user_plans" ON public.user_plans;
CREATE POLICY "Allow public read on user_plans" ON public.user_plans FOR SELECT USING (true);
DROP POLICY IF EXISTS "Allow all write on user_plans" ON public.user_plans;
CREATE POLICY "Allow all write on user_plans" ON public.user_plans FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public read on workout_day_progress" ON public.workout_day_progress;
CREATE POLICY "Allow public read on workout_day_progress" ON public.workout_day_progress FOR SELECT USING (true);
DROP POLICY IF EXISTS "Allow all write on workout_day_progress" ON public.workout_day_progress;
CREATE POLICY "Allow all write on workout_day_progress" ON public.workout_day_progress FOR ALL USING (true) WITH CHECK (true);

-- 16. STORAGE BUCKETS FOR MEDIA UPLOADS
INSERT INTO storage.buckets (id, name, public) VALUES ('avatars', 'avatars', true) ON CONFLICT (id) DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('posts', 'posts', true) ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Public Access avatars" ON storage.objects;
CREATE POLICY "Public Access avatars" ON storage.objects FOR SELECT USING (bucket_id = 'avatars');
DROP POLICY IF EXISTS "Public Upload avatars" ON storage.objects;
CREATE POLICY "Public Upload avatars" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'avatars');
DROP POLICY IF EXISTS "Public Access posts" ON storage.objects;
CREATE POLICY "Public Access posts" ON storage.objects FOR SELECT USING (bucket_id = 'posts');
DROP POLICY IF EXISTS "Public Upload posts" ON storage.objects;
CREATE POLICY "Public Upload posts" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'posts');

-- =========================================================
-- SEED DATA (22 Users, 25 Posts, 35 Media items)
-- =========================================================

INSERT INTO public.users ("firebaseUid", "fullName", email, gender, age, weight, height, workout_location, equipment_list, focus_areas, workout_frequency, training_level, is_setup_completed, weight_unit, fitness_goal, "profilePictureUrl", "coverPhotoUrl", "isOnline", bio, looking_for, latitude, longitude, location_label, "isPremium")
VALUES ('Hi3Rybe6ryVFm4LypojQr2qM9Vn2', 'Alex Smith', 'dummy1@spottr.com', 'Prefer not to say', 31, 78, 161, 'Home', '["Kettlebells","Resistance Bands","Barbell","Dumbbells","Bench"]', '["Legs","Back"]', 3, 'Beginner', TRUE, 'kg', 'Strength', 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773807629/profile_pics/sqooznna8wtcnuqjp2r4.jpg', 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773816794/dummy_covers/3d3364e50260be1b67213d4dc339ddff_mvxbuj.jpg', FALSE, 'Strength training is my passion. PB hunting! 🏆', 'Yoga Friend', 11.533495006865413, 104.90203150546134, 'Phnom Penh, Cambodia', TRUE)
ON CONFLICT ("firebaseUid") DO NOTHING;

INSERT INTO public.users ("firebaseUid", "fullName", email, gender, age, weight, height, workout_location, equipment_list, focus_areas, workout_frequency, training_level, is_setup_completed, weight_unit, fitness_goal, "profilePictureUrl", "coverPhotoUrl", "isOnline", bio, looking_for, latitude, longitude, location_label, "isPremium")
VALUES ('U4QdkEbUWiMaqAhE0kOgPv2tUR02', 'Jordan Johnson', 'dummy2@spottr.com', 'Prefer not to say', 36, 69, 174, 'Home', '["Resistance Bands","Treadmill","Kettlebells","Bench","Barbell","Squat Rack"]', '["Chest","Legs","Full Body","Core"]', 4, 'Beginner', TRUE, 'kg', 'Bodybuilding', 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773807636/profile_pics/werm9yxzbaq4qiw5nogq.jpg', 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773816795/dummy_covers/12e2c6eac85eb312e394755d150fae9a_xefepj.jpg', FALSE, 'Fitness enthusiast. Love lifting and healthy living! 💪', 'Yoga Friend', 11.513563859215363, 104.87040112747141, 'Phnom Penh, Cambodia', TRUE)
ON CONFLICT ("firebaseUid") DO NOTHING;

INSERT INTO public.users ("firebaseUid", "fullName", email, gender, age, weight, height, workout_location, equipment_list, focus_areas, workout_frequency, training_level, is_setup_completed, weight_unit, fitness_goal, "profilePictureUrl", "coverPhotoUrl", "isOnline", bio, looking_for, latitude, longitude, location_label, "isPremium")
VALUES ('yelWAekr9OciERN80fVEi7dwQUe2', 'Casey Williams', 'dummy3@spottr.com', 'Prefer not to say', 33, 69, 157, 'Gym', '["Kettlebells","Resistance Bands","Squat Rack","Pull-up Bar","Barbell","Treadmill"]', '["Core","Back","Shoulders"]', 3, 'Beginner', TRUE, 'kg', 'Endurance', 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773807640/profile_pics/sqihwtcvsmmo600ugakh.jpg', 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773816797/dummy_covers/pexels-nadin-sh-78971847-36555145_sn57ae.jpg', FALSE, 'Lover of HIIT and strength training. Grinding never stops! 🔥', 'Running Partner', 11.603779583596156, 104.88451709850895, 'Phnom Penh, Cambodia', TRUE)
ON CONFLICT ("firebaseUid") DO NOTHING;

INSERT INTO public.users ("firebaseUid", "fullName", email, gender, age, weight, height, workout_location, equipment_list, focus_areas, workout_frequency, training_level, is_setup_completed, weight_unit, fitness_goal, "profilePictureUrl", "coverPhotoUrl", "isOnline", bio, looking_for, latitude, longitude, location_label, "isPremium")
VALUES ('p10z489UZYU1AVwpnEVjlfRGJkR2', 'Taylor Brown', 'dummy4@spottr.com', 'Prefer not to say', 28, 59, 182, 'Gym', '["Kettlebells","Resistance Bands","Bench","Pull-up Bar"]', '["Arms","Legs","Core","Chest"]', 3, 'Beginner', TRUE, 'kg', 'Flexibility', 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773807643/profile_pics/gww9k90u39k2dg1gpgq7.jpg', 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773816798/dummy_covers/d42dbc581da8fa4b7427921cd8513d17_p3l5mq.jpg', FALSE, 'Lover of HIIT and strength training. Grinding never stops! 🔥', 'Sports Partner', 11.58244059100669, 104.91216265210068, 'Phnom Penh, Cambodia', TRUE)
ON CONFLICT ("firebaseUid") DO NOTHING;

INSERT INTO public.users ("firebaseUid", "fullName", email, gender, age, weight, height, workout_location, equipment_list, focus_areas, workout_frequency, training_level, is_setup_completed, weight_unit, fitness_goal, "profilePictureUrl", "coverPhotoUrl", "isOnline", bio, looking_for, latitude, longitude, location_label, "isPremium")
VALUES ('Q1xXEPbXmYY4HCv5zty2iOPUZnK2', 'Morgan Jones', 'dummy5@spottr.com', 'Female', 19, 94, 164, 'Gym', '["Pull-up Bar","Resistance Bands","Barbell","Dumbbells","Treadmill","Kettlebells"]', '["Core","Back","Arms"]', 6, 'Beginner', TRUE, 'kg', 'Flexibility', 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773807648/profile_pics/jsuz5iqyes1ncjgaexmx.jpg', 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773816800/dummy_covers/pexels-koolshooters-8520628_sowzck.jpg', FALSE, 'Yoga and functional training enthusiast. Movement is life! 🧘‍♂️', 'Gym Motivation', 11.556685689162434, 104.92784278253345, 'Phnom Penh, Cambodia', TRUE)
ON CONFLICT ("firebaseUid") DO NOTHING;

INSERT INTO public.users ("firebaseUid", "fullName", email, gender, age, weight, height, workout_location, equipment_list, focus_areas, workout_frequency, training_level, is_setup_completed, weight_unit, fitness_goal, "profilePictureUrl", "coverPhotoUrl", "isOnline", bio, looking_for, latitude, longitude, location_label, "isPremium")
VALUES ('VcNMjINAllPzZMYZ7gk9Xm3cVHE3', 'Sam Garcia', 'dummy6@spottr.com', 'Prefer not to say', 21, 92, 161, 'Hybrid', '["Bench","Kettlebells","Resistance Bands","Barbell","Dumbbells","Squat Rack"]', '["Core","Full Body"]', 6, 'Elite', TRUE, 'kg', 'Endurance', 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773807654/profile_pics/csbqjqinkhc8vactvgjv.jpg', 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773816801/dummy_covers/pexels-pixabay-39671_c51sod.jpg', FALSE, 'Casual gym goer. Let''s stay active and healthy.', 'Gym Motivation', 11.558235206260392, 104.8843262202249, 'Phnom Penh, Cambodia', TRUE)
ON CONFLICT ("firebaseUid") DO NOTHING;

INSERT INTO public.users ("firebaseUid", "fullName", email, gender, age, weight, height, workout_location, equipment_list, focus_areas, workout_frequency, training_level, is_setup_completed, weight_unit, fitness_goal, "profilePictureUrl", "coverPhotoUrl", "isOnline", bio, looking_for, latitude, longitude, location_label, "isPremium")
VALUES ('WhXdUnhxOXa8eVvrY6jX9f1jjpJ3', 'Riley Miller', 'dummy7@spottr.com', 'Female', 30, 89, 186, 'Outdoor', '["Dumbbells","Treadmill","Resistance Bands","Pull-up Bar","Kettlebells"]', '["Back","Arms","Core","Shoulders"]', 6, 'Elite', TRUE, 'kg', 'Endurance', 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773807659/profile_pics/ercsj5h1zgsenokr4frt.jpg', 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773816802/dummy_covers/e1386d7c1d2d2f998b23b1b8d77d343b_hwyv6v.jpg', FALSE, 'Crossfit lover and enthusiast. Hard work pays off.', 'Running Partner', 11.544109613933143, 104.88744327508262, 'Phnom Penh, Cambodia', TRUE)
ON CONFLICT ("firebaseUid") DO NOTHING;

INSERT INTO public.users ("firebaseUid", "fullName", email, gender, age, weight, height, workout_location, equipment_list, focus_areas, workout_frequency, training_level, is_setup_completed, weight_unit, fitness_goal, "profilePictureUrl", "coverPhotoUrl", "isOnline", bio, looking_for, latitude, longitude, location_label, "isPremium")
VALUES ('YAzWzdXZtgQQSXvk0RTFyjcn7ze2', 'Avery Davis', 'dummy8@spottr.com', 'Prefer not to say', 19, 86, 172, 'Home', '["Kettlebells","Resistance Bands","Squat Rack","Bench","Pull-up Bar"]', '["Back","Arms","Full Body","Core"]', 3, 'Intermediate', TRUE, 'kg', 'General Fitness', 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773807663/profile_pics/nsl7gqycugvujc65pgdh.jpg', 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773816803/dummy_covers/1ce259cdd0779c3b00ff40c1220783fe_cwzp8o.jpg', FALSE, 'Casual gym goer. Let''s stay active and healthy.', 'Sports Partner', 11.516900384275775, 104.9381858919786, 'Phnom Penh, Cambodia', TRUE)
ON CONFLICT ("firebaseUid") DO NOTHING;

INSERT INTO public.users ("firebaseUid", "fullName", email, gender, age, weight, height, workout_location, equipment_list, focus_areas, workout_frequency, training_level, is_setup_completed, weight_unit, fitness_goal, "profilePictureUrl", "coverPhotoUrl", "isOnline", bio, looking_for, latitude, longitude, location_label, "isPremium")
VALUES ('a0uSf9dcyoRhLyicvqYwM5velqv2', 'Parker Rodriguez', 'dummy9@spottr.com', 'Prefer not to say', 35, 76, 170, 'Outdoor', '["Bench","Resistance Bands","Pull-up Bar","Treadmill","Barbell"]', '["Back","Chest","Full Body","Legs"]', 5, 'Intermediate', TRUE, 'kg', 'General Fitness', 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773807667/profile_pics/msu7he9godssfv5xhfb8.jpg', 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773816804/dummy_covers/pexels-pixabay-260352_bqahjh.jpg', FALSE, 'Fitness enthusiast. Love lifting and healthy living! 💪', 'Sports Partner', 11.593910026146759, 104.87917590810912, 'Phnom Penh, Cambodia', TRUE)
ON CONFLICT ("firebaseUid") DO NOTHING;

INSERT INTO public.users ("firebaseUid", "fullName", email, gender, age, weight, height, workout_location, equipment_list, focus_areas, workout_frequency, training_level, is_setup_completed, weight_unit, fitness_goal, "profilePictureUrl", "coverPhotoUrl", "isOnline", bio, looking_for, latitude, longitude, location_label, "isPremium")
VALUES ('GS81b4fFm8ZOyJoqiJ10v2n5x7t2', 'Quinn Martinez', 'dummy10@spottr.com', 'Male', 22, 87, 180, 'Outdoor', '["Pull-up Bar","Barbell","Kettlebells","Resistance Bands","Dumbbells","Bench"]', '["Legs","Back","Core","Shoulders"]', 5, 'Advanced', TRUE, 'kg', 'Muscle Gain', 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773807672/profile_pics/cojwscd5bxjhfbylyfgv.jpg', 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773816805/dummy_covers/pexels-lum3n-44775-1410235_olxvlq.jpg', FALSE, 'Getting back into fitness. Beginner-friendly vibes only!', 'Workout Buddy', 11.591420862696149, 104.93282799168072, 'Phnom Penh, Cambodia', TRUE)
ON CONFLICT ("firebaseUid") DO NOTHING;

INSERT INTO public.users ("firebaseUid", "fullName", email, gender, age, weight, height, workout_location, equipment_list, focus_areas, workout_frequency, training_level, is_setup_completed, weight_unit, fitness_goal, "profilePictureUrl", "coverPhotoUrl", "isOnline", bio, looking_for, latitude, longitude, location_label, "isPremium")
VALUES ('iQRptZdDhNOwd0TfjXCiLvEjvmB3', 'Blake Hernandez', 'dummy11@spottr.com', 'Female', 23, 85, 188, 'Gym', '["Bench","Pull-up Bar","Dumbbells"]', '["Chest","Back","Shoulders"]', 4, 'Beginner', TRUE, 'kg', 'Flexibility', 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773807676/profile_pics/dt5clwegoddi8zlalkmz.jpg', 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773816806/dummy_covers/c81cab4ad349f9a087cad06f51b82e92_smvghh.jpg', FALSE, 'Casual gym goer. Let''s stay active and healthy.', 'Gym Motivation', 11.571595508313754, 104.94758521519529, 'Phnom Penh, Cambodia', TRUE)
ON CONFLICT ("firebaseUid") DO NOTHING;

INSERT INTO public.users ("firebaseUid", "fullName", email, gender, age, weight, height, workout_location, equipment_list, focus_areas, workout_frequency, training_level, is_setup_completed, weight_unit, fitness_goal, "profilePictureUrl", "coverPhotoUrl", "isOnline", bio, looking_for, latitude, longitude, location_label, "isPremium")
VALUES ('u21xoIliBobG8wmLD5w0lkZ65JA3', 'Drew Lopez', 'dummy12@spottr.com', 'Female', 36, 81, 159, 'Outdoor', '["Squat Rack","Kettlebells","Bench"]', '["Chest","Legs","Core"]', 4, 'Advanced', TRUE, 'kg', 'Strength', 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773807679/profile_pics/vrg69pgqfg7cdf81lfry.jpg', 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773816808/dummy_covers/pexels-cottonbro-6702092_iihfdi.jpg', FALSE, 'Getting back into fitness. Beginner-friendly vibes only!', 'Running Partner', 11.585114330235282, 104.93332189387132, 'Phnom Penh, Cambodia', TRUE)
ON CONFLICT ("firebaseUid") DO NOTHING;

INSERT INTO public.users ("firebaseUid", "fullName", email, gender, age, weight, height, workout_location, equipment_list, focus_areas, workout_frequency, training_level, is_setup_completed, weight_unit, fitness_goal, "profilePictureUrl", "coverPhotoUrl", "isOnline", bio, looking_for, latitude, longitude, location_label, "isPremium")
VALUES ('eYNMNRe31BSDcma2sWracvQxC6z2', 'Hayden Gonzalez', 'dummy13@spottr.com', 'Male', 37, 90, 173, 'Outdoor', '["Barbell","Kettlebells","Dumbbells","Squat Rack","Treadmill","Resistance Bands"]', '["Core","Shoulders"]', 5, 'Intermediate', TRUE, 'kg', 'Flexibility', 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773807683/profile_pics/mvxhcziibsaipekjkfzq.jpg', 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773816809/dummy_covers/9f2dba0f77574b71f3817917676b3176_vn8jbx.jpg', FALSE, 'Yoga and functional training enthusiast. Movement is life! 🧘‍♂️', 'Running Partner', 11.557967233157559, 104.93186978964398, 'Phnom Penh, Cambodia', TRUE)
ON CONFLICT ("firebaseUid") DO NOTHING;

INSERT INTO public.users ("firebaseUid", "fullName", email, gender, age, weight, height, workout_location, equipment_list, focus_areas, workout_frequency, training_level, is_setup_completed, weight_unit, fitness_goal, "profilePictureUrl", "coverPhotoUrl", "isOnline", bio, looking_for, latitude, longitude, location_label, "isPremium")
VALUES ('McnmvuVyE2ZZSsDduIeoa3C6ifm1', 'Reese Wilson', 'dummy14@spottr.com', 'Female', 21, 55, 188, 'Hybrid', '["Pull-up Bar","Kettlebells","Bench","Squat Rack"]', '["Full Body","Arms","Legs"]', 3, 'Intermediate', TRUE, 'kg', 'General Fitness', 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773807689/profile_pics/h3qeh0thgobuy1k1nqs0.jpg', 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773816810/dummy_covers/40a828eccb0b4d1fffda236ac3683633_kqglis.jpg', FALSE, 'Marathon runner in training. Looking for a partner to push limits.', 'Sports Partner', 11.556477287305649, 104.94864462997519, 'Phnom Penh, Cambodia', TRUE)
ON CONFLICT ("firebaseUid") DO NOTHING;

INSERT INTO public.users ("firebaseUid", "fullName", email, gender, age, weight, height, workout_location, equipment_list, focus_areas, workout_frequency, training_level, is_setup_completed, weight_unit, fitness_goal, "profilePictureUrl", "coverPhotoUrl", "isOnline", bio, looking_for, latitude, longitude, location_label, "isPremium")
VALUES ('k8GKsykCeNR9J4mEJOLFicg3Hjm2', 'Rowan Anderson', 'dummy15@spottr.com', 'Prefer not to say', 26, 84, 155, 'Hybrid', '["Treadmill","Squat Rack","Bench","Pull-up Bar","Kettlebells"]', '["Arms","Chest","Back"]', 6, 'Intermediate', TRUE, 'kg', 'Flexibility', 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773807692/profile_pics/tncuzvocewkgj7al4ef1.jpg', 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773816811/dummy_covers/4be8fe572800419336347aa352a20e6a_spgilu.jpg', FALSE, 'Fitness enthusiast. Love lifting and healthy living! 💪', 'Sports Partner', 11.572401819086783, 104.9081623961129, 'Phnom Penh, Cambodia', TRUE)
ON CONFLICT ("firebaseUid") DO NOTHING;

INSERT INTO public.users ("firebaseUid", "fullName", email, gender, age, weight, height, workout_location, equipment_list, focus_areas, workout_frequency, training_level, is_setup_completed, weight_unit, fitness_goal, "profilePictureUrl", "coverPhotoUrl", "isOnline", bio, looking_for, latitude, longitude, location_label, "isPremium")
VALUES ('SDuQp7Q398eahJ1hnjqyRznQzGH2', 'Spencer Thomas', 'dummy16@spottr.com', 'Female', 22, 82, 179, 'Home', '["Dumbbells","Pull-up Bar","Barbell","Resistance Bands","Squat Rack","Treadmill"]', '["Legs","Shoulders"]', 3, 'Advanced', TRUE, 'kg', 'Weight Loss', 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773807699/profile_pics/igsd1um8vhxdpxf8brv6.jpg', 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773816812/dummy_covers/f55148ad2ef92de8597008b60bcd29a8_b87mmv.jpg', FALSE, 'Lover of HIIT and strength training. Grinding never stops! 🔥', 'Gym Motivation', 11.607401807033034, 104.93970511464403, 'Phnom Penh, Cambodia', TRUE)
ON CONFLICT ("firebaseUid") DO NOTHING;

INSERT INTO public.users ("firebaseUid", "fullName", email, gender, age, weight, height, workout_location, equipment_list, focus_areas, workout_frequency, training_level, is_setup_completed, weight_unit, fitness_goal, "profilePictureUrl", "coverPhotoUrl", "isOnline", bio, looking_for, latitude, longitude, location_label, "isPremium")
VALUES ('jA8fS61cKLcfkGmRpY3Zqz1XHLf1', 'Charlie Taylor', 'dummy17@spottr.com', 'Female', 35, 75, 158, 'Home', '["Dumbbells","Barbell","Pull-up Bar","Squat Rack","Bench"]', '["Arms","Chest"]', 6, 'Advanced', TRUE, 'kg', 'Weight Loss', 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773807704/profile_pics/ap7oqd6yxbsqrvio5lnm.jpg', 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773816813/dummy_covers/110698eb5b90e05bac7282b60979b972_ju3jw8.jpg', FALSE, 'Crossfit lover and enthusiast. Hard work pays off.', 'Gym Motivation', 11.59159879787992, 104.95245065624646, 'Phnom Penh, Cambodia', TRUE)
ON CONFLICT ("firebaseUid") DO NOTHING;

INSERT INTO public.users ("firebaseUid", "fullName", email, gender, age, weight, height, workout_location, equipment_list, focus_areas, workout_frequency, training_level, is_setup_completed, weight_unit, fitness_goal, "profilePictureUrl", "coverPhotoUrl", "isOnline", bio, looking_for, latitude, longitude, location_label, "isPremium")
VALUES ('lGwJRAOWs7dtjUweVm4ish7I14f1', 'Finley Moore', 'dummy18@spottr.com', 'Female', 34, 66, 173, 'Home', '["Dumbbells","Treadmill","Barbell","Resistance Bands","Kettlebells"]', '["Legs","Full Body"]', 4, 'Beginner', TRUE, 'kg', 'Weight Loss', 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773807710/profile_pics/nr5syjkqltwx0ufdwvpp.jpg', 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773816815/dummy_covers/pexels-pixabay-361184_k30aju.jpg', FALSE, 'Getting back into fitness. Beginner-friendly vibes only!', 'Yoga Friend', 11.610536295109268, 104.94146284084678, 'Phnom Penh, Cambodia', TRUE)
ON CONFLICT ("firebaseUid") DO NOTHING;

INSERT INTO public.users ("firebaseUid", "fullName", email, gender, age, weight, height, workout_location, equipment_list, focus_areas, workout_frequency, training_level, is_setup_completed, weight_unit, fitness_goal, "profilePictureUrl", "coverPhotoUrl", "isOnline", bio, looking_for, latitude, longitude, location_label, "isPremium")
VALUES ('rXeiRsCfucgRh998wlaCrpuIRm73', 'Skyler Jackson', 'dummy19@spottr.com', 'Prefer not to say', 26, 87, 189, 'Gym', '["Dumbbells","Resistance Bands","Bench","Kettlebells","Barbell"]', '["Legs","Arms","Back","Shoulders"]', 3, 'Elite', TRUE, 'kg', 'Strength', 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773807713/profile_pics/pcbogk3ftuulmt39phta.jpg', 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773816816/dummy_covers/1d40d0ad9ef6f5ede9927271f00babb5_bs2hqh.jpg', FALSE, 'Crossfit lover and enthusiast. Hard work pays off.', 'Workout Buddy', 11.561272380901636, 104.88757775815351, 'Phnom Penh, Cambodia', TRUE)
ON CONFLICT ("firebaseUid") DO NOTHING;

INSERT INTO public.users ("firebaseUid", "fullName", email, gender, age, weight, height, workout_location, equipment_list, focus_areas, workout_frequency, training_level, is_setup_completed, weight_unit, fitness_goal, "profilePictureUrl", "coverPhotoUrl", "isOnline", bio, looking_for, latitude, longitude, location_label, "isPremium")
VALUES ('VpUNfiWzD6T0jDMLTDob3JAyXWH3', 'Cameron Martin', 'dummy20@spottr.com', 'Female', 40, 73, 156, 'Outdoor', '["Pull-up Bar","Dumbbells","Bench","Barbell","Treadmill","Kettlebells"]', '["Chest","Back","Shoulders"]', 5, 'Advanced', TRUE, 'kg', 'Weight Loss', 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773807719/profile_pics/ke9emjfcp77xwjx6itvs.jpg', 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773816817/dummy_covers/325110ec4a9b1052578b5cf7363d9186_erhcet.jpg', FALSE, 'Marathon runner in training. Looking for a partner to push limits.', 'Gym Motivation', 11.581449813244046, 104.89135228460668, 'Phnom Penh, Cambodia', TRUE)
ON CONFLICT ("firebaseUid") DO NOTHING;

INSERT INTO public.users ("firebaseUid", "fullName", email, gender, age, weight, height, workout_location, equipment_list, focus_areas, workout_frequency, training_level, is_setup_completed, weight_unit, fitness_goal, "profilePictureUrl", "coverPhotoUrl", "isOnline", bio, looking_for, latitude, longitude, location_label, "isPremium")
VALUES ('jqhKPoluPiOVglHs79tFU38VdP83', 'Dylan Lee', 'dummy21@spottr.com', 'Prefer not to say', 40, 61, 179, 'Home', '["Resistance Bands","Kettlebells","Bench","Barbell","Squat Rack","Treadmill"]', '["Full Body","Chest","Core","Arms"]', 3, 'Advanced', TRUE, 'kg', 'Weight Loss', 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773807725/profile_pics/dgra3hpqmwd7ndagyj1b.jpg', 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773816818/dummy_covers/1ccbbcbbc691c86c50aa99ddcf7d1777_cuytcj.jpg', FALSE, 'Strength training is my passion. PB hunting! 🏆', 'Yoga Friend', 11.543812301087334, 104.95037356679771, 'Phnom Penh, Cambodia', TRUE)
ON CONFLICT ("firebaseUid") DO NOTHING;

INSERT INTO public.users ("firebaseUid", "fullName", email, gender, age, weight, height, workout_location, equipment_list, focus_areas, workout_frequency, training_level, is_setup_completed, weight_unit, fitness_goal, "profilePictureUrl", "coverPhotoUrl", "isOnline", bio, looking_for, latitude, longitude, location_label, "isPremium")
VALUES ('qgyi8JnsgLM7aRXR3n8JWgrRhNk1', 'Virak', 'raklol754@gmail.com', 'Male', 21, 66, 167.7, 'Home', '["BodyWeight","Leg Press\nMachine","Dumbbell"]', '["Full Body","Back","Shoulder"]', 7, 'Beginner', TRUE, 'kg', NULL, NULL, NULL, FALSE, NULL, NULL, NULL, NULL, NULL, TRUE)
ON CONFLICT ("firebaseUid") DO NOTHING;

INSERT INTO public.posts (id, "userUid", content, "createdAt")
VALUES (160, 'eYNMNRe31BSDcma2sWracvQxC6z2', 'Feeling stronger than ever! Never give up. 💯', '2026-03-18T11:42:56.723Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.posts (id, "userUid", content, "createdAt")
VALUES (161, 'WhXdUnhxOXa8eVvrY6jX9f1jjpJ3', 'Sweat, smile, and repeat. That''s the motto! 😁', '2026-03-18T11:40:56.730Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.posts (id, "userUid", content, "createdAt")
VALUES (162, 'VcNMjINAllPzZMYZ7gk9Xm3cVHE3', 'Sometimes you just need to lift heavy things. 🦍', '2026-03-18T11:38:56.740Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.posts (id, "userUid", content, "createdAt")
VALUES (163, 'VpUNfiWzD6T0jDMLTDob3JAyXWH3', 'A full look at today''s session! 📸🎥', '2026-03-18T11:36:56.747Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.posts (id, "userUid", content, "createdAt")
VALUES (164, 'VcNMjINAllPzZMYZ7gk9Xm3cVHE3', 'Fueling up for the next session! 🥗', '2026-03-18T11:34:56.753Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.posts (id, "userUid", content, "createdAt")
VALUES (165, 'VpUNfiWzD6T0jDMLTDob3JAyXWH3', 'Consistency is key. Seeing progress every day! 🔥', '2026-03-18T11:32:56.757Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.posts (id, "userUid", content, "createdAt")
VALUES (166, 'WhXdUnhxOXa8eVvrY6jX9f1jjpJ3', 'Feeling stronger than ever! Never give up. 💯', '2026-03-18T11:30:56.760Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.posts (id, "userUid", content, "createdAt")
VALUES (167, 'eYNMNRe31BSDcma2sWracvQxC6z2', 'Early morning grind. No excuses! 🌅', '2026-03-18T11:28:56.763Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.posts (id, "userUid", content, "createdAt")
VALUES (168, 'p10z489UZYU1AVwpnEVjlfRGJkR2', 'Some highlights from the gym. Keep grinding! 💪✨', '2026-03-18T11:26:56.767Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.posts (id, "userUid", content, "createdAt")
VALUES (169, 'k8GKsykCeNR9J4mEJOLFicg3Hjm2', 'Sweat, smile, and repeat. That''s the motto! 😁', '2026-03-18T11:24:56.773Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.posts (id, "userUid", content, "createdAt")
VALUES (170, 'Hi3Rybe6ryVFm4LypojQr2qM9Vn2', 'Consistency is key. Seeing progress every day! 🔥', '2026-03-18T11:22:56.777Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.posts (id, "userUid", content, "createdAt")
VALUES (171, 'yelWAekr9OciERN80fVEi7dwQUe2', 'Focusing on the form today. Quality over quantity. 🏋️‍♂️', '2026-03-18T11:20:56.783Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.posts (id, "userUid", content, "createdAt")
VALUES (172, 'Q1xXEPbXmYY4HCv5zty2iOPUZnK2', 'Consistency is key. Seeing progress every day! 🔥', '2026-03-18T11:18:56.787Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.posts (id, "userUid", content, "createdAt")
VALUES (173, 'GS81b4fFm8ZOyJoqiJ10v2n5x7t2', 'Swipe to see the progress! ➡️🔥', '2026-03-18T11:16:56.790Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.posts (id, "userUid", content, "createdAt")
VALUES (174, 'u21xoIliBobG8wmLD5w0lkZ65JA3', 'Sometimes you just need to lift heavy things. 🦍', '2026-03-18T11:14:56.797Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.posts (id, "userUid", content, "createdAt")
VALUES (175, 'iQRptZdDhNOwd0TfjXCiLvEjvmB3', 'Feeling stronger than ever! Never give up. 💯', '2026-03-18T11:12:56.800Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.posts (id, "userUid", content, "createdAt")
VALUES (176, 'U4QdkEbUWiMaqAhE0kOgPv2tUR02', 'Some highlights from the gym. Keep grinding! 💪✨', '2026-03-18T11:10:56.803Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.posts (id, "userUid", content, "createdAt")
VALUES (177, 'jA8fS61cKLcfkGmRpY3Zqz1XHLf1', 'Early morning grind. No excuses! 🌅', '2026-03-18T11:08:56.807Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.posts (id, "userUid", content, "createdAt")
VALUES (178, 'YAzWzdXZtgQQSXvk0RTFyjcn7ze2', 'Sweat, smile, and repeat. That''s the motto! 😁', '2026-03-18T11:06:56.810Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.posts (id, "userUid", content, "createdAt")
VALUES (179, 'SDuQp7Q398eahJ1hnjqyRznQzGH2', 'Rest day feels good, but can''t wait to get back into it. 🧘‍♂️', '2026-03-18T11:04:56.817Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.posts (id, "userUid", content, "createdAt")
VALUES (180, 'McnmvuVyE2ZZSsDduIeoa3C6ifm1', 'Feeling stronger than ever! Never give up. 💯', '2026-03-18T11:02:56.817Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.posts (id, "userUid", content, "createdAt")
VALUES (181, 'a0uSf9dcyoRhLyicvqYwM5velqv2', 'Fueling up for the next session! 🥗', '2026-03-18T11:00:56.820Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.posts (id, "userUid", content, "createdAt")
VALUES (182, 'jqhKPoluPiOVglHs79tFU38VdP83', 'Some highlights from the gym. Keep grinding! 💪✨', '2026-03-18T10:58:56.823Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.posts (id, "userUid", content, "createdAt")
VALUES (183, 'rXeiRsCfucgRh998wlaCrpuIRm73', 'Focusing on the form today. Quality over quantity. 🏋️‍♂️', '2026-03-18T10:56:56.827Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.posts (id, "userUid", content, "createdAt")
VALUES (184, 'lGwJRAOWs7dtjUweVm4ish7I14f1', 'Consistency is key. Seeing progress every day! 🔥', '2026-03-18T10:54:56.830Z')
ON CONFLICT (id) DO NOTHING;

-- Reset posts id sequence
SELECT setval('public.posts_id_seq', (SELECT COALESCE(MAX(id), 1) FROM public.posts));

INSERT INTO public.post_media (id, "postId", "mediaUrl", "mediaType", "createdAt")
VALUES (217, 160, 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773808610/post_media/pexels-pixabay-260352.jpg', 'image', '2026-03-18T11:42:56.730Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.post_media (id, "postId", "mediaUrl", "mediaType", "createdAt")
VALUES (218, 161, 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773808598/post_media/d42dbc581da8fa4b7427921cd8513d17.jpg', 'image', '2026-03-18T11:42:56.733Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.post_media (id, "postId", "mediaUrl", "mediaType", "createdAt")
VALUES (219, 161, 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773808604/post_media/pexels-cottonbro-6702092.jpg', 'image', '2026-03-18T11:42:56.737Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.post_media (id, "postId", "mediaUrl", "mediaType", "createdAt")
VALUES (220, 161, 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773808580/post_media/110698eb5b90e05bac7282b60979b972.jpg', 'image', '2026-03-18T11:42:56.740Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.post_media (id, "postId", "mediaUrl", "mediaType", "createdAt")
VALUES (221, 162, 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773808605/post_media/pexels-janetrangdoan-1092730.jpg', 'image', '2026-03-18T11:42:56.743Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.post_media (id, "postId", "mediaUrl", "mediaType", "createdAt")
VALUES (222, 163, 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773808600/post_media/f0fd08b3bb0a29af0e802a8769a1e82c.jpg', 'image', '2026-03-18T11:42:56.750Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.post_media (id, "postId", "mediaUrl", "mediaType", "createdAt")
VALUES (223, 163, 'https://res.cloudinary.com/dgncejd4g/video/upload/v1773808615/post_media/Engine_is_running.mp4', 'video', '2026-03-18T11:42:56.750Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.post_media (id, "postId", "mediaUrl", "mediaType", "createdAt")
VALUES (224, 164, 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773808595/post_media/9f2dba0f77574b71f3817917676b3176.jpg', 'image', '2026-03-18T11:42:56.757Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.post_media (id, "postId", "mediaUrl", "mediaType", "createdAt")
VALUES (225, 165, 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773808596/post_media/b770cc5a7bb41f338146406548fb4604.jpg', 'image', '2026-03-18T11:42:56.760Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.post_media (id, "postId", "mediaUrl", "mediaType", "createdAt")
VALUES (226, 166, 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773808589/post_media/40a828eccb0b4d1fffda236ac3683633.jpg', 'image', '2026-03-18T11:42:56.763Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.post_media (id, "postId", "mediaUrl", "mediaType", "createdAt")
VALUES (227, 167, 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773808578/post_media/002da167a6db91939b6585ff7ec04114.jpg', 'image', '2026-03-18T11:42:56.767Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.post_media (id, "postId", "mediaUrl", "mediaType", "createdAt")
VALUES (228, 168, 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773808609/post_media/pexels-nadin-sh-78971847-36555145.jpg', 'image', '2026-03-18T11:42:56.770Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.post_media (id, "postId", "mediaUrl", "mediaType", "createdAt")
VALUES (229, 168, 'https://res.cloudinary.com/dgncejd4g/video/upload/v1773808615/post_media/Engine_is_running.mp4', 'video', '2026-03-18T11:42:56.770Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.post_media (id, "postId", "mediaUrl", "mediaType", "createdAt")
VALUES (230, 169, 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773808593/post_media/82b0b4ff4b22f0fb06e4ebe6f65500c1.jpg', 'image', '2026-03-18T11:42:56.773Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.post_media (id, "postId", "mediaUrl", "mediaType", "createdAt")
VALUES (231, 170, 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773808611/post_media/pexels-pixabay-361184.jpg', 'image', '2026-03-18T11:42:56.780Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.post_media (id, "postId", "mediaUrl", "mediaType", "createdAt")
VALUES (232, 170, 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773808584/post_media/1ce259cdd0779c3b00ff40c1220783fe.jpg', 'image', '2026-03-18T11:42:56.780Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.post_media (id, "postId", "mediaUrl", "mediaType", "createdAt")
VALUES (233, 171, 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773808591/post_media/4be8fe572800419336347aa352a20e6a.jpg', 'image', '2026-03-18T11:42:56.783Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.post_media (id, "postId", "mediaUrl", "mediaType", "createdAt")
VALUES (234, 172, 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773808581/post_media/12e2c6eac85eb312e394755d150fae9a.jpg', 'image', '2026-03-18T11:42:56.787Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.post_media (id, "postId", "mediaUrl", "mediaType", "createdAt")
VALUES (235, 173, 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773808601/post_media/f55148ad2ef92de8597008b60bcd29a8.jpg', 'image', '2026-03-18T11:42:56.793Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.post_media (id, "postId", "mediaUrl", "mediaType", "createdAt")
VALUES (236, 173, 'https://res.cloudinary.com/dgncejd4g/video/upload/v1773808615/post_media/Engine_is_running.mp4', 'video', '2026-03-18T11:42:56.793Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.post_media (id, "postId", "mediaUrl", "mediaType", "createdAt")
VALUES (237, 174, 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773808608/post_media/pexels-lum3n-44775-1410235.jpg', 'image', '2026-03-18T11:42:56.800Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.post_media (id, "postId", "mediaUrl", "mediaType", "createdAt")
VALUES (238, 175, 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773808599/post_media/e1386d7c1d2d2f998b23b1b8d77d343b.jpg', 'image', '2026-03-18T11:42:56.800Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.post_media (id, "postId", "mediaUrl", "mediaType", "createdAt")
VALUES (239, 176, 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773808582/post_media/1ccbbcbbc691c86c50aa99ddcf7d1777.jpg', 'image', '2026-03-18T11:42:56.803Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.post_media (id, "postId", "mediaUrl", "mediaType", "createdAt")
VALUES (240, 176, 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773808588/post_media/3d3364e50260be1b67213d4dc339ddff.jpg', 'image', '2026-03-18T11:42:56.803Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.post_media (id, "postId", "mediaUrl", "mediaType", "createdAt")
VALUES (241, 176, 'https://res.cloudinary.com/dgncejd4g/video/upload/v1773808615/post_media/Engine_is_running.mp4', 'video', '2026-03-18T11:42:56.807Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.post_media (id, "postId", "mediaUrl", "mediaType", "createdAt")
VALUES (242, 177, 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773808613/post_media/pexels-pixabay-39671.jpg', 'image', '2026-03-18T11:42:56.810Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.post_media (id, "postId", "mediaUrl", "mediaType", "createdAt")
VALUES (243, 178, 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773808602/post_media/pexels-annushka-ahuja-7991911.jpg', 'image', '2026-03-18T11:42:56.813Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.post_media (id, "postId", "mediaUrl", "mediaType", "createdAt")
VALUES (244, 179, 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773808587/post_media/325110ec4a9b1052578b5cf7363d9186.jpg', 'image', '2026-03-18T11:42:56.817Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.post_media (id, "postId", "mediaUrl", "mediaType", "createdAt")
VALUES (245, 180, 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773808586/post_media/1d40d0ad9ef6f5ede9927271f00babb5.jpg', 'image', '2026-03-18T11:42:56.820Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.post_media (id, "postId", "mediaUrl", "mediaType", "createdAt")
VALUES (246, 181, 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773808614/post_media/pexels-pixabay-416717.jpg', 'image', '2026-03-18T11:42:56.820Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.post_media (id, "postId", "mediaUrl", "mediaType", "createdAt")
VALUES (247, 182, 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773808606/post_media/pexels-koolshooters-8520628.jpg', 'image', '2026-03-18T11:42:56.827Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.post_media (id, "postId", "mediaUrl", "mediaType", "createdAt")
VALUES (248, 182, 'https://res.cloudinary.com/dgncejd4g/video/upload/v1773808615/post_media/Engine_is_running.mp4', 'video', '2026-03-18T11:42:56.827Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.post_media (id, "postId", "mediaUrl", "mediaType", "createdAt")
VALUES (249, 183, 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773808594/post_media/91f1ef4562c042b0f6ab96678239243b.jpg', 'image', '2026-03-18T11:42:56.830Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.post_media (id, "postId", "mediaUrl", "mediaType", "createdAt")
VALUES (250, 183, 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773808597/post_media/c81cab4ad349f9a087cad06f51b82e92.jpg', 'image', '2026-03-18T11:42:56.830Z')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.post_media (id, "postId", "mediaUrl", "mediaType", "createdAt")
VALUES (251, 184, 'https://res.cloudinary.com/dgncejd4g/image/upload/v1773808592/post_media/559a7f139ac7fdd9993973716bcf5713.jpg', 'image', '2026-03-18T11:42:56.833Z')
ON CONFLICT (id) DO NOTHING;

-- Reset post_media id sequence
SELECT setval('public.post_media_id_seq', (SELECT COALESCE(MAX(id), 1) FROM public.post_media));

