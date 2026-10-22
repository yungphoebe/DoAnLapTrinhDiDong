import 'dart:convert';
import 'dart:math';

import '../services/api_client.dart';

class SupportApi {
  SupportApi({ApiClient? client}) : client = client ?? ApiClient.instance;
  final ApiClient client;
  Future<Map<String, dynamic>> content() async {
    final response = await client
        .get('/api/support/content')
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, 'Không tải được nội dung.');
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  Future<String> feedback(String id, String subject, String content) async {
    final response = await client
        .post('/api/support/feedback', {
          'requestId': id,
          'subject': subject.trim(),
          'content': content.trim(),
        }, includeAuth: true)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ApiException(
        response.statusCode,
        response.statusCode == 401
            ? 'Vui lòng đăng nhập để gửi phản hồi.'
            : 'Chưa gửi được phản hồi. Nội dung vẫn được giữ để thử lại.',
      );
    }
    return (jsonDecode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>)['id']
        as String;
  }

  static String requestId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
