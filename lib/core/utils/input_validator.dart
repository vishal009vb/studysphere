// ── Input Validation & Sanitization Utility ───────────────────────────────────
//
// Purpose: Centralized input validation used across the entire app.
// Every piece of user-supplied text passes through here before reaching
// Firestore, Supabase Edge Functions, or the UI.
//
// Security: Prevents XSS-in-PDFs, null-byte injection, oversized payloads,
// and malformed input from reaching backend systems.
// ─────────────────────────────────────────────────────────────────────────────

import '../config/app_config.dart';

/// Result of a validation check.
class ValidationResult {
  final bool isValid;
  final String? error;
  const ValidationResult.ok() : isValid = true, error = null;
  const ValidationResult.fail(this.error) : isValid = false;
}

class InputValidator {
  InputValidator._(); // Static-only class

  // ── Sanitization ──────────────────────────────────────────────────────────

  /// Strips null bytes, control characters (except tab/newline/CR),
  /// and trims whitespace. Safe to call on any user-supplied string.
  static String sanitize(String input) {
    return input
        // Remove null bytes
        .replaceAll('\x00', '')
        // Remove ASCII control chars except \t (9), \n (10), \r (13)
        .replaceAllMapped(
          RegExp(r'[\x01-\x08\x0b\x0c\x0e-\x1f\x7f]'),
          (_) => '',
        )
        .trim();
  }

  /// For display in UI: additionally collapses multiple whitespace runs
  /// and strips leading/trailing whitespace on each line.
  static String sanitizeForDisplay(String input) {
    return sanitize(input)
        .split('\n')
        .map((line) => line.trim())
        .join('\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n'); // Max 2 consecutive blank lines
  }

  /// Sanitizes a single-line field (strips all newlines).
  static String sanitizeSingleLine(String input) {
    return sanitize(input).replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
  }

  // ── Generic Length Validation ─────────────────────────────────────────────

  static ValidationResult validateLength(
    String value, {
    required String fieldName,
    int minLength = 1,
    required int maxLength,
  }) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return ValidationResult.fail('$fieldName is required.');
    }
    if (trimmed.length < minLength) {
      return ValidationResult.fail('$fieldName must be at least $minLength characters.');
    }
    if (trimmed.length > maxLength) {
      return ValidationResult.fail('$fieldName must be $maxLength characters or fewer.');
    }
    return const ValidationResult.ok();
  }

  // ── Specific Field Validators ─────────────────────────────────────────────

  /// Validates AI prompt — prevents oversized/malformed prompts.
  static ValidationResult validateAiPrompt(String prompt) {
    final cleaned = sanitize(prompt);
    if (cleaned.isEmpty) return const ValidationResult.fail('Please enter a question.');
    if (cleaned.length > AppConfig.maxAiPromptLength) {
      return const ValidationResult.fail(
        'Prompt too long (max ${AppConfig.maxAiPromptLength} characters).',
      );
    }
    return const ValidationResult.ok();
  }

  /// Validates a post/content title.
  static ValidationResult validateTitle(String title) {
    return validateLength(
      sanitizeSingleLine(title),
      fieldName: 'Title',
      minLength: 3,
      maxLength: AppConfig.maxTitleLength,
    );
  }

  /// Validates a content description (multi-line allowed).
  static ValidationResult validateDescription(String desc) {
    final cleaned = sanitizeForDisplay(desc);
    if (cleaned.isEmpty) return const ValidationResult.ok(); // Optional field
    if (cleaned.length > AppConfig.maxDescriptionLength) {
      return const ValidationResult.fail(
        'Description must be ${AppConfig.maxDescriptionLength} characters or fewer.',
      );
    }
    return const ValidationResult.ok();
  }

  /// Validates a community post body.
  static ValidationResult validatePostContent(String content) {
    return validateLength(
      sanitizeForDisplay(content),
      fieldName: 'Post content',
      minLength: 3,
      maxLength: AppConfig.maxPostLength,
    );
  }

  /// Validates a comment.
  static ValidationResult validateComment(String comment) {
    return validateLength(
      sanitizeForDisplay(comment),
      fieldName: 'Comment',
      minLength: 1,
      maxLength: AppConfig.maxCommentLength,
    );
  }

  /// Validates a user bio (optional field).
  static ValidationResult validateBio(String bio) {
    if (bio.trim().isEmpty) return const ValidationResult.ok();
    return validateLength(
      sanitizeForDisplay(bio),
      fieldName: 'Bio',
      maxLength: AppConfig.maxBioLength,
    );
  }

  /// Validates a report reason.
  static ValidationResult validateReportReason(String reason) {
    return validateLength(
      sanitizeForDisplay(reason),
      fieldName: 'Report reason',
      minLength: 10,
      maxLength: AppConfig.maxReportReasonLength,
    );
  }

  /// Validates a support ticket message.
  static ValidationResult validateSupportTicket(String message) {
    return validateLength(
      sanitizeForDisplay(message),
      fieldName: 'Message',
      minLength: 20,
      maxLength: AppConfig.maxSupportTicketLength,
    );
  }

  /// Validates an email address.
  static ValidationResult validateEmail(String email) {
    final cleaned = sanitizeSingleLine(email);
    if (cleaned.isEmpty) return const ValidationResult.fail('Email is required.');
    if (cleaned.length > 254) {
      return const ValidationResult.fail('Email address is too long.');
    }
    // RFC 5321-compliant basic check
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9.!#$%&"*+/=?^_`{|}~-]+@[a-zA-Z0-9]'
      r'(?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?'
      r'(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$',
    );
    if (!emailRegex.hasMatch(cleaned)) {
      return const ValidationResult.fail('Please enter a valid email address.');
    }
    return const ValidationResult.ok();
  }

  /// Validates a password for strength.
  static ValidationResult validatePassword(String password) {
    if (password.length < 8) {
      return const ValidationResult.fail('Password must be at least 8 characters.');
    }
    if (password.length > 128) {
      return const ValidationResult.fail('Password is too long (max 128 characters).');
    }
    // Require at least: 1 uppercase, 1 lowercase, 1 digit
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return const ValidationResult.fail('Password must contain at least one uppercase letter.');
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return const ValidationResult.fail('Password must contain at least one lowercase letter.');
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return const ValidationResult.fail('Password must contain at least one number.');
    }
    return const ValidationResult.ok();
  }

  /// Validates a username.
  static ValidationResult validateUsername(String username) {
    final cleaned = sanitizeSingleLine(username);
    if (cleaned.isEmpty) return const ValidationResult.fail('Username is required.');
    if (cleaned.length < 3) {
      return const ValidationResult.fail('Username must be at least 3 characters.');
    }
    if (cleaned.length > 30) {
      return const ValidationResult.fail('Username must be 30 characters or fewer.');
    }
    // Only alphanumeric and underscore
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(cleaned)) {
      return const ValidationResult.fail(
        'Username may only contain letters, numbers, and underscores.',
      );
    }
    return const ValidationResult.ok();
  }

  /// Validates a subject field for notes/papers.
  static ValidationResult validateSubject(String subject) {
    return validateLength(
      sanitizeSingleLine(subject),
      fieldName: 'Subject',
      minLength: 2,
      maxLength: 100,
    );
  }

  /// Validates a year field (4-digit academic year, 2000–2100).
  static ValidationResult validateYear(String year) {
    final cleaned = sanitizeSingleLine(year);
    if (cleaned.isEmpty) return const ValidationResult.fail('Year is required.');
    final yearInt = int.tryParse(cleaned);
    if (yearInt == null || yearInt < 2000 || yearInt > 2100) {
      return const ValidationResult.fail('Enter a valid year (2000–2100).');
    }
    return const ValidationResult.ok();
  }

  // ── PDF File Validators (client-side pre-flight) ──────────────────────────

  /// Checks the first few bytes of a file are a valid PDF magic number.
  /// Full deep scan is done server-side by the scan-pdf edge function.
  static bool hasPdfMagicBytes(List<int> bytes) {
    if (bytes.length < 5) return false;
    // %PDF- = 0x25 0x50 0x44 0x46 0x2D
    return bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46 &&
        bytes[4] == 0x2D;
  }

  /// Validates a PDF filename — extension must be .pdf (case-insensitive).
  static ValidationResult validatePdfFilename(String filename) {
    final lower = filename.toLowerCase().trim();
    if (!lower.endsWith('.pdf')) {
      return const ValidationResult.fail('Only PDF files are accepted.');
    }
    if (filename.length > 200) {
      return const ValidationResult.fail('Filename is too long.');
    }
    // Block path traversal attempts
    if (filename.contains('..') || filename.contains('/') || filename.contains(r'\')) {
      return const ValidationResult.fail('Invalid filename.');
    }
    return const ValidationResult.ok();
  }

  // ── Disposable Email Detection ────────────────────────────────────────────

  static const _disposableDomains = {
    'tempmail.com', '10minutemail.com', 'guerrillamail.com', 'mailinator.com',
    'throwawaymail.com', 'temp-mail.org', 'yopmail.com', 'tempmail.net',
    'disposablemail.com', 'trashmail.com', 'sharklasers.com', 'guerrillamailblock.com',
    'grr.la', 'guerrillamail.info', 'spam4.me', 'binkmail.com', 'bob.email',
    'discard.email', 'fakeinbox.com', 'filzmail.com', 'getairmail.com',
    'maildrop.cc', 'mailnesia.com', 'mailnull.com', 'mytrashmail.com',
    'no-spam.ws', 'nobulk.com', 'spam.la', 'spamgourmet.com', 'spamgourmet.net',
    'spamgourmet.org', 'trashmail.at', 'trashmail.me',
  };

  static bool isDisposableEmail(String email) {
    final parts = email.toLowerCase().split('@');
    if (parts.length != 2) return false;
    return _disposableDomains.contains(parts[1]);
  }

  // ── Client-Side Rate Guards ───────────────────────────────────────────────
  // These are soft guards — server enforces hard limits.

  static final Map<String, _RateGuard> _guards = {};

  static bool checkClientRateLimit(String key, int maxPerMinute) {
    _guards[key] ??= _RateGuard();
    return _guards[key]!.allow(maxPerMinute);
  }
}

/// In-memory per-key rate guard (soft client-side).
class _RateGuard {
  final List<DateTime> _timestamps = [];

  bool allow(int maxPerMinute) {
    final now = DateTime.now();
    final windowStart = now.subtract(const Duration(minutes: 1));
    _timestamps.removeWhere((t) => t.isBefore(windowStart));
    if (_timestamps.length >= maxPerMinute) return false;
    _timestamps.add(now);
    return true;
  }
}
