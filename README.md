# RoomCraft AI

RoomCraft AI is a modern Flutter-based interior design application that helps users redesign rooms using AI and a manual 2D editor. The app lets users upload a room photo, describe changes in natural language, generate multiple design options, and then fine-tune the result with a custom room editor.

The project combines:
- Flutter mobile/web client
- Firebase Authentication and Firestore
- Express backend for AI generation and image processing
- Replicate-powered image generation
- Manual room arrangement tools for furniture, decor, and lighting

## Project goals

- Make room redesign simple and visual
- Allow quick AI-assisted interior concept generation
- Support custom manual room editing
- Save and reopen user projects
- Provide a premium, polished UX for a modern interior design tool

## Key features

### 1. AI room generation
- Upload a room photo
- Add a description of the desired change
- Choose a style
- Generate multiple design options
- Review the resulting concept directly in the app

### 2. Budget-aware design flow
- The app includes budget-related logic and premium design cards to support more realistic interior decisions

### 3. Multiple style variants
- Users can generate and compare several visual directions for the same room

### 4. Manual 2D editor
- Add furniture, decor, light, and textile items
- Move, resize, and rotate placed objects
- Create custom asset items from uploaded images
- Save the final room composition

### 5. User accounts and saved projects
- Firebase authentication
- Cloud Firestore data for saved works
- Save and reopen previous interior concepts

### 6. Premium UI design
- Soft gradients
- Glass-like translucent panels
- White and blue luxury-inspired palette
- Hover animations and modern card-based layout

## Tech stack

### Frontend
- Flutter
- Dart
- Material Design widgets

### Backend
- Node.js
- Express.js
- Multer for uploads
- Firebase Admin SDK
- Replicate API for image generation

### Database / Auth
- Firebase Authentication
- Firestore

### Other tools
- File picker and image upload support
- Base64 image handling and preview rendering

## Project structure

```text
roomcraft_ai-master-1-
├── android/
├── ios/
├── linux/
├── macos/
├── windows/
├── web/
├── lib/
│   ├── app.dart
│   ├── main.dart
│   ├── firebase_options.dart
│   ├── models/
│   ├── platform/
│   ├── screens/
│   ├── services/
│   ├── theme/
│   └── widgets/
├── backend/
│   ├── server.js
│   ├── package.json
│   └── generated/
├── analysis_options.yaml
├── firebase.json
├── pubspec.yaml
├── README.md
└── .gitignore
```

## Screens included

- Splash screen
- Login / registration
- Mode selection
- AI room generation form
- Result screen
- Manual room editor
- Profile screen

## Main app flow

1. User logs in
2. Chooses between AI mode and manual mode
3. Uploads a room photo or starts with a blank design
4. Enters a prompt and style preferences
5. Generates a concept or customizes the room manually
6. Saves the final design and revisits it later

## Getting started

### Requirements

- Flutter SDK 3.11+
- Dart SDK compatible with the project
- Node.js 18+
- Firebase project
- Replicate API token

### 1. Install Flutter dependencies

```bash
flutter pub get
```

### 2. Start the backend

```bash
cd backend
npm install
cp .env.example .env
```

Then set the required environment variables in `backend/.env`:

```env
PORT=3000
REPLICATE_API_TOKEN=your_replicate_token
FIREBASE_SERVICE_ACCOUNT_PATH=path/to/serviceAccountKey.json
```

Then run:

```bash
npm start
```

### 3. Run the Flutter app

```bash
flutter run -d chrome
```

You can also run on Android/iOS if configured on your environment.

## Firebase setup

This project uses Firebase for:
- Authentication
- Firestore storage
- User-specific saved works

Make sure your Firebase project is configured and that the generated Firebase files are present, including:
- `android/app/google-services.json`
- `lib/firebase_options.dart`

## Backend notes

The backend is responsible for:
- receiving uploaded room images
- preparing the generation prompt
- sending requests to Replicate AI
- saving generated result files
- serving generated images from `/generated`

## Example user flow

```text
Login -> Select mode -> Upload room -> Describe design -> Generate -> Review results -> Save work
```

## Current status

This project is in active development and includes:
- AI room generation flow
- manual 2D room editor
- saved designs
- Firebase-backed user logic
- premium redesigned UI

## Development notes

The app is designed to be extended with:
- more furniture categories
- richer AI prompt presets
- better background removal tools
- image export and sharing
- design history and revisions

## Contact / project ownership

This project is a personal/portfolio-style interior design app built with Flutter and AI-powered room editing tools.

## Next possible improvements

- add real product recommendation system
- support more item categories
- improve AI generation quality
- implement more advanced room segmentation
- add multi-language support
- add premium user dashboard

---

This README is intended as a clear project overview for developers, contributors, and collaborators working on RoomCraft AI.
