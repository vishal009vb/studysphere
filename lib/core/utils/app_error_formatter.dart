import 'package:firebase_auth/firebase_auth.dart';

class AppErrorFormatter {
  /// Converts raw Firebase/System errors into friendly, privacy-respecting messages.
  static String getFriendlyMessage(dynamic error) {
    if (error == null) return 'An unexpected error occurred. Please try again.';

    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Invalid email address or password. Please check your credentials and try again.';
        case 'email-already-in-use':
          return 'An account already exists with this email address. Try logging in instead.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'user-disabled':
          return 'This account has been suspended or disabled. Please contact support.';
        case 'too-many-requests':
          return 'Too many login attempts. Please wait a few minutes before trying again.';
        case 'network-request-failed':
          return 'Network connection issue. Please check your internet connection.';
        case 'unverified-email':
          return 'Please verify your email address before logging in.';
        case 'popup-closed-by-user':
        case 'canceled':
          return 'Sign-in process was canceled.';
        case 'weak-password':
          return 'Password should be at least 6 characters long with letters and numbers.';
        default:
          return error.message != null && !error.message!.contains('firebase')
              ? error.message!
              : 'Authentication failed. Please try again.';
      }
    }

    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'Permission denied. You do not have access to perform this action.';
        case 'unavailable':
          return 'Service is temporarily unavailable. Please try again shortly.';
        case 'deadline-exceeded':
          return 'Request timed out. Please check your internet connection.';
        default:
          return 'Database operation failed. Please try again.';
      }
    }

    final str = error.toString().toLowerCase();

    if (str.contains('network') || str.contains('socketexception') || str.contains('connection failed')) {
      return 'Network connection problem. Please check your internet and try again.';
    }

    if (str.contains('timeout') || str.contains('timed out')) {
      return 'Operation timed out. Please try again.';
    }

    if (str.contains('firebase') || str.contains('cloud_firestore') || str.contains('firebase_auth')) {
      return 'Something went wrong. Please try again later.';
    }

    // Generic error string cleanup
    final cleanStr = error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
    return cleanStr.isNotEmpty ? cleanStr : 'An unexpected error occurred. Please try again.';
  }
}
