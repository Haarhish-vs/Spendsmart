import '../../../core/network/api_client.dart';
import '../models/category_model.dart';

class CategoryService {
  final ApiClient apiClient;

  CategoryService(this.apiClient);

  Future<List<CategoryModel>> getCategories() async {
    try {
      final response = await apiClient.get('/categories');
      if (response is Map<String, dynamic> && response['success'] == true) {
        final list = response['data'] as List<dynamic>? ?? [];
        return list.map((item) => CategoryModel.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
