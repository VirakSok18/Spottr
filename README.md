# Spottr - Social Fitness App

![App Logo](major_frontend/assets/images/app_logo.png)

a social fitness platform connecting users with compatible workout partners

## Features

- **Personalized Workout Plans**: Tailored exercises based on your goals.
- **AI Fitness Coach**: Real-time guidance using Groq (Llama-3).
- **Dynamic Exercise Library**: Extensive list of exercises with detailed instructions.
- **Real-time Interaction**: Integrated chat and social features (via Socket.io).
- **Secure Payments**: Premium features available through Stripe integration.
- **Cloud Storage**: Secure media uploads using Cloudinary.
- **Smart Notifications**: Built with Firebase Cloud Messaging.

## Project Structure

```text
.
├── major_backend/          # Node.js Express server
├── major_frontend/         # Flutter mobile application
└── README.md               # Main documentation
```

## UI Preview

| Home Screen | Workout Search | Exercise Detail |
| :---: | :---: | :---: |
| ![Home](major_frontend/assets/screenshots/Screenshot%202026-03-27%20113318.png) | ![Search](major_frontend/assets/screenshots/Screenshot%202026-03-27%20114243.png) | ![Detail](major_frontend/assets/screenshots/Screenshot%202026-03-27%20114303.png) |

---

## Prerequisites

Before you begin, ensure you have the following installed:
- [Flutter](https://docs.flutter.dev/get-started/install) (latest stable version)
- [Node.js](https://nodejs.org/) (v14 or higher)
- [SQL Server](https://www.microsoft.com/en-us/sql-server/sql-server-downloads) (Express edition is fine)
- [Firebase account](https://console.firebase.google.com/)

---

## Backend Setup (Node.js)

1. **Navigate to the backend directory:**
   ```bash
   cd major_backend
   ```

2. **Install dependencies:**
   ```bash
   npm install
   ```

3. **Configure Environment Variables:**
   Create a `.env` file based on `.env.example`:
   ```bash
   cp .env.example .env
   ```
   **Update the following mandatory keys:**
   - `DB_USER` & `DB_PASSWORD`: Your SQL Server credentials.
   - `STRIPE_SECRET_KEY`: From your Stripe dashboard.
   - `CLOUDINARY_API_KEY`: From Cloudinary.
   - `YOUTUBE_API_KEY`: From Google Cloud Console.
   - `GROQ_API_KEY`: From Groq Cloud Console.
   - `FIREBASE_SERVICE_ACCOUNT_PATH`: Path to your downloaded service account JSON.

4. **Initialize Database:**
   Ensure SQL Server is running, then create the `spottr` database and run:
   ```bash
   node setup-db.js
   ```

5. **Start the Server:**
   ```bash
   npm run dev
   ```

---

## Frontend Setup (Flutter)

1. **Navigate to the frontend directory:**
   ```bash
   cd major_frontend
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Configure Backend URL:**
   Update `lib/services/config.dart` with your local or deployed backend URL.

4. **Configure API Keys:**
   - **Groq**: Set your key in `lib/services/ai_chat_service.dart`.
   - **Google Maps**: Set your key in `lib/services/location_service.dart`.

5. **Run the App:**
   ```bash
   flutter run
   ```

---

## External API Setup

### 1. Firebase
- Create a project in [Firebase Console](https://console.firebase.google.com/).
- Add Android/iOS apps and download config files (`google-services.json` / `GoogleService-Info.plist`).
- Enable **Authentication** (Email/Google) and **Firestore**.

### 2. Groq AI (AI Coach)
- Sign up at [Groq Cloud](https://console.groq.com/).
- Generate an API Key and add it to your frontend/backend config.

### 3. Google Maps
- Enable **Maps SDK for Android/iOS** and **Places API** in [Google Cloud Console](https://console.cloud.google.com/).
- Generate an API Key and add it to the app.

### 4. Stripe
- Get your API keys from [Stripe Dashboard](https://dashboard.stripe.com/).
- Configure webhooks to point to `YOUR_BACKEND_URL/api/payments/webhook`.

---

## Database Note (Workout Videos)

This application retrieves workout demonstration videos from YouTube. To make the workout tracking work:
- The `Workouts` table contains a column named `Short_YouTube_Demonstration`.
- **Important**: You must populate this column with valid YouTube URLs or Video IDs for the exercises you want to show in the app.
- If you use the provided `setup_database.sql` or backup, ensure the links are active.

---

## Full UI Gallery

| | | |
| :---: | :---: | :---: |
| ![UI](major_frontend/assets/screenshots/Screenshot%202026-03-27%20113318.png) | ![UI](major_frontend/assets/screenshots/Screenshot%202026-03-27%20113417.png) | ![UI](major_frontend/assets/screenshots/Screenshot%202026-03-27%20113522.png) |
| ![UI](major_frontend/assets/screenshots/Screenshot%202026-03-27%20113534.png) | ![UI](major_frontend/assets/screenshots/Screenshot%202026-03-27%20113547.png) | ![UI](major_frontend/assets/screenshots/Screenshot%202026-03-27%20114010.png) |
| ![UI](major_frontend/assets/screenshots/Screenshot%202026-03-27%20114016.png) | ![UI](major_frontend/assets/screenshots/Screenshot%202026-03-27%20114022.png) | ![UI](major_frontend/assets/screenshots/Screenshot%202026-03-27%20114038.png) |
| ![UI](major_frontend/assets/screenshots/Screenshot%202026-03-27%20114046.png) | ![UI](major_frontend/assets/screenshots/Screenshot%202026-03-27%20114059.png) | ![UI](major_frontend/assets/screenshots/Screenshot%202026-03-27%20114111.png) |
| ![UI](major_frontend/assets/screenshots/Screenshot%202026-03-27%20114122.png) | ![UI](major_frontend/assets/screenshots/Screenshot%202026-03-27%20114128.png) | ![UI](major_frontend/assets/screenshots/Screenshot%202026-03-27%20114140.png) |
| ![UI](major_frontend/assets/screenshots/Screenshot%202026-03-27%20114201.png) | ![UI](major_frontend/assets/screenshots/Screenshot%202026-03-27%20114208.png) | ![UI](major_frontend/assets/screenshots/Screenshot%202026-03-27%20114214.png) |
| ![UI](major_frontend/assets/screenshots/Screenshot%202026-03-27%20114225.png) | ![UI](major_frontend/assets/screenshots/Screenshot%202026-03-27%20114236.png) | ![UI](major_frontend/assets/screenshots/Screenshot%202026-03-27%20114243.png) |
| ![UI](major_frontend/assets/screenshots/Screenshot%202026-03-27%20114252.png) | ![UI](major_frontend/assets/screenshots/Screenshot%202026-03-27%20114303.png) | ![UI](major_frontend/assets/screenshots/Screenshot%202026-03-27%20115431.png) |
| ![UI](major_frontend/assets/screenshots/Screenshot%202026-03-27%20115452.png) | ![UI](major_frontend/assets/screenshots/Screenshot%202026-03-27%20115505.png) | ![UI](major_frontend/assets/screenshots/Screenshot%202026-03-27%20115512.png) |
| ![UI](major_frontend/assets/screenshots/Screenshot%202026-03-27%20115521.png) | ![UI](major_frontend/assets/screenshots/Screenshot%202026-03-27%20115530.png) | ![UI](major_frontend/assets/screenshots/Screenshot%202026-03-27%20115537.png) |
| ![UI](major_frontend/assets/screenshots/Screenshot%202026-03-27%20115544.png) | ![UI](major_frontend/assets/screenshots/Screenshot%202026-03-27%20115555.png) | ![UI](major_frontend/assets/screenshots/Screenshot%202026-03-27%20115601.png) |
| ![UI](major_frontend/assets/screenshots/Screenshot%202026-03-27%20115609.png) | ![UI](major_frontend/assets/screenshots/Screenshot%202026-03-27%20115857.png) | ![UI](major_frontend/assets/screenshots/Screenshot%202026-03-27%20120016.png) |
| ![UI](major_frontend/assets/screenshots/Screenshot%202026-03-27%20120022.png) | ![UI](major_frontend/assets/screenshots/Screenshot%202026-03-27%20120032.png) | ![UI](major_frontend/assets/screenshots/Screenshot%202026-03-27%20120052.png) |
| ![UI](major_frontend/assets/screenshots/Screenshot%202026-03-27%20120122.png) | ![UI](major_frontend/assets/screenshots/Screenshot%202026-03-27%20120419.png) | ![UI](major_frontend/assets/screenshots/Screenshot%202026-03-27%20120427.png) |

---

## ⚠️ Disclaimer

- **Workout Content**: This application uses workout demonstration videos sourced from YouTube for educational purposes. All credits for the video content belong to their respective creators.
- **Safety**: Consult a healthcare professional before starting any new exercise program. The app provided plans are for guidance only.
