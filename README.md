# KitaKitar - Recycling App

A mobile application for clients who want to recycle waste. Built with Flutter and Firebase.

## Features

- **Authentication**: Email/Password and Google Sign-In
- **Scan**: Camera-based waste scanning with AI recognition
- **Map**: Map with recycling centers and filters
- **Leaders**: Leaderboards for users and centers
- **Profile**: User profile with editing capabilities
- **QR Scanner**: Scan QR codes to receive points

## Tech Stack

- **Frontend**: Flutter (mobile)
- **Backend**: Firebase (Auth, Firestore, Storage, Cloud Functions)
- **AI**: Google AI (Vision/Vertex/ML Kit) for photo recognition
- **Maps**: Google Maps SDK

## Prerequisites

- Flutter SDK (latest stable version)
- Android Studio / Xcode (for mobile development)
- Firebase project
- Google Cloud account (for Maps API)

## Setup Instructions

### 1. Clone the repository

```bash
git clone <repository-url>
cd KitaKitar
```

### 2. Install Flutter dependencies

```bash
cd mobile
flutter pub get
```

### 3. Configure Firebase

#### Option 1: Using FlutterFire CLI (Recommended)

```bash
cd mobile
flutterfire configure
```

This will automatically generate `lib/firebase_options.dart` with your Firebase project configuration.

#### Option 2: Manual Configuration

1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Enable Authentication (Email/Password + Google Sign-In)
3. Enable Firestore Database
4. Enable Storage
5. Download configuration files:
   - **Android**: Download `google-services.json` and place it in `mobile/android/app/`
   - **iOS**: Download `GoogleService-Info.plist` and place it in `mobile/ios/Runner/`
6. Create `mobile/lib/firebase_options.dart` manually (see `firebase_options.dart` template)

### 4. Configure Google Maps

1. Get Google Maps API key from [Google Cloud Console](https://console.cloud.google.com/)
2. Enable "Maps SDK for Android" and "Maps SDK for iOS" APIs

#### Android:
Add to `mobile/android/app/src/main/AndroidManifest.xml`:
```xml
<application>
  <meta-data
      android:name="com.google.android.geo.API_KEY"
      android:value="YOUR_API_KEY_HERE"/>
</application>
```

#### iOS:
Add to `mobile/ios/Runner/AppDelegate.swift`:
```swift
import GoogleMaps

GMSServices.provideAPIKey("YOUR_API_KEY_HERE")
```

### 5. Configure Google Sign-In

1. In Firebase Console → Authentication → Sign-in method, enable Google
2. **Android**: Add SHA-1 fingerprint to Firebase Console
   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```
3. **iOS**: Configure OAuth client in Google Cloud Console

### 6. Deploy Firestore Rules

```bash
cd firebase
firebase deploy --only firestore:rules
```

Current rules allow all authenticated users (for testing). Update rules in `firebase/firestore.rules` for production.

### 7. Run the Application

```bash
cd mobile
flutter run
```

## Project Structure

```
KitaKitar/
├── mobile/                 # Flutter mobile app
│   ├── lib/
│   │   ├── main.dart       # Entry point
│   │   ├── models/         # Data models
│   │   ├── services/       # Firebase, AI, Maps, QR services
│   │   ├── providers/      # State management (Provider)
│   │   └── screens/        # App screens
│   │       ├── auth/       # Authentication
│   │       ├── main/        # Main screen with navigation
│   │       ├── scan/        # Waste scanning
│   │       ├── map/         # Centers map
│   │       ├── leaders/     # Leaderboards
│   │       ├── profile/     # User profile
│   │       └── qr/          # QR scanner
│   └── pubspec.yaml        # Dependencies
├── firebase/
│   ├── functions/           # Cloud Functions (TypeScript)
│   └── firestore.rules      # Firestore security rules
└── README.md                # This file
```

## Firebase Data Model

### Collections

- `/users` - Client users (mobile app)
- `/centers` - Recycling centers
- `/centers/{centerId}/materials` - Materials accepted by center
- `/materials` - Material types reference
- `/ai_scans` - AI scan results
- `/transactions` - Waste acceptance transactions
- `/qr_codes` - One-time QR codes
- `/leaderboards` - Cached leaderboard data

## Troubleshooting

### Build Errors

If you encounter build errors:
1. Run `flutter clean`
2. Delete `.gradle` cache: `Remove-Item -Recurse -Force $env:USERPROFILE\.gradle`
3. Run `flutter pub get`
4. Try building again

### Permission Denied (Firestore)

Make sure Firestore rules are deployed:
```bash
cd firebase
firebase deploy --only firestore:rules
```

Current rules allow all authenticated users. Update `firebase/firestore.rules` for production security.

### Google Maps Not Loading

- Verify API key is correct in `AndroidManifest.xml` (Android) or `AppDelegate.swift` (iOS)
- Ensure "Maps SDK for Android/iOS" is enabled in Google Cloud Console
- Check API key restrictions in Google Cloud Console

## Development Notes

- **AI Service**: Current implementation returns mock data. Integrate Google Vision API or Vertex AI for real recognition.
- **Cloud Functions**: Deploy functions with `firebase deploy --only functions`
- **Firestore Rules**: Current rules are permissive for testing. Update for production.

## License

[Your License Here]
