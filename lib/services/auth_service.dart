import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import '../notifications/runtime.dart';

class AuthResponse {
  AuthResponse({
    required this.token,
    required this.userId,
    required this.email,
    required this.fullName,
    required this.role,
    required this.expiresAt,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
    token: (json['token'] ?? '').toString(),
    userId: (json['userId'] ?? '').toString(),
    email: (json['email'] ?? '').toString(),
    fullName: (json['fullName'] ?? '').toString(),
    role: (json['role'] ?? '').toString(),
    expiresAt:
        DateTime.tryParse((json['expiresAt'] ?? '').toString()) ??
        DateTime.now(),
  );

  final String token;
  final String userId;
  final String email;
  final String fullName;
  final String role;
  final DateTime expiresAt;

  Map<String, dynamic> toJson() => {
    'token': token,
    'userId': userId,
    'email': email,
    'fullName': fullName,
    'role': role,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
  };
}

class AuthService {
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    ApiClient.instance.token = prefs.getString('auth_token');
  }

  Future<AuthResponse> login(String email, String password) async {
    final response = await ApiClient.instance.post('/api/auth/login', {
      'email': email.trim(),
      'password': password,
    });
    return _handleAuthResponse(response);
  }

  Future<AuthResponse> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final response = await ApiClient.instance.post('/api/auth/register', {
      'fullName': fullName.trim(),
      'email': email.trim(),
      'password': password,
    });
    return _handleAuthResponse(response);
  }

  Future<void> forgotPassword(String email) async {
    final resetBaseUrl = '${Uri.base.origin}/#/reset-password';
    final response = await ApiClient.instance.post(
      '/api/auth/forgot-password',
      {'email': email.trim(), 'resetBaseUrl': resetBaseUrl},
    );
    _handleSimpleResponse(response);
  }

  Future<void> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    final response = await ApiClient.instance.post('/api/auth/reset-password', {
      'email': email.trim(),
      'token': token.trim(),
      'newPassword': newPassword,
    });
    _handleSimpleResponse(response);
  }

  Future<void> logout() async {
    try {
      await NotificationRuntime.beforeLogout?.call();
    } catch (_) {}
    ApiClient.instance.token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    NotificationRuntime.sessionChanged?.call();
  }

  Future<void> saveSession(AuthResponse auth) async {
    ApiClient.instance.token = auth.token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', auth.token);
    NotificationRuntime.sessionChanged?.call();
  }

  Future<AuthResponse> _handleAuthResponse(dynamic response) async {
    final body = response.body;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final auth = AuthResponse.fromJson(decoded);
      await saveSession(auth);
      return auth;
    }

    String message = 'Yêu cầu thất bại.';
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        if (decoded['message'] != null) {
          message = decoded['message'].toString();
        } else if (decoded['errors'] != null) {
          final errors = decoded['errors'];
          if (errors is List) {
            message = errors.join(', ');
          }
        }
      }
    } catch (_) {}

    throw ApiException(response.statusCode, message);
  }

  void _handleSimpleResponse(dynamic response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    String message = 'Yeu cau that bai.';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        if (decoded['message'] != null) {
          message = decoded['message'].toString();
        } else if (decoded['errors'] is List) {
          message = (decoded['errors'] as List).join(', ');
        }
      }
    } catch (_) {}

    throw ApiException(response.statusCode, message);
  }
}
