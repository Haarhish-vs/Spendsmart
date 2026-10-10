import '../../../core/network/api_client.dart';

class AnalyticsService {
  final ApiClient apiClient;

  AnalyticsService(this.apiClient);

  Future<dynamic> getOverview(String userId, {String period = 'month'}) {
    return apiClient.get('/analytics/overview/$userId?period=$period');
  }
}
