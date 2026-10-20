import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_client.dart';

class ProfileService extends ChangeNotifier {
  ProfileService({ApiClient? api}) : _api = api ?? ApiClient.instance;

  static final instance = ProfileService();
  final ApiClient _api;
  Map<String, dynamic>? profile;
  String? error;
  bool loading = false;
  int _generation = 0;
  int _revision = 0;

  void clear() {
    _generation++;
    profile = null;
    error = null;
    loading = false;
    notifyListeners();
  }

  Future<void> load() async {
    if (_api.token == null) return;
    final generation = _generation;
    final revision = ++_revision;
    final token = _api.token;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final data = _decode(await _api.get('/api/profile', includeAuth: true));
      if (generation == _generation &&
          revision == _revision &&
          token == _api.token) {
        profile = data;
      }
    } catch (_) {
      if (generation == _generation &&
          revision == _revision &&
          token == _api.token) {
        error = 'Không tải được hồ sơ. Vui lòng thử lại.';
      }
    } finally {
      if (generation == _generation &&
          revision == _revision &&
          token == _api.token) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> save(Map<String, dynamic> fields) async {
    if (profile == null || _api.token == null) {
      throw ApiException(401, 'Vui lòng tải hồ sơ hoặc đăng nhập lại.');
    }
    final generation = _generation;
    final token = _api.token;
    _revision++;
    loading = false;
    final data = _decode(
      await _api.put('/api/profile', {
        ...profile!,
        ...fields,
      }, includeAuth: true),
    );
    if (generation != _generation || token != _api.token) return;
    _revision++;
    loading = false;
    profile = data;
    error = null;
    notifyListeners();
  }

  Future<void> saveWorkout({
    required String id,
    required DateTime startedAt,
    required int durationSeconds,
    List<Map<String, dynamic>>? exercises,
    Map<String, int>? feedbackCounts,
  }) async {
    if (_api.token == null) {
      throw ApiException(401, 'Vui lòng đăng nhập để lưu phiên tập.');
    }
    final generation = _generation;
    final token = _api.token;
    final response = await _api.post('/api/profile/workouts', {
      'id': id,
      'startedAt': startedAt.toUtc().toIso8601String(),
      'durationSeconds': durationSeconds,
      'exercises': ?exercises,
      'feedbackCounts': ?feedbackCounts,
    }, includeAuth: true);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        response.statusCode,
        'Chưa lưu được phiên tập. Vui lòng thử lại.',
      );
    }
    if (generation == _generation && token == _api.token) await load();
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        response.statusCode,
        'Không lưu hoặc tải được dữ liệu tài khoản. Vui lòng thử lại.',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
