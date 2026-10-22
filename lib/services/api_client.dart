import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() =>
      'ApiException(statusCode: $statusCode, message: $message)';
}

class ApiClient {
  ApiClient({String? baseUrl, bool isWeb = kIsWeb})
    : _baseUrl = (baseUrl ?? _defaultBaseUrl(isWeb)).trim().replaceFirst(
        RegExp(r'/+$'),
        '',
      );

  static final ApiClient instance = ApiClient();
  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

  final String _baseUrl;
  String? token;

  String get baseUrl => _baseUrl;

  Uri uri(String path) => Uri.parse('$_baseUrl$path');

  static String _defaultBaseUrl(bool isWeb) {
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl;
    }
    return isWeb ? 'http://localhost:5129' : 'http://10.0.2.2:5129';
  }

  Map<String, String> headers({bool includeAuth = false}) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (includeAuth && token != null && token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<http.Response> get(String path, {bool includeAuth = false}) async =>
      http.get(uri(path), headers: headers(includeAuth: includeAuth));

  Future<http.Response> post(
    String path,
    Map<String, dynamic> body, {
    bool includeAuth = false,
  }) async => http.post(
    uri(path),
    headers: headers(includeAuth: includeAuth),
    body: jsonEncode(body),
  );

  Future<http.Response> put(
    String path,
    Map<String, dynamic> body, {
    bool includeAuth = false,
  }) async => http.put(
    uri(path),
    headers: headers(includeAuth: includeAuth),
    body: jsonEncode(body),
  );

  Future<http.Response> delete(
    String path, {
    bool includeAuth = false,
    Map<String, dynamic>? body,
  }) async => http.delete(
    uri(path),
    headers: headers(includeAuth: includeAuth),
    body: body == null ? null : jsonEncode(body),
  );
}
