<div align="center">

<img src="assets/logo.png" alt="StudySphere Logo" width="120" height="120"/>

# StudySphere

### AI-Powered Student Learning Platform

*A community-driven study companion for BCA, BSc, BCom, Engineering & competitive exam students*

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-%3E%3D3.0.0-0175C2?logo=dart)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Firestore%20%7C%20Auth%20%7C%20Storage-FFCA28?logo=firebase)](https://firebase.google.com)
[![License](https://img.shields.io/badge/License-Not%20yet%20licensed-red)](#-license)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen)](CONTRIBUTING.md)

</div>

---

## 📖 Table of Contents

- [About](#-about)
- [Features](#-features)
- [Tech Stack](#-tech-stack)
- [Architecture](#-architecture)
- [Screenshots](#-screenshots)
- [Getting Started](#-getting-started)
- [Environment Configuration](#-environment-configuration)
- [Database Setup](#-database-setup)
- [Roadmap](#-roadmap)
- [Contributing](#-contributing)
- [Security](#-security)
- [License](#-license)
- [Acknowledgements](#-acknowledgements)

---

## 📚 About

**StudySphere** is an open-source, AI-powered mobile learning platform built with Flutter. It connects students through crowd-sourced notes, previous year question papers (PYQs), a real-time community feed, and an AI study assistant powered by Google Gemini — all secured behind Firebase authentication and Firestore security rules.

The project is designed for students pursuing BCA, BSc, BCom, Engineering, MCA, and competitive exams like MPSC/UPSC in the Indian academic ecosystem.

> **Vision:** Democratise access to quality study materials and make peer learning effortless for every Indian student.

---

## ✅ Features

### Implemented & Working

| Feature | Description |
|---|---|
| 🔐 **Authentication** | Email/Password and Google Sign-In via Firebase Auth |
| 📝 **Notes Module** | Browse, upload, download, and bookmark PDF study notes |
| 📄 **Question Papers** | Tree-navigation PYQ browser filtered by course, year, and subject |
| 🤖 **AI Study Assistant** | Google Gemini-powered chat via Supabase Edge Function (server-side key, 25 req/day limit) |
| 🌐 **Community Feed** | Posts, likes, comments, follows, blocks, and content reporting |
| 👤 **User Profiles** | Contributor rankings, reputation points, follower/following system |
| 🎓 **Courses Browser** | Curated YouTube courses across 8 discipline categories |
| 🔔 **Notifications** | In-app and push notifications (Firebase Cloud Messaging) |
| 📥 **Offline Downloads** | PDF caching for offline access |
| 🛡️ **Admin Console** | Role-based admin dashboard (notes moderation, analytics, banners, colleges, logs) |
| 🏫 **College Search** | Location-aware college discovery (state → district → taluka) |
| 🔍 **AI Scraper** | Python backend tool to scrape and bulk-upload academic PDFs |
| 📊 **Analytics** | Firebase Analytics integration |
| 📱 **Platforms** | Android, iOS, Web (Flutter multi-platform) |

### In Development / Planned

- [ ] Full offline-first data synchronisation
- [ ] Supabase AI quota enforcement moved entirely server-side
- [ ] Rich-text post editor in the community feed
- [ ] Study groups and collaborative note-taking
- [ ] Advanced search with full-text indexing

---

## 🛠 Tech Stack

### Mobile Application (Flutter/Dart)

| Layer | Technology |
|---|---|
| **Framework** | Flutter 3.x (Dart ≥ 3.0) |
| **State Management** | Riverpod 2.x |
| **Navigation** | GoRouter 13.x |
| **UI Design** | Claymorphism + Glassmorphism hybrid, Google Fonts (Poppins/Inter) |
| **Animations** | flutter_animate, Lottie |

### Backend & Infrastructure

| Service | Purpose |
|---|---|
| **Firebase Auth** | User authentication (Email + Google OAuth) |
| **Cloud Firestore** | Primary NoSQL database |
| **Firebase Storage** | PDF & image storage (20 MB cap, PDF-only enforced) |
| **Firebase App Check** | Abuse protection for Firebase services |
| **Firebase Cloud Messaging** | Push notifications |
| **Firebase Analytics** | Usage analytics |
| **Supabase Edge Functions** | Server-side AI proxy (Gemini), PDF scanning, welcome emails |
| **Cloudinary** | CDN image delivery for profile pictures |

### AI Integration

| Component | Details |
|---|---|
| **Model** | Google Gemini 2.0 Flash (dynamic model discovery) |
| **Key Location** | Supabase Secrets only — never in the client app |
| **Rate Limiting** | 25 requests/day per user (server-enforced) + 3s cooldown |
| **Auth** | Firebase ID token verified on every Edge Function call |

### Supporting Tools

| Tool | Purpose |
|---|---|
| **Python 3** (`ai_scraper/`) | Academic PDF scraper & bulk uploader |
| **Supabase CLI** | Edge Function deployment |
| **Firebase CLI** | Rules deployment, hosting |
| **flutter_native_splash** | Splash screen generation |
| **flutter_launcher_icons** | App icon generation |

---

## 🏗 Architecture

```
studysphere/
├── lib/
│   ├── main.dart                    # App entrypoint + Firebase init
│   ├── firebase_options.dart        # Platform-specific Firebase config
│   ├── core/
│   │   ├── config/app_config.dart   # App-wide constants & URL config
│   │   ├── constants/               # Colors, text styles
│   │   ├── providers/               # App-level Riverpod providers
│   │   ├── theme/                   # Material theme definition
│   │   ├── utils/                   # Validators, formatters, cache helpers
│   │   └── widgets/                 # Shared UI components
│   ├── features/
│   │   ├── admin/                   # Admin console (role-gated)
│   │   ├── ai_assistant/            # Gemini chat UI
│   │   ├── auth/                    # Login, register, onboarding
│   │   ├── community/               # Feed, posts, comments
│   │   ├── courses/                 # YouTube course browser
│   │   ├── home/                    # Dashboard & banners
│   │   ├── legal/                   # Privacy policy, ToS
│   │   ├── notes/                   # Notes browser, PDF viewer
│   │   ├── notifications/           # Notification centre
│   │   ├── onboarding/              # First-run preferences
│   │   ├── profile/                 # User profiles, uploads
│   │   ├── question_papers/         # PYQ tree navigation
│   │   └── upload/                  # PDF upload flow
│   ├── models/                      # Dart data models
│   ├── routes/                      # GoRouter config + auth guards
│   └── services/                    # Business logic & API clients
├── supabase/functions/
│   ├── gemini-chat/                 # AI proxy Edge Function
│   ├── scan-pdf/                    # PDF validation Edge Function
│   └── send-welcome-email/          # Transactional email Edge Function
├── ai_scraper/                      # Python PDF scraping tool
├── firestore.rules                  # Firestore security rules
├── storage.rules                    # Firebase Storage security rules
├── firebase.json                    # Firebase project config
└── pubspec.yaml                     # Flutter dependencies
```

**Security model:**
- Firestore rules enforce authentication, ownership, and role-based access at the database layer
- Storage rules enforce PDF-only uploads, 20 MB limit, and owner-only writes
- AI API key lives exclusively in Supabase Secrets — the Flutter app never touches it
- Firebase App Check protects all Firebase service calls

---

## 📸 Screenshots

> Screenshots will be added once a stable release build is available. Contributions of screenshots are welcome!

---

## 🚀 Getting Started

### Prerequisites

| Tool | Version | Install |
|---|---|---|
| Flutter SDK | ≥ 3.0 | [flutter.dev](https://docs.flutter.dev/get-started/install) |
| Dart SDK | ≥ 3.0.0 (bundled with Flutter) | — |
| Firebase CLI | Latest | `npm install -g firebase-tools` |
| FlutterFire CLI | Latest | `dart pub global activate flutterfire_cli` |
| Supabase CLI | Latest | [supabase.com/docs/guides/cli](https://supabase.com/docs/guides/cli) |
| Python 3.9+ | ≥ 3.9 (for AI scraper only) | [python.org](https://python.org) |

### 1. Clone the Repository

```bash
git clone https://github.com/vishal009vb/studysphere.git
cd studysphere
```

### 2. Install Flutter Dependencies

```bash
flutter pub get
```

### 3. Firebase Setup

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com).
2. Enable **Authentication** — Email/Password and Google providers.
3. Create a **Firestore** database (start in test mode, then deploy rules).
4. Enable **Firebase Storage**.
5. Enable **Firebase App Check** (Play Integrity for Android, DeviceCheck for iOS).
6. Configure FlutterFire:

```bash
flutterfire configure
```

This generates `lib/firebase_options.dart` with your project's values.

7. Deploy security rules:

```bash
firebase deploy --only firestore:rules,storage
```

### 4. Supabase Setup

1. Create a project at [supabase.com](https://supabase.com).
2. Copy your **Project URL** and **anon key** from Project Settings → API.
3. Create a `.env` file in the project root (see [Environment Configuration](#-environment-configuration)).
4. Add secrets to Supabase:

```bash
supabase secrets set GEMINI_API_KEY=your_gemini_key_here
supabase secrets set FIREBASE_API_KEY=your_firebase_web_api_key_here
```

5. Deploy Edge Functions:

```bash
supabase functions deploy gemini-chat
supabase functions deploy scan-pdf
supabase functions deploy send-welcome-email
```

### 5. Update AppConfig

Open [`lib/core/config/app_config.dart`](lib/core/config/app_config.dart) and replace:

```dart
static const String supabaseUrl = 'YOUR_SUPABASE_URL';
static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
```

### 6. Run the App

```bash
# Debug mode
flutter run

# Specific platform
flutter run -d android
flutter run -d chrome
```

---

## ⚙️ Environment Configuration

Copy `.env.example` to `.env` and fill in your values:

```bash
cp .env.example .env
```

| Variable | Description | Required |
|---|---|---|
| `SUPABASE_URL` | Your Supabase project URL | Yes |
| `SUPABASE_ANON_KEY` | Supabase publishable anon key | Yes |

> **Note:** The Supabase anon key is a *publishable* key by design (security is enforced by Row-Level Security). The Gemini and Firebase API keys are stored exclusively in **Supabase Secrets** and are never embedded in the app.

### AI Scraper Environment (Optional)

For the Python-based PDF scraper in `ai_scraper/`, create `ai_scraper/.env`:

```env
SERPAPI_KEY=your_serpapi_key
GOOGLE_API_KEY=your_google_custom_search_api_key
GOOGLE_CX=your_search_engine_id
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
```

> ⚠️ **Never commit `serviceAccountKey.json` or any `.pem` files.** These are already in `.gitignore`.

---

## 🗄 Database Setup

StudySphere uses **Cloud Firestore** as its primary database. The security rules in [`firestore.rules`](firestore.rules) enforce:

- Role-based access (admin, moderator, contributor, user)
- AI quota fields are client write-protected
- Input length validation at the rule level
- Owner-only writes for user data

### Key Collections

| Collection | Description |
|---|---|
| `users` | User profiles, roles, reputation, AI quota |
| `notes` | Uploaded study notes metadata |
| `questionPapers` | PYQ metadata |
| `posts` | Community feed posts |
| `comments` | Post comments |
| `follows` | Follow relationships |
| `blocks` | Block relationships |
| `notifications` | Per-user notifications |
| `global_notifications` | Admin-broadcast messages |
| `colleges` | College database |
| `courses` | YouTube course catalog |
| `reports` | Content moderation reports |
| `adminLogs` | Admin action audit log |
| `supportTickets` | User support requests |

---

## 🗺 Roadmap

### v1.1 — Stability & Onboarding
- [ ] Replace hardcoded API key fallbacks in `ai_scraper/config.py` with env-only config
- [ ] Add meaningful widget/unit tests
- [ ] CI/CD pipeline (GitHub Actions — lint + test on PRs)

### v1.2 — Features
- [ ] Move AI quota enforcement fully server-side (Supabase → Firestore)
- [ ] Study groups with collaborative document pinning
- [ ] Full-text search for notes and question papers

### v1.3 — Platform Expansion
- [ ] iOS App Store release
- [ ] Web PWA optimisation

### v2.0 — Community Scale
- [ ] College-specific content spaces
- [ ] Verified contributor badges
- [ ] AI-generated note summaries

---

## 🤝 Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) to get started.

**Quick start:**

1. Fork the repository
2. Create a feature branch: `git checkout -b feat/your-feature-name`
3. Commit using [Conventional Commits](https://www.conventionalcommits.org): `git commit -m "feat: add note bookmarking"`
4. Push and open a Pull Request

See [CONTRIBUTING.md](CONTRIBUTING.md) for full guidelines, code style, and the PR checklist.

---

## 🔒 Security

Found a security vulnerability? Please **do not** open a public issue.

Read our [Security Policy](SECURITY.md) for responsible disclosure instructions.

---

## 📜 License

**This project does not currently have an open-source license.**

The absence of a license means the code is under default copyright — contributors and users should be aware that explicit usage rights have not yet been granted. The maintainer is evaluating license options (MIT, Apache-2.0, GPL-3.0).

*A license will be added before the first public release.*

---

## 🙏 Acknowledgements

- [Flutter](https://flutter.dev) — the cross-platform UI framework
- [Firebase](https://firebase.google.com) — auth, database, storage, and messaging
- [Supabase](https://supabase.com) — Edge Functions and AI key management
- [Google Gemini](https://deepmind.google/technologies/gemini/) — AI study assistant model
- [Cloudinary](https://cloudinary.com) — image CDN
- [Riverpod](https://riverpod.dev) — state management
- [GoRouter](https://pub.dev/packages/go_router) — declarative routing
- All open-source package authors listed in [`pubspec.yaml`](pubspec.yaml)
- The student community who inspired this project

---

<div align="center">
  Made with ❤️ for students by students
</div>
