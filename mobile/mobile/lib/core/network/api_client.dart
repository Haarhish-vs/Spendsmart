import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  // Live Render production backend
  static const String productionBaseUrl = 'https://spendsmart-k8sh.onrender.com/api/v1';

  // Ordered fallback URLs:
  // 1. Live Render production backend
  // 2. LAN Wi-Fi IP of development machine
  // 3. USB reverse loopback
  // 4. Android Emulator alias
  static const List<String> candidateBaseUrls = [
    productionBaseUrl,
    'http://172.27.142.75:5000/api/v1',
    'http://127.0.0.1:5000/api/v1',
    'http://10.0.2.2:5000/api/v1',
  ];

  static String activeBaseUrl = candidateBaseUrls.first;

  final http.Client _client;

  ApiClient({
    String? baseUrl,
    http.Client? client,
  })  : _client = client ?? http.Client() {
    if (baseUrl != null) {
      activeBaseUrl = baseUrl;
    }
  }

  String get baseUrl => activeBaseUrl;

  Future<dynamic> get(String endpoint) async {
    return _executeWithFallback((url) => _client.get(
          Uri.parse('$url$endpoint'),
          headers: {'Content-Type': 'application/json'},
        ));
  }

  Future<dynamic> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    return _executeWithFallback((url) => _client.post(
          Uri.parse('$url$endpoint'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ));
  }

  Future<dynamic> put(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    return _executeWithFallback((url) => _client.put(
          Uri.parse('$url$endpoint'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ));
  }

  Future<dynamic> delete(String endpoint) async {
    return _executeWithFallback((url) => _client.delete(
          Uri.parse('$url$endpoint'),
          headers: {'Content-Type': 'application/json'},
        ));
  }

  Future<dynamic> _executeWithFallback(Future<http.Response> Function(String url) requestFn) async {
    // Try currently active URL first
    try {
      final response = await requestFn(activeBaseUrl).timeout(const Duration(seconds: 4));
      return _handleResponse(response);
    } catch (e) {
      // If network failure / connection refused, try alternate candidates
      for (final candidate in candidateBaseUrls) {
        if (candidate == activeBaseUrl) continue;
        try {
          final response = await requestFn(candidate).timeout(const Duration(seconds: 3));
          activeBaseUrl = candidate; // Remember working candidate
          return _handleResponse(response);
        } catch (_) {
          continue;
        }
      }
      throw Exception('Could not connect to SpendSmart backend. Check that PC is running and on same Wi-Fi ($activeBaseUrl). Error: $e');
    }
  }

  dynamic _handleResponse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded;
      }

      if (decoded is Map<String, dynamic> && decoded.containsKey('message')) {
        throw Exception(decoded['message']);
      }

      throw Exception('API request failed with status: ${response.statusCode}');
    } on FormatException {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.body;
      }
      throw Exception('API request failed with status: ${response.statusCode}');
    }
  }
}
