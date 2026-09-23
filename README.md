# Location Sharing System (X ➔ Y)

A real-time, privacy-focused location sharing system split into **two completely separate Flutter mobile applications** and **one lightweight Node.js backend**.

```text
Location/
│
├── sender_app/       # Installed ONLY on Phone X (Collects & pushes GPS coordinates)
│   ├── lib/
│   │   ├── config/app_config.dart
│   │   ├── models/location_data.dart
│   │   ├── services/api_service.dart
│   │   ├── services/location_service.dart
│   │   ├── widgets/status_badge.dart
│   │   ├── widgets/coordinate_card.dart
│   │   ├── widgets/server_config_dialog.dart
│   │   ├── screens/sender_screen.dart
│   │   └── main.dart
│   ├── android/
│   └── pubspec.yaml
│
├── receiver_app/     # Installed ONLY on Phone Y (Displays live coordinates on Google Maps)
│   ├── lib/
│   │   ├── config/app_config.dart
│   │   ├── models/location_data.dart
│   │   ├── services/api_service.dart
│   │   ├── services/socket_service.dart
│   │   ├── widgets/map_view.dart
│   │   ├── widgets/coordinate_card.dart
│   │   ├── widgets/status_badge.dart
│   │   ├── widgets/server_config_dialog.dart
│   │   ├── screens/receiver_screen.dart
│   │   └── main.dart
│   ├── android/
│   └── pubspec.yaml
│
└── backend/          # Node.js + Express + MongoDB Atlas + Socket.IO server
    ├── models/Location.js
    ├── controllers/locationController.js
    ├── routes/locationRoutes.js
    ├── services/socketService.js
    ├── server.js
    ├── package.json
    ├── test_api.js
    └── .env
```

---

## 🏗 Architecture Overview

```text
                 SENDER APP
                Android X
                    │
                    │ GPS (Geolocator + Foreground Service)
                    ↓
             LocationService
                    │
                    │ HTTP POST /api/location
                    ↓
          ┌──────────────────┐
          │ Node.js / Express│
          └────────┬─────────┘
                   │
                   ↓
              MongoDB Atlas
             (single doc: _id="X")
                   │
                   │
                   ↓
               Socket.IO (event: locationUpdated)
                   │
                   ↓
          ┌──────────────────┐
          │  RECEIVER APP    │
          │    Android Y     │
          └────────┬─────────┘
                   │
                   ↓
             Google Maps
                   │
                   📍 X
```

---

## 📱 1. Sender App (`sender_app/`)

Installed exclusively on **Phone X**.

### Features:
- **Clean Material 3 UI**:
  - Location Sharing status: `● ACTIVE` / `● STOPPED`
  - Latitude, Longitude, Accuracy (m), Last Updated timestamp.
  - Big `[ START SHARING ]` and `[ STOP SHARING ]` buttons.
- **Privacy & Permissions**:
  - Explains location access requirement before prompting.
  - Handles GPS disabled, permission denied, and permanently denied states with setting shortcuts.
  - Shows clear indicator that sharing is active.
- **Android Background / Foreground Service & Continuous Streaming**:
  - Employs `geolocator` with Android Foreground Service notification:
    - **Title**: `Continuous Location Sharing Active`
    - **Text**: `Real-time updates sending every 5s without break.`
  - **Zero Break / Continuous Real-Time Tracking**:
    - Default interval: **5 seconds** (or customizable: 3s, 5s, 10s, 30s, etc.).
    - `distanceFilter: 0` ensures real-time updates are pushed continuously even if stationary or moving slowly.
    - CPU WakeLock (`enableWakeLock: true`) prevents Android Doze / battery suspend while sharing.
    - Dual tracking: Native Android Fused Location Provider stream + periodic heartbeat timer to guarantee continuous sending without interruption.
- **Graceful Offline Handling**:
  - If internet drops, GPS coordinates are still read locally, but the app warns:
    ```text
    Internet unavailable
    Last upload failed
    ```
    and avoids falsely reporting successful transmission.
- **Configurable Server URL**:
  - Tap the settings icon (⚙️) on the top right to set the backend URL (e.g., `http://10.0.2.2:5000` for Android emulator or `http://<YOUR_LAN_IP>:5000` for physical devices).

---

## 🗺 2. Receiver App (`receiver_app/`)

Installed exclusively on **Phone Y**.

### Features:
- **Zero GPS Requirement**:
  - The Receiver app **never** requests or requires the user's own GPS or location permissions.
- **Google Maps Integration**:
  - Displays a marker for X (`📍 X`).
  - Automatically centers and animates the camera to X's coordinates.
- **Real-Time Updates via Socket.IO**:
  - Listens to the `locationUpdated` event.
  - Automatically moves and updates X's marker in real time without refreshing.
- **`[ OPEN IN GOOGLE MAPS ]`**:
  - One tap opens the exact coordinates directly in Google Maps (`https://www.google.com/maps?q=LATITUDE,LONGITUDE`).
- **Offline / Disconnect Banner**:
  - If the server is unreachable, displays:
    ```text
    Unable to connect to server.
    Last known location: 10:15 AM
    ```
    Clearly distinguishing last known cached location from live status.
- **Configurable Server URL**:
  - Tap the settings icon (⚙️) on the top right to configure the backend URL.

---

## ⚙️ 3. Backend (`backend/`)

- **Tech Stack**: Node.js, Express, Mongoose, Socket.IO, Helmet, CORS, Dotenv.
- **Database**: Single document in the `locations` collection:
  ```json
  {
    "_id": "X",
    "latitude": 17.385044,
    "longitude": 78.486671,
    "accuracy": 8.5,
    "timestamp": "2026-09-23T10:15:00.000Z"
  }
  ```
- **Strict Validation**:
  - `-90 <= latitude <= 90`
  - `-180 <= longitude <= 180`
  - `accuracy` > 0
  - Rejection of `null`, `undefined`, `NaN`, `Infinity`, non-numeric types with `400 Bad Request`.
- **API Endpoints**:
  - `POST /api/location`: Updates location document for `X` and broadcasts `locationUpdated` via Socket.IO.
  - `GET /api/location`: Returns latest location document for `X`.
  - `GET /api/health`: Health status and MongoDB connectivity.

---

## 🚀 Quickstart & Local Development

### 1. Start the Backend

```bash
cd backend
npm install
npm test    # Run automated verification tests
npm start   # Starts server on port 5000 (0.0.0.0:5000)
```

Configure `.env` if needed:
```env
PORT=5000
MONGODB_URI=your_mongodb_atlas_connection_string
```

### 2. Run Sender App

```bash
cd sender_app
flutter pub get
flutter run
```

*Note: For Android Emulator, the default URL `http://10.0.2.2:5000` is already configured.*
*For a physical device, set the URL to `http://<YOUR_COMPUTER_LOCAL_IP>:5000` in the app settings.*

### 3. Run Receiver App

```bash
cd receiver_app
flutter pub get
flutter run
```

*Note: In `receiver_app/android/app/src/main/AndroidManifest.xml`, make sure to provide your Google Maps Android API key for production map rendering.*

---

## 📦 Building Separate Android APKs

Both Flutter projects are completely independent and can be built into standalone APKs:

### Build Sender APK (for Phone X)
```bash
cd sender_app
flutter build apk --release
```
The output APK will be located at:
`sender_app/build/app/outputs/flutter-apk/app-release.apk`

### Build Receiver APK (for Phone Y)
```bash
cd receiver_app
flutter build apk --release
```
The output APK will be located at:
`receiver_app/build/app/outputs/flutter-apk/app-release.apk`

---

## 🧪 Verification & Testing

Both apps and the backend have been verified:
1. `npm test` in `backend`:
   - Validates `GET /api/health`
   - Validates coordinate bounds & type checking on `POST /api/location`
   - Verifies single document atomic upsert `_id = "X"`
   - Verifies Socket.IO `locationUpdated` broadcast reception
2. `flutter analyze` in `sender_app`: **0 issues found**
3. `flutter test` in `sender_app`: **All tests passed**
4. `flutter analyze` in `receiver_app`: **0 issues found**
5. `flutter test` in `receiver_app`: **All tests passed**
