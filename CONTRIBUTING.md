# Contributing to StudySphere

Thank you for your interest in contributing to StudySphere! 🎉

This document explains how to contribute effectively, what we expect from contributors, and how to get your changes merged.

---

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How to Contribute](#how-to-contribute)
- [Development Setup](#development-setup)
- [Branch Naming](#branch-naming)
- [Commit Messages](#commit-messages)
- [Pull Request Process](#pull-request-process)
- [Code Style](#code-style)
- [Testing](#testing)
- [Reporting Bugs](#reporting-bugs)
- [Requesting Features](#requesting-features)

---

## Code of Conduct

By participating in this project, you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md). Please read it before contributing.

---

## How to Contribute

### Types of Contributions We Welcome

- 🐛 Bug fixes
- ✨ New features aligned with the project roadmap
- 📝 Documentation improvements
- 🧪 Tests (we need more!)
- 🔒 Security improvements
- 🎨 UI/UX improvements
- 🌐 Translations (future)
- 🧹 Code cleanup and refactoring (with justification)

### What We Ask You Not to Do

- Do not submit large architectural rewrites without prior discussion
- Do not add unnecessary dependencies
- Do not break existing features
- Do not expose API keys, credentials, or personal data
- Do not submit AI-generated code without reviewing it carefully

---

## Development Setup

### Prerequisites

| Tool | Version |
|---|---|
| Flutter SDK | ≥ 3.0 |
| Dart SDK | ≥ 3.0 (bundled with Flutter) |
| Firebase CLI | Latest |
| FlutterFire CLI | Latest |
| Git | Latest |

### Steps

1. **Fork** the repository on GitHub.
2. **Clone** your fork:

   ```bash
   git clone https://github.com/YOUR_USERNAME/studysphere.git
   cd studysphere
   ```

3. **Add the upstream remote:**

   ```bash
   git remote add upstream https://github.com/vishal009vb/studysphere.git
   ```

4. **Install dependencies:**

   ```bash
   flutter pub get
   ```

5. **Configure Firebase and Supabase** as described in [README.md](README.md#-getting-started).

6. **Verify the setup:**

   ```bash
   flutter analyze
   flutter test
   ```

---

## Branch Naming

Use the following convention for branch names:

| Type | Pattern | Example |
|---|---|---|
| Feature | `feat/short-description` | `feat/note-bookmarking` |
| Bug fix | `fix/short-description` | `fix/pdf-viewer-crash` |
| Documentation | `docs/short-description` | `docs/api-setup-guide` |
| Chore/Refactor | `chore/short-description` | `chore/remove-unused-imports` |
| Tests | `test/short-description` | `test/auth-service-unit` |

---

## Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/):

```
<type>(<scope>): <short description>

[optional body]

[optional footer(s)]
```

**Types:** `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `perf`, `build`, `ci`

**Examples:**

```
feat(notes): add bookmark toggle with Riverpod state
fix(auth): handle Google sign-in cancellation gracefully
docs(readme): update Firebase setup steps
test(gemini): add unit test for rate limit logic
```

---

## Pull Request Process

1. **Sync with upstream** before creating your PR:

   ```bash
   git fetch upstream
   git rebase upstream/master
   ```

2. **Run checks locally** before pushing:

   ```bash
   flutter analyze --no-fatal-infos
   flutter test
   ```

3. **Open a Pull Request** against the `master` branch.
4. Fill in the PR template completely.
5. Link any related issues using `Fixes #123` or `Closes #123`.
6. **Do not** request reviews until CI passes.
7. Respond to review comments promptly.

### PR Requirements

- [ ] `flutter analyze` passes with no new errors
- [ ] `flutter test` passes
- [ ] No hardcoded API keys or credentials
- [ ] Existing features are not broken
- [ ] PR description clearly explains what changed and why
- [ ] Screenshots added for any UI changes

---

## Code Style

StudySphere follows standard Flutter/Dart conventions:

- Run `flutter analyze` — all warnings must be resolved
- Follow effective Dart style: [dart.dev/guides/language/effective-dart](https://dart.dev/guides/language/effective-dart)
- Use `const` constructors wherever possible
- Prefer `final` over `var`
- Keep widget `build()` methods focused — extract sub-widgets
- Services and providers go in `lib/services/`; UI goes in `lib/features/`
- Use Riverpod providers for state — avoid `setState` in complex widgets

### File Organisation

```
lib/features/<feature_name>/
├── <feature_name>_screen.dart     # Main screen widget
├── widgets/                       # Feature-specific widgets
└── providers/                     # Feature-specific Riverpod providers (if needed)
```

---

## Testing

We currently have minimal test coverage and actively welcome test contributions.

**Run tests:**

```bash
flutter test
```

**Test file location:** `test/`

**What to test:**
- Service layer logic (auth, Firestore operations)
- Input validation (`lib/core/utils/input_validator.dart`)
- Model serialisation/deserialisation
- Utility functions

Widget tests are also welcome but require a Firebase mock setup.

---

## Reporting Bugs

1. Search [existing issues](https://github.com/vishal009vb/studysphere/issues) first.
2. If not found, open a [Bug Report](https://github.com/vishal009vb/studysphere/issues/new?template=bug_report.md).
3. Include:
   - Flutter version (`flutter --version`)
   - Device/platform
   - Steps to reproduce
   - Expected vs actual behaviour
   - Screenshots or error logs (redact any personal information)

---

## Requesting Features

1. Search [existing issues](https://github.com/vishal009vb/studysphere/issues) and [discussions](https://github.com/vishal009vb/studysphere/discussions) first.
2. Open a [Feature Request](https://github.com/vishal009vb/studysphere/issues/new?template=feature_request.md).
3. Explain:
   - The problem it solves
   - Who benefits from it
   - How it fits the project's scope

Large features should be discussed before implementation to avoid wasted effort.

---

## Questions?

Open a [Discussion](https://github.com/vishal009vb/studysphere/discussions) rather than an issue for general questions.

Thank you for making StudySphere better! 🚀
