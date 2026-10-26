import 'package:ai_gym/services/api_client.dart';
import 'package:ai_gym/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ApiClient keeps a configurable backend URL', () {
    final client = ApiClient(baseUrl: 'https://example.com');
    expect(client.baseUrl, 'https://example.com');
  });

  test('ApiClient uses localhost for Flutter web by default', () {
    final client = ApiClient(isWeb: true);
    expect(client.baseUrl, 'http://localhost:5129');
  });

  test('ApiClient attaches a bearer token only to authenticated requests', () {
    final client = ApiClient(baseUrl: 'https://example.com');
    client.token = 'jwt-value';

    expect(client.headers()['Authorization'], isNull);
    expect(client.headers(includeAuth: true)['Authorization'], 'Bearer jwt-value');
  });

  test('AuthResponse parses JWT auth payload', () {
    final auth = AuthResponse.fromJson({
      'token': 'token-123',
      'userId': 'u-1',
      'email': 'user@example.com',
      'fullName': 'Nguyen Van A',
      'role': 'User',
      'expiresAt': '2026-10-10T00:00:00Z',
    });

    expect(auth.email, 'user@example.com');
    expect(auth.role, 'User');
    expect(auth.token, 'token-123');
  });
}
