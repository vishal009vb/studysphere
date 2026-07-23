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
import 'seed_courses.dart';
import 'services/analytics_service.dart';
import 'services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/courses/providers/enrollment_provider.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  // Hold native splash visible until Flutter SplashScreen removes it
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

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

    // Sync 10 core courses provided by user
    try {
      await seedUserProvidedCourses();
    } catch (e) {
      debugPrint('Course seeding skipped: $e');
    }

    // App Check (Mobile only in dev)
    if (!kIsWeb) {
      try {
        await FirebaseAppCheck.instance.activate(
          androidProvider: kReleaseMode
              ? AndroidProvider.playIntegrity
              : AndroidProvider.debug,
          appleProvider: kReleaseMode
              ? AppleProvider.deviceCheck
              : AppleProvider.debug,
        );
      } catch (e) {
        debugPrint('App Check activation skipped/failed: $e');
      }

      try {
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: 100 * 1024 * 1024, // 100 MB — prevents unbounded disk usage
        );
      } catch (e) {
        debugPrint('Firestore persistence settings error: $e');
      }
    }
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }
}

class StudySphereApp extends ConsumerWidget {
  const StudySphereApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // Using a basic approach: just log app open once when the widget builds
    // since we already know the app has opened.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsServiceProvider).logAppOpen();
      ref.read(notificationServiceProvider).initialize();
    });

    return MaterialApp.router(
      title: 'StudySphere',
      theme: AppTheme.lightTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
