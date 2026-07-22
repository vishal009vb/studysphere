# StudySphere — AI-Powered Student Learning Platform

StudySphere is a comprehensive learning ecosystem designed for BCA, BSc, BCom, Engineering, and competitive exam students. It offers crowd-sourced study notes, previous year question papers (PYQs), an AI assistant using the Google Gemini API, a community feed, and leaderboard rankings for contributors.

---

## 🎨 Visual Design & UI System
We designed StudySphere using a **Claymorphism + Modern Glassmorphism Hybrid** style:
- Soft, bouncy card structures with custom layered shadows (`AppColors.clayShadow`).
- Floating pill bottom navigation.
- Smooth spring-like press scaling effects (`AnimatedScale`).
- Interactive Google Fonts (Poppins and Inter).

---

## 🛠️ Folder Structure
- `lib/main.dart` — App Entrypoint.
- `lib/routes/app_routes.dart` — Declarative routing (GoRouter) with auth guards.
- `lib/models/` — Complete data definitions (User, Note, PYQ, Posts, Comments, etc.).
- `lib/services/` — Core business logic (Auth, Firestore, Gemini AI helper).
- `lib/features/` — Clean features directory containing all Claymorphic screens (Home Dashboard, Onboarding, Preferences, Notes module, PYQs Tree Nav, AI Assistant, Community Feed, User Profile, Admin Console).
- `firestore.rules` — Production-ready Firestore document security configurations.
- `storage.rules` — 20MB file size cap & PDF-only validation storage rules.

---

## 🚀 Setup Instructions

1. **Flutter Installation**:
   Ensure you have Flutter installed. If not, follow instructions at [flutter.dev](https://docs.flutter.dev/get-started/install).

2. **Firebase Setup**:
   - Create a Firebase project in the [Firebase Console](https://console.firebase.google.com).
   - Activate **Authentication** (Email/Password & Google Provider).
   - Initialize **Firestore Database** in test mode, then deploy `firestore.rules`.
   - Setup **Firebase Storage** bucket and deploy `storage.rules`.
   - Configure Flutterfire by running:
     ```bash
     npm install -g firebase-tools
     firebase login
     dart pub global activate flutterfire_cli
     flutterfire configure
     ```

3. **Gemini API Configuration**:
   - Obtain an API key from [Google AI Studio](https://aistudio.google.com).
   - Paste the API key into `lib/services/gemini_service.dart` under the `_apiKey` variable.

4. **Running the Application**:
   Run the following commands in the project directory:
   ```bash
   flutter pub get
   flutter run
   ```
