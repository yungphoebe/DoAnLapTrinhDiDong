import 'dart:convert';

import 'api_client.dart';

class WorkoutService {
  WorkoutService({ApiClient? api}) : _api = api ?? ApiClient.instance;

  final ApiClient _api;

  Future<List<Map<String, dynamic>>> exercises() async {
    final response = await _api.get('/api/exercises', includeAuth: true);
    return _list(response);
  }

  Future<List<Map<String, dynamic>>> plans() async {
    final response = await _api.get('/api/workout-plans', includeAuth: true);
    return _list(response);
  }

  Future<Map<String, dynamic>> createPlan({
    required String name,
    String? goal,
    String? level,
    required List<Map<String, dynamic>> exercises,
  }) async {
    final response = await _api.post('/api/workout-plans', {
      'name': name,
      'goal': goal,
      'level': level,
      'isActive': true,
      'exercises': exercises,
    }, includeAuth: true);
    return _object(response);
  }

  Future<List<Map<String, dynamic>>> appointments() async {
    final response = await _api.get('/api/appointments', includeAuth: true);
    return _list(response);
  }

  Future<Map<String, dynamic>> weeklyProgress({DateTime? weekStart}) async {
    final query = weekStart == null
        ? ''
        : '?weekStart=${Uri.encodeQueryComponent(weekStart.toIso8601String())}';
    final response = await _api.get(
      '/api/progress/weekly$query',
      includeAuth: true,
    );
    return _object(response);
  }

  List<Map<String, dynamic>> _list(dynamic response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, 'Không tải được dữ liệu tập luyện.');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) throw const FormatException('Invalid list response');
    return decoded
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Map<String, dynamic> _object(dynamic response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, 'Không lưu được dữ liệu tập luyện.');
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }
}
