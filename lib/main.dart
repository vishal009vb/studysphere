import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'firebase_options.dart';
import 'routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'services/analytics_service.dart';
import 'services/notification_service.dart';
import 'services/connectivity_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/widgets/in_app_notification_banner.dart';
import 'features/courses/providers/enrollment_provider.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  // Hold native splash visible until Flutter SplashScreen removes it
  if (!kIsWeb) {
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  }

  // Catch ALL silent Flutter errors and print to console (helps debug web white screen)
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('══════ FLUTTER ERROR ══════');
    debugPrint('Exception: ${details.exception}');
    debugPrint('Stack: ${details.stack}');
    FlutterError.presentError(details);
  };

  // Initialize Firebase — all config is compile-time, no .env loading needed
  await _initFirebase();

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const StudySphereApp(),
    ),
  );
}

Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Offline cache must be configured BEFORE the Firestore client starts —
    // once any read/write runs, settings can no longer be changed. Applies to
    // web as well, so cached reads are reused there instead of re-billed.
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: 100 * 1024 * 1024, // 100 MB — prevents unbounded disk usage
      );
    } catch (e) {
      debugPrint('Firestore persistence settings error: $e');
    }

    // App Check (Mobile)
    if (!kIsWeb) {
      try {
        await FirebaseAppCheck.instance.activate(
          androidProvider: AndroidProvider.debug,
          appleProvider: AppleProvider.debug,
        );
      } catch (e) {
        debugPrint('App Check activation skipped/failed: $e');
      }
    }
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }
}

class StudySphereApp extends ConsumerStatefulWidget {
  const StudySphereApp({super.key});

  @override
  ConsumerState<StudySphereApp> createState() => _StudySphereAppState();
}

class _StudySphereAppState extends ConsumerState<StudySphereApp> {
  @override
  void initState() {
    super.initState();
    // Runs once for the app's lifetime. This used to sit in build() behind a
    // post-frame callback, so every rebuild re-registered the FCM listeners and
    // re-logged app_open.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(analyticsServiceProvider).logAppOpen();
      final notifService = ref.read(notificationServiceProvider);
      notifService.attachRouter(ref.read(routerProvider));
      notifService.initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'StudySphere',
      theme: AppTheme.lightTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return ConnectivityWrapper(
          child: InAppNotificationOverlayManager(child: child!),
        );
      },
    );
  }
}

class ConnectivityWrapper extends ConsumerStatefulWidget {
  final Widget child;
  const ConnectivityWrapper({super.key, required this.child});

  @override
  ConsumerState<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends ConsumerState<ConnectivityWrapper> {
  bool _isOnline = true;
  bool _isChecking = false;
  Timer? _connectivityTimer;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    // Poll for online/offline changes. This was every 2 seconds for the entire
    // app lifetime (1,800 network probes an hour) purely to drive an overlay;
    // 15 seconds is still responsive but a fraction of the battery and data.
    _connectivityTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _checkConnectivity();
    });

    // Listen to GoRouter Delegate changes to rebuild when the user navigates offline
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        ref.read(routerProvider).routerDelegate.addListener(_onRouteChanged);
      } catch (_) {}
    });
  }

  void _onRouteChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _connectivityTimer?.cancel();
    try {
      ref.read(routerProvider).routerDelegate.removeListener(_onRouteChanged);
    } catch (_) {}
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    if (_isChecking) return;
    _isChecking = true;

    final online = await checkInternetConnection();

    if (mounted && _isOnline != online) {
      setState(() {
        _isOnline = online;
      });
    }
    _isChecking = false;
  }

  @override
  Widget build(BuildContext context) {
    // Determine current path using GoRouter State
    String location = '/';
    try {
      final router = ref.read(routerProvider);
      location = router.routerDelegate.currentConfiguration.uri.path;
    } catch (_) {}

    // Allowed offline screens:
    // - '/' (Splash/root)
    // - '/login', '/register', '/forgot-password', '/admin-login' (Auth screens)
    // - '/downloads' (Offline downloads screen)
    // - '/offline-downloads' (Offline downloads screen alternative)
    // - '/pdf-viewer' (PDF viewer screen)
    // - '/onboarding' (Onboarding flow)
    final bool showOfflineOverlay = !_isOnline && 
        location != '/' && 
        location != '/login' && 
        location != '/register' && 
        location != '/forgot-password' && 
        location != '/admin-login' && 
        !location.startsWith('/downloads') && 
        !location.startsWith('/offline-downloads') && 
        !location.startsWith('/pdf-viewer') && 
        !location.startsWith('/onboarding');

    return Stack(
      children: [
        widget.child, // Actual app Navigator is always kept alive in the tree
        if (showOfflineOverlay)
          Positioned.fill(
            child: Scaffold(
              backgroundColor: const Color(0xff1a1a2e), // premium dark background matching theme
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.wifi_off_rounded,
                          size: 52,
                          color: Color(0xff7c72e8),
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'No Internet Connection',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Please turn on your internet connection.',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: () {
                          _checkConnectivity();
                        },
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                        label: const Text(
                          'Retry',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff7c72e8),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () {
                          try {
                            ref.read(routerProvider).go('/downloads');
                            setState(() {});
                          } catch (_) {}
                        },
                        icon: const Icon(Icons.download_done_rounded, color: Colors.white70, size: 18),
                        label: const Text(
                          'Go to Offline Downloads',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            color: Colors.white70,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
