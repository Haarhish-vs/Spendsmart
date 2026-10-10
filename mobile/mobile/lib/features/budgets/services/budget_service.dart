import '../../../core/network/api_client.dart';

class BudgetService {
  final ApiClient apiClient;

  BudgetService(this.apiClient);

  Future<dynamic> getBudgets(String userId) {
    return apiClient.get('/budgets/$userId');
  }

  Future<dynamic> saveBudget(Map<String, dynamic> budget) {
    if (budget.containsKey('id') && budget['id'] != null) {
      return apiClient.put('/budgets/${budget['id']}', budget);
    }
    return apiClient.post('/budgets', budget);
  }

  Future<dynamic> deleteBudget(String id, String userId) {
    return apiClient.delete('/budgets/$id?userId=$userId');
  }

  Future<dynamic> getBudgetAlerts(String userId) {
    return apiClient.get('/budgets/alerts/$userId');
  }
}
