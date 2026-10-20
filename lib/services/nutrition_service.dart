import 'dart:convert';
import 'dart:typed_data';

import '../models/nutrition.dart';
import 'api_client.dart';

class NutritionService {
  NutritionService({ApiClient? api}) : _api = api ?? ApiClient.instance;
  final ApiClient _api;

  Future<List<NutritionFood>> searchFoods(String query) async {
    final response = await _api.get(
      '/api/nutrition/foods?query=${Uri.encodeQueryComponent(query)}',
      includeAuth: true,
    );
    final decoded = _decode(response);
    final list = decoded is List ? decoded : const [];
    return list
        .whereType<Map>()
        .map((item) => NutritionFood.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<NutritionFood>> estimate({
    required Uint8List image,
    String mimeType = 'image/jpeg',
  }) async {
    final response = await _api.post('/api/nutrition/scans/analyze', {
      'imageBase64': base64Encode(image),
      'mimeType': mimeType,
      'idempotencyKey': '${DateTime.now().microsecondsSinceEpoch}',
    }, includeAuth: true);
    final decoded = _decode(response);
    if (decoded is Map && decoded['foodName'] != null) {
      return [
        NutritionFood.fromJson(Map<String, dynamic>.from(decoded)),
      ];
    }
    final list = decoded is List
        ? decoded
        : decoded['foods'] ?? decoded['items'] ?? const [];
    return (list as List)
        .whereType<Map>()
        .map((item) => NutritionFood.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<NutritionEntry>> entries({DateTime? from, DateTime? to}) async {
    final response = await _api.get(
      '/api/nutrition/meals${from == null && to == null ? '' : '?date=${from?.toIso8601String().substring(0, 10)}'}',
      includeAuth: true,
    );
    final decoded = _decode(response);
    final list = decoded is List
        ? decoded
        : decoded['entries'] ?? decoded['items'] ?? const [];
    return (list as List)
        .whereType<Map>()
        .map((item) => NutritionEntry.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Map<String, dynamic>> summary({DateTime? date}) async {
    final value = date == null
        ? ''
        : '?date=${Uri.encodeQueryComponent(date.toIso8601String().substring(0, 10))}';
    final response = await _api.get(
      '/api/nutrition/summary$value',
      includeAuth: true,
    );
    return Map<String, dynamic>.from(_decode(response) as Map);
  }

  Future<Map<String, dynamic>> calculateTarget() async {
    final response = await _api.post(
      '/api/nutrition/target/calculate',
      {},
      includeAuth: true,
    );
    return Map<String, dynamic>.from(_decode(response) as Map);
  }

  Future<NutritionEntry> create(NutritionEntry entry) async {
    var normalized = entry;
    final foods = <NutritionFood>[];
    for (final food in entry.foods) {
      if (food.id != null) {
        foods.add(food);
      } else {
        final matches = await searchFoods(food.name);
        final fallback = matches.isEmpty ? await searchFoods('') : matches;
        if (fallback.isEmpty) {
          throw const FormatException(
            'Không tìm thấy món ăn trong cơ sở dữ liệu.',
          );
        }
        foods.add(food.copyWith(id: fallback.first.id));
      }
    }
    normalized = NutritionEntry(
      id: entry.id,
      date: entry.date,
      mealType: entry.mealType,
      foods: foods,
      note: entry.note,
    );
    final response = await _api.post(
      '/api/nutrition/meals',
      normalized.toJson(),
      includeAuth: true,
    );
    return NutritionEntry.fromJson(_object(response));
  }

  Future<NutritionEntry> update(NutritionEntry entry) async {
    final response = await _api.put(
      '/api/nutrition/meals/${Uri.encodeComponent(entry.id)}',
      entry.toJson(),
      includeAuth: true,
    );
    return NutritionEntry.fromJson(_object(response));
  }

  Future<void> delete(String id) async {
    final response = await _api.delete(
      '/api/nutrition/meals/${Uri.encodeComponent(id)}',
      includeAuth: true,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        response.statusCode,
        'Không thể xóa nhật ký dinh dưỡng.',
      );
    }
  }

  dynamic _decode(dynamic response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        response.statusCode,
        'Không tải được dữ liệu dinh dưỡng.',
      );
    }
    return jsonDecode(response.body);
  }

  Map<String, dynamic> _object(dynamic response) {
    final decoded = _decode(response);
    return Map<String, dynamic>.from(
      decoded is Map && decoded['entry'] is Map
          ? decoded['entry']
          : decoded as Map,
    );
  }
}
