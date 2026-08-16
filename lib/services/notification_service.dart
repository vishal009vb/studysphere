import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

// Top-level background message handler for when app is closed / terminated
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("FCM Background message received: ${message.messageId}");
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  GoRouter? _router;

  // Guards against re-initialising. initialize() is triggered from a post-frame
  // callback, so without this every rebuild would re-register the FCM listeners
  // (duplicate handling of a single notification tap) and re-write the token.
  bool _initialized = false;

  // Last token written to Firestore this session, so an unchanged token does
  // not cost a write on every launch.
  String? _lastSyncedToken;

  final List<StreamSubscription<dynamic>> _subscriptions = [];

  NotificationService();

  void attachRouter(GoRouter router) {
    _router = router;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      // 1. Request Permission for status bar / lock screen notifications
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: true,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('FCM Authorization status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized || 
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        
        // 2. Register Background Handler
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

        // 3. Subscribe to global announcements topic for closed app push notifications
        if (!kIsWeb) {
          await _messaging.subscribeToTopic('global_announcements');
        }

        // 4. Handle notification tap when app was completely CLOSED (Terminated State)
        RemoteMessage? initialMessage = await _messaging.getInitialMessage();
        if (initialMessage != null) {
          _handleNotificationTap(initialMessage);
        }

        // 5. Handle notification tap when app was in BACKGROUND
        _subscriptions.add(
          FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
            debugPrint('Notification tapped in background: ${message.data}');
            _handleNotificationTap(message);
          }),
        );

        // 6. Handle FOREGROUND notifications
        _subscriptions.add(
          FirebaseMessaging.onMessage.listen((RemoteMessage message) {
            debugPrint('FCM Foreground message received: ${message.data}');
          }),
        );

        // 7. Save & sync FCM Token to Firestore
        try {
          final token = await _messaging.getToken();
          await _saveTokenToDatabase(token);

          // On a cold start auth restoration often has not finished yet, so the
          // write above is skipped (no uid). Retry once auth resolves rather
          // than losing the token until the next launch.
          _subscriptions.add(
            FirebaseAuth.instance.authStateChanges().listen((user) {
              if (user != null) _saveTokenToDatabase(token);
            }),
          );
        } catch (e) {
          debugPrint('Could not fetch FCM token: $e');
        }

        // 8. Sync Token Refreshes
        _subscriptions.add(_messaging.onTokenRefresh.listen(_saveTokenToDatabase));
      }
    } catch (e) {
      debugPrint('FCM Notification initialization error: $e');
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    final route = message.data['route'] as String?;
    if (route != null && route.isNotEmpty && _router != null) {
      _router!.push(route);
    }
  }

  Future<void> dispose() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    _initialized = false;
  }

  Future<void> _saveTokenToDatabase(String? token) async {
    if (token == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Skip the write when nothing changed — this ran unconditionally on every
    // launch before, costing one write per user per app open for no reason.
    if (_lastSyncedToken == token) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _lastSyncedToken = token;
      debugPrint('FCM Token saved to Firestore for user $uid');
    } catch (e) {
      debugPrint('Failed to save FCM token: $e');
    }
  }
}
