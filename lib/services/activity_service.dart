import 'dart:convert';

import 'api_client.dart';

class ActivityRoutePoint {
  const ActivityRoutePoint({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    this.segmentStart = false,
  });

  final double latitude;
  final double longitude;
  final DateTime recordedAt;
  final bool segmentStart;

  factory ActivityRoutePoint.fromJson(Map<String, dynamic> json) =>
      ActivityRoutePoint(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        recordedAt: DateTime.parse(json['recordedAt'] as String),
        segmentStart: json['segmentStart'] == true,
      );

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'recordedAt': recordedAt.toUtc().toIso8601String(),
    'segmentStart': segmentStart,
  };
}

class ActivityService {
  ActivityService({ApiClient? api}) : _api = api ?? ApiClient.instance;

  final ApiClient _api;

  Future<List<Map<String, dynamic>>> sessions(DateTime from) async {
    final day = from.toLocal();
    final date = '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final response = await _api.get(
      '/api/activity/sessions?from=$date',
      includeAuth: true,
    );
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, 'Không tải được lịch sử đi bộ/chạy.');
    }
    return (jsonDecode(response.body) as List<dynamic>)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>> goal(DateTime date) async {
    final response = await _api.get(
      '/api/activity/goals/${_date(date)}',
      includeAuth: true,
    );
    return _object(response);
  }

  Future<Map<String, dynamic>> saveGoal({
    required DateTime date,
    required int steps,
    required int minutes,
    required double kilometers,
  }) async {
    final response = await _api.put(
      '/api/activity/goals/${_date(date)}',
      {
        'stepsGoal': steps,
        'minutesGoal': minutes,
        'distanceGoalKm': kilometers,
      },
      includeAuth: true,
    );
    return _object(response);
  }

  Future<void> saveSession({
    required String id,
    required String activityType,
    required DateTime startedAt,
    required int durationSeconds,
    required int? steps,
    required double? distanceMeters,
    required List<ActivityRoutePoint> route,
    required bool completed,
  }) async {
    final response = await _api.post(
      '/api/activity/sessions',
      {
        'id': id,
        'activityType': activityType,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'durationSeconds': durationSeconds,
        'steps': steps,
        'distanceMeters': distanceMeters,
        'route': route.map((point) => point.toJson()).toList(),
        'distanceEstimated': false,
        'completed': completed,
      },
      includeAuth: true,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, 'Không lưu được buổi vận động.');
    }
  }

  String _date(DateTime date) {
    final local = date.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> _object(dynamic response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, 'Không lưu hoặc tải được mục tiêu vận động.');
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }
}
