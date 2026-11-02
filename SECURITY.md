# Security Policy

## Supported Versions

StudySphere is currently in active development. Security fixes are applied to the latest version on the `master` branch only.

| Version | Supported |
|---|---|
| Latest (`master`) | ✅ Yes |
| Older commits | ❌ No |

---

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub Issues.**

If you discover a security vulnerability, please report it responsibly by emailing:

📧 **[vishal009vb@gmail.com]** *(replace with your actual security contact email)*

### What to Include

Please provide as much of the following as possible:

- Type of vulnerability (e.g., authentication bypass, data exposure, injection)
- Affected component (e.g., Firestore rules, Edge Function, Flutter service)
- Steps to reproduce
- Potential impact assessment
- Any proof-of-concept (redact sensitive data)

### What to Expect

- **Acknowledgement:** Within 72 hours of your report
- **Initial assessment:** Within 7 days
- **Resolution timeline:** Depends on severity — critical issues will be prioritised
- **Credit:** Responsible reporters will be credited in the release notes (if desired)

---

## Security Architecture

### What Is Protected by Design

| Component | Security Mechanism |
|---|---|
| Firebase API keys | Intentionally public; restricted by **Firebase App Check** + Security Rules |
| Supabase anon key | Intentionally public (publishable key); protected by **Row-Level Security** |
| Gemini API key | Lives in **Supabase Secrets only** — never in the client app or source code |
| Firebase service account | **Must not** be committed — enforced by `.gitignore` patterns |
| User data | Protected by Firestore Security Rules (role + ownership checks) |
| PDF uploads | Firebase Storage rules enforce PDF-only, 20 MB max, owner-only writes |
| AI quota | Server-side enforcement in the `gemini-chat` Edge Function |

### Known Limitations (Acknowledged)

- The Supabase anon key and Firebase web API key are embedded in the compiled app. This is by design for both platforms; security is enforced at the service layer, not by key secrecy.
- The in-memory rate limiter in the `gemini-chat` Edge Function resets on cold starts. For production scale, a persistent store (Supabase KV or Redis) should be used.

---

## Security Checklist for Contributors

When submitting code, please verify:

- [ ] No API keys, tokens, passwords, or private keys are hardcoded
- [ ] No sensitive values appear in log output
- [ ] Firestore security rules are not weakened
- [ ] User input is validated before use
- [ ] No `allow read, write: if true;` rules are introduced
- [ ] Error messages do not expose internal implementation details

---

## Scope

The following are **in scope** for security reports:

- Firestore security rule bypasses
- Authentication or authorisation bypasses
- API key exposure in source code or build artifacts
- Server-side injection vulnerabilities in Edge Functions
- AI quota bypass vulnerabilities
- Data exposure through unprotected endpoints

The following are **out of scope:**

- Social engineering attacks
- Physical access attacks
- Theoretical vulnerabilities without a proof of concept
- Issues in third-party dependencies (report those upstream)
- Firebase/Supabase platform vulnerabilities (report to Google/Supabase)
