import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/analytics_service.dart';
import '../core/widgets/splash_ui.dart';

// Import features (these screens will be created next)
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/onboarding/preferences_screen.dart';
import '../features/home/home_screen.dart';
import '../features/notes/notes_screen.dart';
import '../features/notes/note_detail_screen.dart';
import '../features/notes/pdf_viewer_screen.dart';
import '../features/notes/downloads_screen.dart';
import '../features/profile/my_uploads_screen.dart';
import '../features/question_papers/question_papers_screen.dart';
import '../features/ai_assistant/ai_assistant_screen.dart';
import '../features/community/community_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/profile/offline_downloads_screen.dart';
import '../features/admin/admin_main_screen.dart';
import '../features/legal/privacy_policy_screen.dart';
import '../features/legal/contact_support_screen.dart';
import '../features/legal/community_guidelines_screen.dart';
import '../features/legal/copyright_policy_screen.dart';
import '../features/legal/disclaimers_screen.dart';
import '../features/legal/delete_account_screen.dart';

import 'package:firebase_auth/firebase_auth.dart';
import '../features/admin/admin_login_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges()),
    observers: [ref.read(analyticsServiceProvider).getAnalyticsObserver()],
    redirect: (context, state) {
      final user = ref.read(authStateProvider).value;
      final currentUser = ref.read(currentUserModelProvider);
      final location = state.matchedLocation;

      final isAuthRoute = location == '/login' ||
          location == '/register' ||
          location == '/forgot-password' ||
          location == '/admin-login';

      final isOnboardingRoute =
          location == '/onboarding' || location == '/preferences';

      // Always allow splash screen to render and play animation
      if (location == '/') {
        return null;
      }

      // Redirect to login if not authenticated
      if (user == null) {
        return isAuthRoute ? null : '/login';
      }

      // Logged in but on auth page → go back to splash (it decides home vs onboarding)
      if (isAuthRoute) {
        // If admin login and user is admin, go to admin
        if (location == '/admin-login' && currentUser?.role == 'admin') {
          return '/admin';
        }
        if (!user.emailVerified) {
          // Keep unverified email users on the auth screen so they can see verification popups
          return null;
        }
        return '/';
      }

      // Admin routes protection handled in AdminMainScreen directly

      // Allow onboarding & preference routes for logged-in users
      if (isOnboardingRoute) {
        return null;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/admin-login',
        builder: (context, state) => const AdminLoginScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/preferences',
        builder: (context, state) => const PreferencesScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/notes',
        builder: (context, state) => const NotesScreen(),
      ),
      GoRoute(
        path: '/notes/:id',
        builder: (context, state) => NoteDetailScreen(noteId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/pdf-viewer',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return PDFViewerScreen(
            pdfUrl: extra['pdfUrl'] as String,
            title: extra['title'] as String,
            isLocal: extra['isLocal'] as bool? ?? false,
          );
        },
      ),
      GoRoute(
        path: '/papers',
        builder: (context, state) => const QuestionPapersScreen(),
      ),
      GoRoute(
        path: '/ai',
        builder: (context, state) => const AIAssistantScreen(),
      ),
      GoRoute(
        path: '/community',
        builder: (context, state) => const CommunityScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/my-uploads',
        builder: (context, state) => const MyUploadsScreen(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminMainScreen(initialTab: 'dashboard'),
      ),
      GoRoute(
        path: '/admin/:tab',
        builder: (context, state) => AdminMainScreen(initialTab: state.pathParameters['tab']),
      ),
      GoRoute(
        path: '/offline-downloads',
        builder: (context, state) => const OfflineDownloadsScreen(),
      ),
      GoRoute(
        path: '/downloads',
        builder: (context, state) => const DownloadsScreen(),
      ),
      GoRoute(
        path: '/privacy',
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: '/terms',
        builder: (context, state) => const TermsConditionsScreen(),
      ),
      GoRoute(
        path: '/contact',
        builder: (context, state) => const ContactSupportScreen(),
      ),
      GoRoute(
        path: '/community-guidelines',
        builder: (context, state) => const CommunityGuidelinesScreen(),
      ),
      GoRoute(
        path: '/copyright-policy',
        builder: (context, state) => const CopyrightPolicyScreen(),
      ),
      GoRoute(
        path: '/ai-disclaimer',
        builder: (context, state) => const AiDisclaimerScreen(),
      ),
      GoRoute(
        path: '/content-disclaimer',
        builder: (context, state) => const ContentDisclaimerScreen(),
      ),
      GoRoute(
        path: '/delete-account',
        builder: (context, state) => const DeleteAccountScreen(),
      ),
    ],
  );
});

/// SplashScreen: Animated entry screen. Checks auth + onboarding state:
/// - Not logged in        → /login
/// - First login (no coursePreference set) → /onboarding
/// - Returning user       → /home
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    try {
      // Remove OS native splash as soon as Flutter SplashUI is painted
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FlutterNativeSplash.remove();
      });

      // Display full-screen splash screen for 1.2s for clean branding experience
      await Future.delayed(const Duration(milliseconds: 1200));

      // Await auth state stream to resolve logged in status
      final user = await ref.read(authStateProvider.future);

      if (!mounted) return;

      if (user == null || !user.emailVerified) {
        context.go('/login');
        return;
      }

      final firestoreService = ref.read(firestoreServiceProvider);
      final userProfile = await firestoreService.getUserProfile(user.uid);
      ref.read(currentUserModelProvider.notifier).state = userProfile;

      if (!mounted) return;

      if (userProfile.coursePreference.isEmpty) {
        context.go('/onboarding');
      } else {
        context.go('/home');
      }
    } catch (_) {
      if (mounted) {
        context.go('/onboarding');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SplashUI();
  }
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
