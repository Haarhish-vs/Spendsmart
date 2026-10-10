import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/app_storage.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized for background message handler
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

class PushNotificationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      final messaging = FirebaseMessaging.instance;

      // 1. Request notification permission (Required for Android 13+ / API 33+)
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');

      // 2. Fetch and register token
      await syncDeviceToken();

      // 3. Listen to token refresh
      messaging.onTokenRefresh.listen((newToken) {
        _sendTokenToBackend(newToken);
      });

      // 4. Foreground notification handling
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (message.notification != null) {
          _showInAppNotificationBanner(message);
        }
      });

      // 5. App opened from background notification tap
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleNotificationTap(message);
      });

      // 6. Terminated app opened from notification tap
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }
    } catch (e) {
      // Graceful fallback if google-services.json not configured on local machine
      debugPrint('Firebase messaging initialization skipped: $e');
    }
  }

  /// Sync currently assigned FCM token with backend
  static Future<void> syncDeviceToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _sendTokenToBackend(token);
      }
    } catch (_) {}
  }

  static Future<void> _sendTokenToBackend(String token) async {
    try {
      final userId = await AppStorage.getUserId();
      if (userId == null) return;

      final client = ApiClient();
      await client.post('/notifications/device-token', {
        'userId': userId,
        'token': token,
        'platform': 'android',
      });
    } catch (_) {}
  }

  static void _showInAppNotificationBanner(RemoteMessage message) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final title = message.notification?.title ?? 'Budget Alert';
    final body = message.notification?.body ?? '';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF232C54),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_active_rounded, color: Color(0xFFF39C12), size: 18),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
            const SizedBox(height: 4),
            Text(body, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
        action: SnackBarAction(
          label: 'View',
          textColor: const Color(0xFF2ECC71),
          onPressed: () {
            _handleNotificationTap(message);
          },
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  static void _handleNotificationTap(RemoteMessage message) {
    final route = message.data['route'] ?? '/budgets';
    navigatorKey.currentState?.pushNamed(route);
  }
}
