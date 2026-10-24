import '../../../core/network/api_client.dart';
import '../../../core/utils/app_storage.dart';
import '../../notifications/services/push_notification_service.dart';

class AuthService {
  final ApiClient apiClient;

  AuthService([ApiClient? client]) : apiClient = client ?? ApiClient();

  /// Register a new user with standard JWT authentication
  Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final response = await apiClient.post('/auth/register', {
      'fullName': fullName.trim(),
      'email': email.trim().toLowerCase(),
      'password': password,
    });

    if (response is Map<String, dynamic> && response['success'] == true) {
      final data = response['data'] as Map<String, dynamic>;
      final user = data['user'] as Map<String, dynamic>;
      final token = data['token'] as String;

      await AppStorage.saveAuthSession(
        token: token,
        userId: user['id'] as String,
        email: user['email'] as String,
        fullName: (user['full_name'] ?? fullName) as String,
      );

      // Reset onboarded flag for newly registered user so they complete setup
      await AppStorage.setIsOnboarded(false);

      // Immediately sync FCM push device token under this user's unique identity
      PushNotificationService.syncDeviceToken();

      return data;
    }

    throw Exception(response['message'] ?? 'Registration failed');
  }

  /// Log in an existing user with standard JWT authentication
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await apiClient.post('/auth/login', {
      'email': email.trim().toLowerCase(),
      'password': password,
    });

    if (response is Map<String, dynamic> && response['success'] == true) {
      final data = response['data'] as Map<String, dynamic>;
      final user = data['user'] as Map<String, dynamic>;
      final token = data['token'] as String;

      await AppStorage.saveAuthSession(
        token: token,
        userId: user['id'] as String,
        email: user['email'] as String,
        fullName: (user['full_name'] ?? '') as String,
      );

      // Check if user already has an active bank and budget setup
      try {
        final profileRes = await apiClient.get('/profile/${user['id']}');
        if (profileRes is Map<String, dynamic> && profileRes['success'] == true) {
          final profileData = profileRes['data'] as Map<String, dynamic>?;
          final selectedBank = (profileData?['selected_bank'] ??
              profileData?['profile']?['selected_bank']) as String?;
          final trackingStart = (profileData?['tracking_start'] ??
              profileData?['profile']?['tracking_start']) as String?;

          if (selectedBank != null && selectedBank.isNotEmpty) {
            await AppStorage.setSelectedBank(selectedBank);
            if (trackingStart != null && trackingStart.isNotEmpty) {
              await AppStorage.setTrackingStartDate(trackingStart);
            }
            await AppStorage.setIsOnboarded(true);
          } else {
            await AppStorage.setIsOnboarded(false);
          }
        }
      } catch (_) {
        // Non-fatal profile check fallback
      }

      // Immediately sync FCM push device token under this user's unique identity
      PushNotificationService.syncDeviceToken();

      return data;
    }

    throw Exception(response['message'] ?? 'Login failed');
  }

  /// Sign out current user and clear local session state
  Future<void> logout() async {
    await AppStorage.logout();
  }
}
