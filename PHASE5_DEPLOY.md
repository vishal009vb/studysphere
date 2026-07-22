# Phase 5 — Cloud Functions Deployment Guide

## Prerequisites

```bash
npm install -g firebase-tools
firebase login
firebase use --add  # Select your StudySphere project
```

## Step 1: Install Functions Dependencies

```bash
cd functions
npm install
cd ..
```

## Step 2: Set the Gemini API Key as a Secret

```bash
# Store the API key in Firebase Secret Manager (NEVER in code)
firebase functions:secrets:set GEMINI_API_KEY
# Paste your Gemini API key when prompted
```

To verify the secret is set:
```bash
firebase functions:secrets:access GEMINI_API_KEY
```

## Step 3: Deploy Cloud Functions

```bash
firebase deploy --only functions
```

Expected output:
```
✔ functions[checkAndIncrementUsage]: Successful create operation.
✔ functions[askGeminiAI]:            Successful create operation.
✔ functions[fetchChatHistory]:       Successful create operation.
✔ functions[cleanupOldChatHistory]:  Successful create operation.
```

## Step 4: Deploy Firestore Security Rules

```bash
firebase deploy --only firestore:rules
```

This enforces the rule that **clients cannot directly write** `dailyUsageCount` or `lastResetDate`.

## Step 5: Run Flutter pub get

```bash
flutter pub get
```

---

## Architecture Overview

```
Flutter App (UI only)
    │
    ├── checkAndIncrementUsage() ──► Cloud Function
    │                                    │ IST-aware date check
    │                                    │ Firestore transaction
    │                                    └── returns { allowed, remaining }
    │
    └── askGeminiAI()             ──► Cloud Function
                                         │ Re-validates rate limit
                                         │ Reads GEMINI_API_KEY from Secret Manager
                                         │ Calls Gemini 1.5 Flash
                                         │ Saves to chatHistory subcollection
                                         └── returns { answer }
```

## Security Architecture

| Layer | What it protects |
|---|---|
| **Firestore Rules** | Blocks direct client writes to `dailyUsageCount`, `lastResetDate`, `chatHistory` |
| **Cloud Function auth check** | Rejects unauthenticated callers |
| **Server-side rate limit** | Cannot be bypassed by app data manipulation |
| **Secret Manager** | Gemini API key never exposed in APK/IPA |
| **IST timezone** | Daily reset at IST midnight (not UTC) |

## Testing Checklist

- [ ] Send 20 questions → 21st should show rate limit dialog
- [ ] Check Firestore → `dailyUsageCount` increments correctly
- [ ] Verify `lastResetDate` is stored as `YYYY-MM-DD` (IST)
- [ ] Check APK: run `strings app-release.apk | grep -i gemini` → should find nothing
- [ ] Turn off internet → app shows "temporarily unavailable" error, not crash
- [ ] Check Firebase Console → Functions logs for errors
- [ ] Verify `users/{uid}/chatHistory` has max 50 docs per user
- [ ] Daily cleanup cron runs at 2:30 AM IST (check scheduler)

## Daily Limit per Role

| Role | Daily AI Questions |
|---|---|
| Learner | 20 |
| Contributor | Unlimited (∞) |
| Moderator | Unlimited (∞) |
| Admin | Unlimited (∞) |

## Chat History Retention

- **Per user**: Max 50 messages (enforced by Cloud Function after each save)
- **By date**: Messages older than 30 days auto-deleted (daily cron at 2:30 AM IST)
