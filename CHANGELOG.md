# Changelog

All notable changes to StudySphere are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [Unreleased]

### Added
- `LICENSE` — MIT License
- `CONTRIBUTING.md` — contributor guide
- `SECURITY.md` — security policy and vulnerability reporting
- `CODE_OF_CONDUCT.md` — Contributor Covenant v2.1
- `.env.example` — environment variable template
- `ai_scraper/.env.example` — scraper environment variable template
- `.github/ISSUE_TEMPLATE/` — bug report, feature request, security issue templates
- `.github/pull_request_template.md` — standardised PR checklist
- `.github/workflows/flutter_ci.yml` — automated lint, test, and secret-scan on push/PR
- `.github/workflows/dependency_audit.yml` — scheduled Dart and Python dependency security audit
- `CHANGELOG.md` — this file

### Changed
- `README.md` — full professional rewrite with accurate tech stack, architecture diagram, setup instructions, and updated roadmap
- `.gitignore` — deduplicated and expanded coverage for credentials, private keys, and build artifacts
- `ai_scraper/config.py` — migrated from hardcoded fallback API keys to strict environment variable configuration (`SERPAPI_KEY`, `GOOGLE_API_KEY`, `GOOGLE_CX`)

### Security
- Removed hardcoded fallback API keys from `ai_scraper/config.py`; keys must now be supplied via `.env` or system environment variables
- Confirmed `ai_scraper/serviceAccountKey.json` and `scraper-key.pem.pem` are properly gitignored and not tracked in Git history

---

## [Pre-release] — 2026-11

### Added
- Flutter multi-platform app (Android, iOS, Web, Windows)
- Firebase Auth (Email/Password + Google Sign-In)
- Cloud Firestore database with production-ready security rules
- Firebase Storage with PDF-only, 20 MB cap enforcement
- Firebase App Check integration
- Firebase Cloud Messaging push notifications
- Notes module (browse, upload PDF, bookmark, offline download)
- Question Papers (PYQ) tree navigation
- AI Study Assistant via Supabase Edge Function (Gemini 2.0 Flash)
  - Server-side API key — never in the client
  - 25 requests/day server-enforced rate limit
  - Firebase ID token verification on every request
- Community feed (posts, likes, comments, follows, blocks, reports)
- User profiles with reputation points and contributor rankings
- Courses browser (curated YouTube content, 8 categories)
- Admin console (notes, community moderation, analytics, banners, logs)
- College search with state → district → taluka hierarchy
- Python AI scraper tool for academic PDF bulk upload
- Supabase Edge Functions: `gemini-chat`, `scan-pdf`, `send-welcome-email`
- Claymorphism + Glassmorphism UI design system
- Riverpod 2.x state management
- GoRouter 13.x navigation with auth guards
- Firestore security rules: role-based (admin, moderator, contributor, user)
  - AI quota field write-protection with time-gated daily reset
  - Input length validation at rule level
- Firebase Storage rules: authenticated reads, owner-only writes

### Security Hardening
- `[C-06]` Fixed AI quota reset vulnerability — time-gated 24h window enforced
- `[C-02]` User role fields (`role`, `isBanned`, `isSuspended`, `isVerified`) cannot be self-modified
- `[H-05]` CORS restricted to known origins in Edge Functions
- `[H-03]` Server-side rate limiting in `gemini-chat` Edge Function
- `[H-07]` Prompt injection resistance and input sanitisation in Edge Function
- `[L-01]` Explicit Firestore rules for blocks collection
- `[M-05]` Required field validation for reports collection
- `[P-03]` Storage reads require authentication (no public PDF access)

---

[Unreleased]: https://github.com/vishal009vb/studysphere/compare/HEAD...HEAD
