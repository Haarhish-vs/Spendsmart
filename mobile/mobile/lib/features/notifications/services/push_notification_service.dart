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
  static RemoteMessage? pendingInitialMessage;

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

      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 2. Fetch and register token
      await syncDeviceToken();

      // 3. Listen to token refresh
      messaging.onTokenRefresh.listen((newToken) {
        debugPrint('[FCM] Token refreshed, updating backend');
        _sendTokenToBackend(newToken);
      });

      // 4. Foreground notification handling
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[FCM] Foreground message received: ${message.messageId}');
        _showInAppNotificationBanner(message);
      });

      // 5. App opened from background notification tap
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[FCM] App opened from background notification tap: ${message.messageId}');
        _handleNotificationTap(message);
      });

      // 6. Terminated app opened from notification tap
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[FCM] Terminated app opened from notification tap: ${initialMessage.messageId}');
        pendingInitialMessage = initialMessage;
        // Attempt immediate tap if navigator is ready
        if (navigatorKey.currentState != null) {
          _handleNotificationTap(initialMessage);
          pendingInitialMessage = null;
        }
      }
    } catch (e) {
      debugPrint('[FCM] Firebase messaging initialization skipped: $e');
    }
  }

  /// Process any pending notification message from a cold start once navigator is ready
  static void handlePendingInitialMessage() {
    if (pendingInitialMessage != null && navigatorKey.currentState != null) {
      final msg = pendingInitialMessage!;
      pendingInitialMessage = null;
      _handleNotificationTap(msg);
    }
  }

  /// Sync currently assigned FCM token with backend
  static Future<void> syncDeviceToken() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _sendTokenToBackend(token);
      }
    } catch (e) {
      debugPrint('[FCM] Device token retrieval failed: $e');
    }
  }

  static Future<void> _sendTokenToBackend(String token) async {
    try {
      final userId = await AppStorage.getUserId();
      if (userId == null) {
        debugPrint('[FCM] Token sync postponed: User not logged in/onboarded yet.');
        return;
      }

      final client = ApiClient();
      final res = await client.post('/notifications/device-token', {
        'userId': userId,
        'token': token,
        'platform': 'android',
      });
      debugPrint('[FCM] Device token registered with backend successfully: $res');
    } catch (e) {
      debugPrint('[FCM] Device token registration error: $e');
    }
  }

  static void _showInAppNotificationBanner(RemoteMessage message) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final title = message.notification?.title ?? message.data['title'] ?? 'Budget Alert';
    final body = message.notification?.body ?? message.data['body'] ?? message.data['message'] ?? '';

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
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(body, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
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

