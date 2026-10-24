import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/utils/app_storage.dart';
import 'package:mobile/features/auth/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('JWT Authentication & User Session Tests', () {
    test('1. Register successfully saves user session and JWT token', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, endsWith('/auth/register'));
        final body = jsonDecode(request.body);
        expect(body['email'], 'alice@example.com');
        expect(body['fullName'], 'Alice Smith');

        return http.Response(
          jsonEncode({
            'success': true,
            'message': 'User registered successfully',
            'data': {
              'user': {
                'id': 'user-alice-123',
                'email': 'alice@example.com',
                'full_name': 'Alice Smith',
              },
              'token': 'mock.jwt.token.alice',
            },
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockClient);
      final authService = AuthService(apiClient);

      final result = await authService.register(
        fullName: 'Alice Smith',
        email: 'alice@example.com',
        password: 'Password123!',
      );

      expect(result['user']['id'], 'user-alice-123');
      expect(result['token'], 'mock.jwt.token.alice');

      // Verify session stored in AppStorage
      expect(await AppStorage.isLoggedIn(), true);
      expect(await AppStorage.getAuthToken(), 'mock.jwt.token.alice');
      expect(await AppStorage.getUserId(), 'user-alice-123');
      expect(await AppStorage.getUserEmail(), 'alice@example.com');
      expect(await AppStorage.getUserFullName(), 'Alice Smith');
    });

    test('2. Login successfully sets user session', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) {
          final body = jsonDecode(request.body);
          expect(body['email'], 'bob@example.com');

          return http.Response(
            jsonEncode({
              'success': true,
              'message': 'Login successful',
              'data': {
                'user': {
                  'id': 'user-bob-456',
                  'email': 'bob@example.com',
                  'full_name': 'Bob Jones',
                },
                'token': 'mock.jwt.token.bob',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path.contains('/profile/')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'selected_bank': 'HDFC Bank',
                'tracking_start': '2026-10-24T00:00:00.000Z',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(client: mockClient);
      final authService = AuthService(apiClient);

      await authService.login(
        email: 'bob@example.com',
        password: 'Password123!',
      );

      expect(await AppStorage.isLoggedIn(), true);
      expect(await AppStorage.getAuthToken(), 'mock.jwt.token.bob');
      expect(await AppStorage.getUserId(), 'user-bob-456');
      expect(await AppStorage.getSelectedBank(), 'HDFC Bank');
      expect(await AppStorage.isOnboarded(), true);
    });

    test('3. ApiClient attaches Authorization Bearer token header', () async {
      await AppStorage.saveAuthSession(
        token: 'valid.jwt.bearer.token',
        userId: 'user-789',
        email: 'carol@example.com',
        fullName: 'Carol White',
      );

      final mockClient = MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer valid.jwt.bearer.token');
        return http.Response(
          jsonEncode({'success': true, 'data': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockClient);
      final res = await apiClient.get('/transactions/user-789');
      expect(res['success'], true);
    });

    test('4. Logout completely purges session state', () async {
      await AppStorage.saveAuthSession(
        token: 'temp-token',
        userId: 'user-111',
        email: 'user@test.com',
        fullName: 'Test User',
      );

      expect(await AppStorage.isLoggedIn(), true);
      expect(await AppStorage.getAuthToken(), isNotNull);

      final authService = AuthService();
      await authService.logout();

      expect(await AppStorage.isLoggedIn(), false);
      expect(await AppStorage.getAuthToken(), isNull);
      expect(await AppStorage.getUserId(), isNull);
      expect(await AppStorage.getUserEmail(), isNull);
    });

    test('5. Login failure propagates error message', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'message': 'Invalid email or password',
          }),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockClient);
      final authService = AuthService(apiClient);

      expect(
        () async => await authService.login(
          email: 'wrong@example.com',
          password: 'WrongPassword',
        ),
        throwsA(predicate((e) => e.toString().contains('Invalid email or password'))),
      );
    });
  });
}
