# Spottr — Social Fitness Platform & AI Workout Partner

<p align="center">
  <img src="major_frontend/assets/images/app_logo.png" alt="Spottr Logo" width="100" />
</p>

A next-generation social fitness platform connecting fitness enthusiasts with compatible workout partners, personal AI coaching, and over 1,000 video-guided exercises.

Spottr features a flexible architecture: a **100% Free Standalone Mobile App** (Flutter + Supabase) that runs without any server hosting overhead, alongside the full **Node.js Express & SQL Server Microservice Backend** (`major_backend/`) for custom enterprise deployments.

---

## Features

- **Personalized Workout Plans**: Dynamic fitness programs tailored to individual experience levels and athletic goals.
- **AI Fitness Coach**: Real-time conversational fitness guidance powered by Groq (Llama-3).
- **1,000+ Exercise Library**: Extensive catalog of movements with direct YouTube video demonstration links.
- **Gym Partner Discovery**: Location and preference-based matching to find workout buddies nearby.
- **Real-Time Social Feed & Chat**: Community posts, progress sharing, workout reactions, and direct messaging.
- **Zero Paywalls**: All exercises, AI coaching, and partner discovery are fully unlocked and 100% free.

---

## Architecture & Deployment Modes

### Mode 1: Standalone / Serverless Mode (Current Mobile Release)
- **Direct Supabase Integration:** Authentication (Email/Password), User Profiles, Social Feed, Likes, Comments, and Direct Messaging are handled directly via Supabase PostgreSQL and Realtime subscriptions.
- **Zero Server Costs:** No Node.js server, MSSQL instance, or external webhooks needed to run the mobile app.
- **Built-in Offline Workouts:** Over 870+ exercises and 10 full multi-week workout programs are bundled locally for instant offline access.

### Mode 2: Microservice Backend Mode (`major_backend/`)
- **Node.js & Express REST API:** Complete suite of 7 modular routes covering authentication, workout catalog queries, social feeds, and notifications.
- **Database Support:** Full schema scripts and pre-configured models for Microsoft SQL Server (MSSQL) with `database.bacpac` recovery.
- **Third-Party Services:** Firebase Cloud Messaging (FCM) push notifications, Cloudinary media storage, and Stripe webhook handling.

---

## Project Structure

```text
Spottr/
├── major_frontend/           # Flutter Mobile Application (iOS & Android)
│   ├── assets/               # Local icons, illustrations, and exercise datasets
│   ├── lib/
│   │   ├── screens/          # Auth, Home, Workouts, Social, and Profile views
│   │   ├── services/         # Supabase client, AI coach, chat, and offline DB
│   │   └── widgets/          # Reusable cards, dialogs, and video players
│   └── pubspec.yaml          # Flutter dependencies (supabase_flutter, etc.)
├── major_backend/            # Node.js + Express REST API Server
│   ├── config/               # Database pool and Firebase admin configuration
│   ├── routes/               # API endpoints (auth, workouts, chat, social)
│   ├── services/             # Push notification and storage helpers
│   ├── socket/               # Realtime WebSocket event handlers
│   └── package.json          # Node.js dependencies
├── database.bacpac           # Original MSSQL database backup
├── spottr_supabase_setup.sql # Master idempotent Supabase PostgreSQL setup script
└── README.md                 # Monorepo documentation
```

---

## UI Preview

| Home Screen | Workout Search | Exercise Detail |
| :---: | :---: | :---: |
| ![Home](major_frontend/assets/screenshots/Screenshot%202026-03-27%20113318.png) | ![Search](major_frontend/assets/screenshots/Screenshot%202026-03-27%20114243.png) | ![Detail](major_frontend/assets/screenshots/Screenshot%202026-03-27%20114303.png) |

---

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.27 or higher)
- [Node.js](https://nodejs.org/) (v18 or higher, optional for backend mode)
- [SQL Server](https://www.microsoft.com/en-us/sql-server/sql-server-downloads) (optional for backend mode)
- [Supabase Account](https://supabase.com) (for standalone serverless mode)

---

### Part 1: Running the Mobile App (Flutter)

1. **Navigate to the frontend directory:**
   ```bash
   cd major_frontend
   ```

2. **Install Flutter packages:**
   ```bash
   flutter pub get
   ```

3. **Configure Supabase Credentials:**
   Verify `lib/services/config.dart` has your active Supabase URL and public anon key.

4. **Run the App:**
   ```bash
   flutter run
   ```

5. **Build Standalone Release APK:**
   ```bash
   flutter build apk --split-per-abi --release
   ```

---

### Part 2: Running the Backend Server (Node.js & MSSQL)

If you wish to run the original Node.js microservice architecture:

1. **Navigate to the backend directory:**
   ```bash
   cd major_backend
   ```

2. **Install dependencies:**
   ```bash
   npm install
   ```

3. **Configure Environment Secrets:**
   Create `.env` from `.env.example`:
   ```bash
   cp .env.example .env
   ```
   Configure your database credentials, Groq API key, Cloudinary keys, and Firebase service account path.

4. **Initialize Database:**
   Ensure SQL Server is running, then run the database migration scripts:
   ```bash
   node setup-db.js
   ```

5. **Start the Server:**
   ```bash
   npm run dev
   ```
   The backend API will listen on `http://localhost:5000`.

---

## Security & Privacy

- **Safe Version Control:** Neither `.env`, private service accounts, nor production credentials are tracked in Git.
- **Row Level Security:** In Supabase standalone mode, all personal user data, private messages, and user plans are isolated with PostgreSQL Row Level Security (RLS).
- **Public Templates:** Both components provide `.env.example` templates with empty placeholders for secure onboarding.

---

## Disclaimer

- **Workout Content**: This application references workout demonstration videos sourced from YouTube for educational fitness demonstration. All credits for the video content belong to their respective creators.
- **Safety**: Always consult a qualified physician or healthcare provider before beginning any vigorous exercise regimen.

---

## Author

**Sok Virak** — [@VirakSok18](https://github.com/VirakSok18)
