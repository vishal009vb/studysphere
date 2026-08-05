import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import 'firestore_service.dart';
import 'analytics_service.dart';
import '../core/config/app_config.dart';
import '../core/utils/input_validator.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.read(firestoreServiceProvider), ref.read(analyticsServiceProvider));
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final currentUserModelProvider = StateProvider<UserModel?>((ref) => null);

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn? _googleSignIn = kIsWeb
      ? null
      : GoogleSignIn(
          serverClientId: "726667741250-00il2941gflc3q3hntunr3d31lgpluvq.apps.googleusercontent.com",
        );

  final FirestoreService _firestoreService;
  final AnalyticsService _analyticsService;

  AuthService(this._firestoreService, this._analyticsService);

  // â”€â”€ Brute-Force Login Protection â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // Client-side tracking. Firebase Auth enforces server-side rate limiting.
  // This adds a local lockout to prevent rapid credential-stuffing attempts.
  static const int _maxLoginAttempts = 5;
  static const Duration _lockoutDuration = Duration(minutes: 5);
  static final Map<String, List<DateTime>> _loginAttempts = {};
  static final Map<String, DateTime> _lockouts = {};

  /// Returns a lockout message if the email is locked out, else null.
  String? _checkLoginRateLimit(String email) {
    final key = email.toLowerCase().trim();
    final lockoutUntil = _lockouts[key];
    if (lockoutUntil != null && DateTime.now().isBefore(lockoutUntil)) {
      final remaining = lockoutUntil.difference(DateTime.now()).inSeconds;
      return 'Too many failed attempts. Please wait $remaining seconds.';
    }
    // Clear expired lockout
    if (lockoutUntil != null) {
      _lockouts.remove(key);
      _loginAttempts.remove(key);
    }
    return null;
  }

  /// Records a failed login attempt and locks out if threshold exceeded.
  void _recordFailedLogin(String email) {
    final key = email.toLowerCase().trim();
    final now = DateTime.now();
    final windowStart = now.subtract(const Duration(minutes: 10));
    _loginAttempts[key] ??= [];
    // Prune old timestamps
    _loginAttempts[key]!.removeWhere((t) => t.isBefore(windowStart));
    _loginAttempts[key]!.add(now);
    if (_loginAttempts[key]!.length >= _maxLoginAttempts) {
      _lockouts[key] = now.add(_lockoutDuration);
      _loginAttempts[key]!.clear();
      debugPrint('[AuthService] Login locked out for $key');
    }
  }

  /// Clears login attempt tracking on successful login.
  void _clearLoginAttempts(String email) {
    final key = email.toLowerCase().trim();
    _loginAttempts.remove(key);
    _lockouts.remove(key);
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential?> signInWithEmail(String email, String password) async {
    // â”€â”€ Input sanitization
    final cleanEmail = InputValidator.sanitizeSingleLine(email);

    // â”€â”€ Client-side brute-force guard
    final lockoutMsg = _checkLoginRateLimit(cleanEmail);
    if (lockoutMsg != null) {
      throw FirebaseAuthException(
        code: 'too-many-requests',
        message: lockoutMsg,
      );
    }

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      if (credential.user != null && !credential.user!.emailVerified) {
        await _auth.signOut();
        throw FirebaseAuthException(
          code: 'unverified-email',
          message: 'Please verify your email before continuing.',
        );
      }

      // Clear failure tracking on success
      _clearLoginAttempts(cleanEmail);
      if (credential.user != null) {
        await _syncUserProfile(credential.user!);
        await _analyticsService.logLogin('email');
      }
      return credential;
    } on FirebaseAuthException catch (e) {
      // Track failures for wrong credentials â€” not for verified-email or network errors
      if (e.code == 'wrong-password' ||
          e.code == 'user-not-found' ||
          e.code == 'invalid-credential') {
        _recordFailedLogin(cleanEmail);
      }
      rethrow;
    }
  }

  Future<UserCredential?> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String username,
    String state = '',
    String district = '',
    String taluka = '',
    String collegeId = '',
    String collegeName = '',
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user != null) {
        await credential.user!.updateDisplayName(name);
        await credential.user!.sendEmailVerification();
        await _firestoreService.createUserProfile(
          UserModel(
            uid: credential.user!.uid,
            name: name,
            username: username.toLowerCase().trim(),
            email: email,
            photoUrl: '',
            role: 'learner',
            state: state,
            district: district,
            subDistrict: taluka,
            collegeId: collegeId,
            collegeName: collegeName,
            createdAt: DateTime.now(),
            lastLogin: DateTime.now(),
            lastUsageReset: DateTime.now(),
          ),
        );
        // Send welcome email asynchronously in background
        _sendWelcomeEmail(email, name);
      }
      await _analyticsService.logRegistration('email');
      await _auth.signOut();
      return credential;
    } catch (e) {
      rethrow;
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      UserCredential userCredential;

      if (kIsWeb) {
        // Web: use Firebase popup directly — google_sign_in doesn't return idToken on web
        final googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        userCredential = await _auth.signInWithPopup(googleProvider);
      } else {
        // Mobile: prompt Google account picker cleanly
        try {
          await _googleSignIn!.signOut();
        } catch (_) {}

        final GoogleSignInAccount? googleUser = await _googleSignIn!.signIn();
        if (googleUser == null) return null;

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        userCredential = await _auth.signInWithCredential(credential);
      }

      final user = userCredential.user;

      if (user != null) {
        // Sync profile in foreground so it's ready before routing
        await _syncUserProfile(user);
        _analyticsService.logLogin('google');
      }
      return userCredential;
    } catch (e) {
      rethrow;
    }
  }


  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() async {
    await _googleSignIn?.signOut();
    await _auth.signOut();
  }

  Future<void> _updateUserLastLogin(User? user) async {
    if (user != null) {
      await _firestoreService.updateLastLogin(user.uid);
      // Roles are managed strictly via Firestore and admin UI.
    }
  }

  /// Checks and syncs user profile in Firestore.
  Future<void> _syncUserProfile(User user) async {
    try {
      final docExists = await _firestoreService
          .userProfileExists(user.uid)
          .timeout(const Duration(seconds: 5), onTimeout: () => throw Exception('Timeout checking profile'));

      if (!docExists) {
        await _firestoreService.createUserProfile(
          UserModel(
            uid: user.uid,
            name: user.displayName ?? 'Student',
            username: '',
            email: user.email ?? '',
            photoUrl: user.photoURL ?? '',
            role: 'learner',
            createdAt: DateTime.now(),
            lastLogin: DateTime.now(),
            lastUsageReset: DateTime.now(),
          ),
        );
        if (user.email != null) {
          _sendWelcomeEmail(user.email!, user.displayName ?? 'Student');
        }
      } else {
        await _updateUserLastLogin(user);
        // Always sync Google photo URL so DP appears correctly
        if (user.photoURL != null && user.photoURL!.isNotEmpty) {
          try {
            await _firestoreService.updateUserField(user.uid, 'photoUrl', user.photoURL!);
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('[AuthService] Profile sync failed: $e');
      rethrow;
    }
  }

  /// Sends a welcome email via the authenticated Supabase Edge Function.
  /// The edge function verifies the Firebase ID token before sending â€”
  /// this prevents open email relay abuse.
  Future<void> _sendWelcomeEmail(String email, String name) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Get fresh ID token to authenticate the edge function call
      final idToken = await user.getIdToken(false);
      if (idToken == null) return;

      final url = Uri.parse('${AppConfig.supabaseUrl}/functions/v1/send-welcome-email');
      await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'apikey': AppConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
          'x-firebase-token': idToken,
        },
        body: jsonEncode({
          'email': email,
          'name': name,
        }),
      );
    } catch (_) {
      // Silently fail â€” welcome email is non-critical
      // Errors are captured by Crashlytics in production
      debugPrint('[AuthService] Welcome email failed (non-critical)');
    }
  }
}

