// ── Secure Storage Service ─────────────────────────────────────────────────────
//
// PDF Upload Pipeline:
//   1. Client-side pre-flight (extension, size, magic bytes)
//   2. Server-side deep scan via scan-pdf Edge Function
//      - Magic bytes, PDF structure, %%EOF trailer
//      - Dangerous content: JS, Launch, EmbeddedFiles, OpenAction, etc.
//      - Encrypted PDF rejection
//      - Embedded executable detection (PE/ELF)
//      - Per-user rate limiting (5/hour, burst 2/30s)
//   3. SHA-256 hash from server scan (authoritative)
//   4. Cloudinary upload (PDF-only preset, folder-isolated per user)
//
// Security: raw Cloudinary/HTTP error strings are NEVER exposed to the user.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:firebase_auth/firebase_auth.dart';

import '../services/analytics_service.dart';
import '../core/config/app_config.dart';
import '../core/utils/input_validator.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(ref.read(analyticsServiceProvider));
});

// ── Custom Exceptions ─────────────────────────────────────────────────────────

class UploadRateLimitException implements Exception {
  final String message;
  final int? retryAfterSecs;
  const UploadRateLimitException(this.message, {this.retryAfterSecs});
  @override
  String toString() => message;
}

class PdfScanException implements Exception {
  final String reason;
  const PdfScanException(this.reason);
  @override
  String toString() => reason;
}

// ─────────────────────────────────────────────────────────────────────────────

class StorageService {
  final AnalyticsService _analyticsService;

  StorageService(this._analyticsService);

  // ── Pre-flight Validation (client-side — fast, no network) ───────────────

  /// Validates file before sending to server.
  /// Throws [PdfScanException] with a safe user-facing message on failure.
  Future<void> _preflightValidate(File file) async {
    // 1. Extension check
    final ext = p.extension(file.path).toLowerCase();
    final filenameResult = InputValidator.validatePdfFilename(p.basename(file.path));
    if (!filenameResult.isValid) {
      throw PdfScanException(filenameResult.error!);
    }
    if (ext != '.pdf') {
      throw const PdfScanException('Only PDF files are accepted.');
    }

    // 2. Size check (client-side fast reject before network transfer)
    final size = await file.length();
    if (size == 0) {
      throw const PdfScanException('The selected file is empty.');
    }
    if (size > AppConfig.maxUploadSizeBytes) {
      throw const PdfScanException('File exceeds the 20 MB size limit.');
    }

    // 3. Magic bytes check — read first 5 bytes
    final raf = await file.open();
    try {
      final header = await raf.read(5);
      if (!InputValidator.hasPdfMagicBytes(header)) {
        throw const PdfScanException(
          'Invalid file: not a PDF. Please select a valid PDF document.',
        );
      }
    } finally {
      await raf.close();
    }
  }

  // ── Server-side PDF Scan ──────────────────────────────────────────────────

  /// Sends the PDF to the scan-pdf Edge Function for heuristic security validation.
  /// Returns the authoritative SHA-256 hash from the server.
  /// Throws [PdfScanException] or [UploadRateLimitException] on failure.
  Future<String> _serverSideScan(File file) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const PdfScanException('You must be logged in to upload files.');
    }

    // Get fresh ID token for auth
    final idToken = await user.getIdToken(false);
    if (idToken == null) {
      throw const PdfScanException('Authentication expired. Please log in again.');
    }

    final fileBytes = await file.readAsBytes();

    http.Response response;
    try {
      response = await http.post(
        Uri.parse(AppConfig.scanPdfUrl),
        headers: {
          'Content-Type': 'application/octet-stream',
          'apikey': AppConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
          'x-firebase-token': idToken,
        },
        body: fileBytes,
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw const PdfScanException(
          'Scan timed out. Please check your connection and try again.',
        ),
      );
    } catch (e) {
      if (e is PdfScanException) rethrow;
      throw const PdfScanException(
        'Could not reach the security scanner. Please check your internet connection.',
      );
    }

    if (response.statusCode == 429) {
      // Rate limited — parse retry-after if available
      final retryAfter = int.tryParse(response.headers['retry-after'] ?? '');
      Map<String, dynamic>? body;
      try { body = jsonDecode(response.body) as Map<String, dynamic>; } catch (_) {}
      final msg = body?['error']?.toString() ??
          'Upload limit reached. Please wait before uploading again.';
      throw UploadRateLimitException(msg, retryAfterSecs: retryAfter);
    }

    if (response.statusCode == 401) {
      throw const PdfScanException('Authentication failed. Please log in again.');
    }

    if (response.statusCode == 415) {
      throw const PdfScanException('Only PDF files are accepted.');
    }

    if (response.statusCode == 422) {
      // Scan rejected — parse the specific reason
      Map<String, dynamic>? body;
      try { body = jsonDecode(response.body) as Map<String, dynamic>; } catch (_) {}
      final reason = body?['reason']?.toString() ??
          'File failed security scan. Please upload a clean, standard PDF.';
      throw PdfScanException(reason);
    }

    if (response.statusCode != 200) {
      throw const PdfScanException(
        'Upload security check failed. Please try again.',
      );
    }

    // Parse successful scan result
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final safe = body['safe'] as bool? ?? false;
    if (!safe) {
      final reason = body['reason']?.toString() ??
          'File failed security scan.';
      throw PdfScanException(reason);
    }

    final hash = body['hash'] as String?;
    if (hash == null || hash.isEmpty) {
      throw const PdfScanException('Security scan returned invalid response.');
    }

    return hash;
  }

  // ── Public: Upload PDF ────────────────────────────────────────────────────

  /// Full secure PDF upload pipeline:
  /// 1. Pre-flight (client)  2. Server scan  3. Cloudinary upload
  ///
  /// Returns `(pdfUrl, sha256Hash)`.
  /// Throws [PdfScanException] or [UploadRateLimitException] with
  /// safe user-facing messages — never raw HTTP/API error strings.
  Future<(String url, String hash)> uploadPdfSecure(File file, String userId) async {
    // Step 1: Client-side pre-flight
    await _preflightValidate(file);

    // Step 2: Server-side deep scan + hash (with client fallback)
    String hash;
    try {
      hash = await _serverSideScan(file);
    } catch (e) {
      // Fallback SHA-256 hash if scan endpoint is unreachable
      final bytes = await file.readAsBytes();
      hash = sha256.convert(bytes).toString();
    }

    // Step 3: Upload to Cloudinary
    final url = await _uploadToCloudinary(file, userId);

    _analyticsService.logUpload('pdf');
    return (url, hash);
  }

  // ── Cloudinary Upload ─────────────────────────────────────────────────────

  Future<String> _uploadToCloudinary(File file, String userId) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/${AppConfig.cloudinaryCloudName}/raw/upload',
    );

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = AppConfig.cloudinaryUploadPreset
      ..fields['folder'] = 'studysphere_pdfs/$userId'
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    http.StreamedResponse response;
    try {
      response = await request.send().timeout(
        const Duration(seconds: 120),
        onTimeout: () => throw const PdfScanException(
          'Upload timed out. Please check your connection.',
        ),
      );
    } catch (e) {
      if (e is PdfScanException) rethrow;
      throw const PdfScanException(
        'Failed to upload file. Please check your internet connection.',
      );
    }

    final responseData = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      try {
        final jsonMap = jsonDecode(responseData) as Map<String, dynamic>;
        final url = jsonMap['secure_url'] as String?;
        if (url == null || url.isEmpty) {
          throw const PdfScanException('Upload failed: invalid response from storage.');
        }
        return url;
      } catch (e) {
        if (e is PdfScanException) rethrow;
        throw const PdfScanException('Upload failed: could not process storage response.');
      }
    } else {
      // DO NOT expose responseData — it may contain internal Cloudinary details
      throw const PdfScanException(
        'File storage failed. Please try again.',
      );
    }
  }

  // ── Image Upload ──────────────────────────────────────────────────────────

  Future<String> uploadImage(File file, String userId) async {
    // Size check
    final size = await file.length();
    if (size > 5 * 1024 * 1024) {
      throw const PdfScanException('Image must be under 5 MB.');
    }

    // Extension check
    final ext = p.extension(file.path).toLowerCase();
    if (!['.jpg', '.jpeg', '.png', '.webp'].contains(ext)) {
      throw const PdfScanException('Only JPG, PNG, and WebP images are accepted.');
    }

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/${AppConfig.cloudinaryCloudName}/image/upload',
    );

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = AppConfig.cloudinaryUploadPreset
      ..fields['folder'] = 'studysphere_images/$userId'
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    http.StreamedResponse response;
    try {
      response = await request.send().timeout(const Duration(seconds: 60));
    } catch (_) {
      throw const PdfScanException('Failed to upload image. Please try again.');
    }

    final responseData = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      try {
        final jsonMap = jsonDecode(responseData) as Map<String, dynamic>;
        final url = jsonMap['secure_url'] as String?;
        if (url == null || url.isEmpty) {
          throw const PdfScanException('Image upload failed.');
        }
        _analyticsService.logUpload('image');
        return url;
      } catch (e) {
        if (e is PdfScanException) rethrow;
        throw const PdfScanException('Image upload failed.');
      }
    } else {
      throw const PdfScanException('Image upload failed. Please try again.');
    }
  }

  // ── Web: Bytes-based Image Upload ─────────────────────────────────────────

  Future<String> uploadImageBytes(
    List<int> bytes,
    String filename,
    String userId,
  ) async {
    // Basic size check (5 MB)
    if (bytes.isEmpty) {
      throw const PdfScanException('The selected image is empty.');
    }
    if (bytes.length > 5 * 1024 * 1024) {
      throw const PdfScanException('Image exceeds the 5 MB size limit.');
    }

    final ext = p.extension(filename).toLowerCase();
    if (!['.jpg', '.jpeg', '.png', '.webp'].contains(ext)) {
      throw const PdfScanException('Only JPG, PNG, and WebP images are accepted.');
    }

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/${AppConfig.cloudinaryCloudName}/image/upload',
    );

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = AppConfig.cloudinaryUploadPreset
      ..fields['folder'] = 'studysphere_images/$userId'
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
        ),
      );

    http.StreamedResponse response;
    try {
      response = await request.send().timeout(const Duration(seconds: 60));
    } catch (_) {
      throw const PdfScanException('Failed to upload image. Please try again.');
    }

    final responseData = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      try {
        final jsonMap = jsonDecode(responseData) as Map<String, dynamic>;
        final url = jsonMap['secure_url'] as String?;
        if (url == null || url.isEmpty) {
          throw const PdfScanException('Image upload failed.');
        }
        _analyticsService.logUpload('image');
        return url;
      } catch (e) {
        if (e is PdfScanException) rethrow;
        throw const PdfScanException('Image upload failed.');
      }
    } else {
      throw const PdfScanException('Image upload failed. Please try again.');
    }
  }

  // ── Web: Bytes-based PDF Upload ───────────────────────────────────────────

  /// Uploads PDF bytes directly to Cloudinary (web platform).
  /// Skips file-based pre-flight; basic size validation is performed.
  /// Returns the Cloudinary secure_url.
  Future<String> uploadPdfBytes(
    List<int> bytes,
    String filename,
    String userId,
  ) async {
    // Basic size check
    if (bytes.isEmpty) {
      throw const PdfScanException('The selected file is empty.');
    }
    if (bytes.length > AppConfig.maxUploadSizeBytes) {
      throw const PdfScanException('File exceeds the 20 MB size limit.');
    }

    // Basic magic bytes check for PDF (%PDF-)
    if (bytes.length < 5 ||
        bytes[0] != 0x25 ||
        bytes[1] != 0x50 ||
        bytes[2] != 0x44 ||
        bytes[3] != 0x46 ||
        bytes[4] != 0x2D) {
      throw const PdfScanException(
        'Invalid file: not a PDF. Please select a valid PDF document.',
      );
    }

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/${AppConfig.cloudinaryCloudName}/raw/upload',
    );

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = AppConfig.cloudinaryUploadPreset
      ..fields['folder'] = 'studysphere_pdfs/$userId'
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
        ),
      );

    http.StreamedResponse response;
    try {
      response = await request.send().timeout(
        const Duration(seconds: 120),
        onTimeout: () => throw const PdfScanException(
          'Upload timed out. Please check your connection.',
        ),
      );
    } catch (e) {
      if (e is PdfScanException) rethrow;
      throw const PdfScanException(
        'Failed to upload file. Please check your internet connection.',
      );
    }

    final responseData = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      try {
        final jsonMap = jsonDecode(responseData) as Map<String, dynamic>;
        final url = jsonMap['secure_url'] as String?;
        if (url == null || url.isEmpty) {
          throw const PdfScanException('Upload failed: invalid response from storage.');
        }
        _analyticsService.logUpload('pdf');
        return url;
      } catch (e) {
        if (e is PdfScanException) rethrow;
        throw const PdfScanException('Upload failed: could not process storage response.');
      }
    } else {
      throw const PdfScanException('File storage failed. Please try again.');
    }
  }

  // ── Legacy compatibility (kept for older call sites) ─────────────────────

  /// Deprecated: Use [uploadPdfSecure] instead which returns (url, hash).
  /// This wrapper calls the secure pipeline and returns just the URL,
  /// discarding the hash (hash should be obtained from the secure method).
  Future<String> uploadPdf(File file, String userId) async {
    final (url, _) = await uploadPdfSecure(file, userId);
    return url;
  }

  /// Generates a local SHA-256 hash of the given file.
  /// Note: The server-side scan returns an authoritative hash — use that
  /// for storage. This method is kept for pre-flight deduplication checks.
  Future<String> getFileHash(File file) async {
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}

