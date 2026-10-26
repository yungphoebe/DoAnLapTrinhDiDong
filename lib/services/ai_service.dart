import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';

class AiService {
  AiService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient.instance;

  final ApiClient _api;

  Future<Map<String, dynamic>> chat(
    String message, {
    String? conversationId,
  }) async {
    final response = await _api.post('/api/coach/chat', {
      'message': message,
      ...?conversationId == null ? null : {'conversationId': conversationId},
    }, includeAuth: true);
    final body = _decodeResponse(response);
    if (response.statusCode >= 400) {
      throw ApiException(
        response.statusCode,
        body is Map && body['message'] is String
            ? body['message'] as String
            : 'Không thể kết nối Coach.',
      );
    }
    return Map<String, dynamic>.from(body as Map);
  }

  dynamic _decodeResponse(http.Response response) {
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw ApiException(
        response.statusCode,
        'Máy chủ trả về dữ liệu không hợp lệ. Hãy kiểm tra backend và LMStudio.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> conversations() async {
    final response = await _api.get(
      '/api/coach/conversations',
      includeAuth: true,
    );
    final body = jsonDecode(response.body) as List;
    return body.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<Map<String, dynamic>> insights() async {
    final response = await _api.get('/api/coach/insights', includeAuth: true);
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<Map<String, dynamic>> planProposal() async {
    final response = await _api.post(
      '/api/coach/plan-proposal',
      {},
      includeAuth: true,
    );
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }
}
