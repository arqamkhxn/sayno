# 🚀 First Real End-to-End Test (Phase 1 Checklist)

Phase 1 code implementation is complete. I have wired the Home Feed `ContentCardWidget` to route to a new `FeedVideoPlayerScreen` which correctly utilizes the existing `YoutubeMediaProvider` for playback.

Follow these exact steps to run the first real YouTube ingestion and test it on your physical device.

## 1. Configure Local Secrets
Inside `sayno-uce/functions`, create a file named `.env.local` containing your real API keys (the emulator will load these automatically without exposing them to your Git repo):
```env
YOUTUBE_API_KEY=your_real_youtube_key
GEMINI_API_KEY=your_real_gemini_key
```

## 2. Start the Backend Emulators
Open a terminal in the `sayno-uce/functions` directory:
```powershell
npm run build
cd ..
firebase emulators:start --only auth,firestore,functions
```
*(Keep this terminal running. Emulators are now bound to `0.0.0.0` to allow LAN access).*

## 3. Launch the Flutter App on Your Physical Device
Find your Windows IPv4 Address (e.g., `192.168.1.100` via `ipconfig`). 
Open a new terminal in your Flutter project root (`d:\A-SAYNO APP`) and run the app on your connected Android phone using the emulator flags:

```powershell
flutter run --dart-define=USE_LOCAL_EMULATOR=true --dart-define=LAN_IP=192.168.1.100
```
*Once the app opens, sign up/login as a new user. Complete the Identity Setup so your user is ready to receive a feed.*

## 4. Get an Admin Token
Open the Local Auth Emulator UI in your browser: [http://localhost:4000/auth](http://localhost:4000/auth). 
Copy the **User UID** of the account you just created.

Run the admin script I created for you to grant this user the `admin` claim and generate a fresh ID token:
```powershell
cd sayno-uce/functions
node set-admin.js YOUR_COPIED_UID
```
*Copy the very long ID Token printed in your console.*

## 5. Trigger Real Ingestion
Run this `curl` command (replacing `YOUR_ID_TOKEN`) to trigger the secure admin ingestion endpoint. Because we are using the local emulator, it connects to the functions emulator on port 5001:

```powershell
curl -X POST http://localhost:5001/sayno-6bbdd/us-central1/feedApi/v1/admin/ingest `
  -H "Authorization: Bearer YOUR_ID_TOKEN" `
  -H "Content-Type: application/json"
```

## 6. Trace & Verify Playback
1. **Watch the Emulator Logs:** You should see `admin.ingest.start`, followed by YouTube API fetches, and then Firestore triggers firing (`onContentIngested` -> Gemini Analysis -> `onContentAnalyzed` -> Recommendation Scoring).
2. **Refresh the App:** Pull to refresh the Home Feed on your Android phone.
3. **Play the Video:** Tap on one of the new real YouTube cards. It will open the `FeedVideoPlayerScreen` and stream the actual video.

> [!IMPORTANT]
> If anything fails during the Gemini analysis or YouTube ingestion, the emulator logs will output exactly where it broke. Share those logs with me so we can fix any pipeline issues before moving to Phase 2 (Remote 20-User setup).
