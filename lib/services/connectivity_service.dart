import 'package:flutter/foundation.dart';

// Use conditional import: dart:io on mobile, stub on web
import 'connectivity_io.dart' if (dart.library.html) 'connectivity_web.dart';

/// Platform-safe internet connectivity check.
/// - Web: always returns true (browser handles offline, dart:io unavailable)
/// - Mobile: tries Socket.connect to Google DNS / Cloudflare / lookup
Future<bool> checkInternetConnection() async {
  if (kIsWeb) return true;
  return checkConnectionNative();
}
