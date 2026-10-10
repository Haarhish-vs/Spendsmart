import '../../../core/network/api_client.dart';

class TransactionService {
  final ApiClient apiClient;

  TransactionService(this.apiClient);

  Future<dynamic> getTransactions(String userId) {
    return apiClient.get('/transactions/$userId');
  }

  Future<dynamic> getDashboardSummary(String userId) {
    return apiClient.get('/transactions/summary/$userId');
  }

  Future<dynamic> createTransaction(Map<String, dynamic> transaction) {
    return apiClient.post('/transactions', transaction);
  }

  Future<dynamic> deleteTransaction(String id, String userId) {
    return apiClient.delete('/transactions/$id?userId=$userId');
  }
}
