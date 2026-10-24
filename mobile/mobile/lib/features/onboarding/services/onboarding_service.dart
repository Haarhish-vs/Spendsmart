import '../../../core/network/api_client.dart';
import '../../../core/utils/app_storage.dart';
import '../../notifications/services/push_notification_service.dart';

class OnboardingService {
  final ApiClient apiClient;

  OnboardingService(this.apiClient);

  Future<Map<String, dynamic>> submitOnboarding({
    required String employmentStatus,
    double? monthlyIncome,
    required double dailyBudget,
    required double weeklyBudget,
    required double monthlyBudget,
    required String selectedBank,
  }) async {
    final trackingStart = DateTime.now().toIso8601String();

    final localUserId = await AppStorage.getUserId();
    final payload = {
      if (localUserId != null && localUserId.isNotEmpty) 'user_id': localUserId,
      'employment_status': employmentStatus,
      'monthly_income': monthlyIncome,
      'daily_budget': dailyBudget,
      'weekly_budget': weeklyBudget,
      'monthly_budget': monthlyBudget,
      'selected_bank': selectedBank,
      'tracking_start': trackingStart,
    };

    final response = await apiClient.post('/profile/onboarding', payload);

    if (response is Map<String, dynamic> && response['success'] == true) {
      final data = (response['data'] as Map<String, dynamic>?) ?? {};
      final profile = (data['profile'] as Map<String, dynamic>?) ?? {};
      final userId = (profile['id'] ?? data['userId'] ?? data['user_id'] ?? '').toString();

      // Save locally
      await AppStorage.setOnboarded(
        userId: userId,
        selectedBank: selectedBank,
        trackingStart: trackingStart,
        employmentStatus: employmentStatus,
        monthlyIncome: monthlyIncome,
        dailyBudget: dailyBudget,
        weeklyBudget: weeklyBudget,
        monthlyBudget: monthlyBudget,
      );

      // Register device token with backend for push notifications
      PushNotificationService.syncDeviceToken();

      return data;
    }

    throw Exception(response['message'] ?? 'Failed to submit onboarding');
  }
}
